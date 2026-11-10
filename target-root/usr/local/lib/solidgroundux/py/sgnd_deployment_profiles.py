#!/usr/bin/env python3
# =====================================================================================
# SolidGroundUX Framework - Deployment Profile Store
# -------------------------------------------------------------------------------------
# Metadata:
#   Version     : 2.2
#   Build       : 2631102
#   Source      : sgnd_deployment_profiles.py
#   Type        : module
#   Group       : Framework
#   Purpose     : Store named WCM and SDK deployment profiles without interactive UI
#
# Description:
#   The Bash applications own all questions and deployment operations. This module
#   provides versioned, namespaced, atomic JSON storage, field validation, safe
#   selection, independent success timestamps, and idempotent 2631102 state migration.
#   No passwords are accepted or stored.
#
# Usage:
#   ```bash
#   python3 sgnd_deployment_profiles.py wcm list
#   python3 sgnd_deployment_profiles.py sdk save --name HQ --field transport=remote
#   python3 sgnd_deployment_profiles.py sdk get --name HQ
#   ```
# =====================================================================================
from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from datetime import datetime, timezone
from contextlib import contextmanager

VERSION = 1
FIELDS = {
    'wcm': ('website', 'name', 'method', 'source', 'host', 'user', 'port',
            'identity', 'path', 'hostname', 'strategy', 'manage_site',
            'preview_port', 'url', 'last_success'),
    'sdk': ('name', 'transport', 'remote', 'product_root', 'products', 'source',
            'target', 'directory', 'match', 'changed_after', 'since_last',
            'receiver', 'last_success'),
}
EDITABLE = {kind: set(fields) - {'last_success'} for kind, fields in FIELDS.items()}
VALID_NAME = re.compile(r'^[^\x00-\x1f\x7f/\\]{1,96}$')
VALID_HOST = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]*$')
VALID_USER = re.compile(r'^[A-Za-z_][A-Za-z0-9_.-]*$')
VALID_HOSTING_USER = re.compile(r'^[A-Za-z0-9_][A-Za-z0-9_.@+-]{0,127}$')


class ProfileError(ValueError):
    pass


def config_dir() -> Path:
    profile_home = os.environ.get('SGND_PROFILE_HOME')
    if profile_home:
        root = Path(profile_home).expanduser()
        if not root.is_absolute():
            raise ProfileError('SGND_PROFILE_HOME must be absolute')
        return root / '.config' / 'solidgroundux' / 'deployment-profiles'
    base = os.environ.get('XDG_CONFIG_HOME')
    if base:
        base_dir = Path(base).expanduser()
        if not base_dir.is_absolute():
            raise ProfileError('XDG_CONFIG_HOME must be absolute')
    else:
        base_dir = Path.home() / '.config'
    return base_dir / 'solidgroundux' / 'deployment-profiles'


def validate_name(name: str) -> str:
    name = name.strip()
    if not VALID_NAME.fullmatch(name) or name in ('.', '..'):
        raise ProfileError('Profile names must be 1-96 printable characters, without / or \\')
    return name


def validate_record(namespace: str, record: dict) -> None:
    if not isinstance(record.get('name'), str):
        raise ProfileError('Profile name must be a string')
    validate_name(record['name'])
    for key, value in record.items():
        if key not in FIELDS[namespace] or not isinstance(value, str):
            raise ProfileError(f'Unexpected profile field: {key}')
        if any(c in value for c in ('\x00', '\r', '\n')):
            raise ProfileError(f'Invalid control character in {key}')
    if namespace == 'wcm':
        if record.get('method', 'rsync') not in ('preview', 'rsync', 'ftp', 'ftps', 'sftp'):
            raise ProfileError('Invalid website publication method')
        if record.get('method') in ('ftp', 'ftps', 'sftp') and record.get('strategy', 'Update') != 'Update':
            raise ProfileError('External FTP/SFTP hosting supports Update only')
        if record.get('strategy', 'Update') not in ('Update', 'Mirror'):
            raise ProfileError('Invalid synchronization strategy')
        if record.get('manage_site', 'No') not in ('Yes', 'No'):
            raise ProfileError('Invalid Nginx management choice')
        if record.get('website'):
            validate_name(record['website'])
        if record.get('host') and not VALID_HOST.fullmatch(record['host']):
            raise ProfileError('Invalid destination host')
        if record.get('user') and not (VALID_HOSTING_USER if record.get('method') in ('ftp', 'ftps', 'sftp') else VALID_USER).fullmatch(record['user']):
            raise ProfileError('Invalid destination user')
        if record.get('method') == 'preview' and record.get('manage_site') == 'Yes':
            raise ProfileError('Preview cannot manage a remote server')
        if record.get('method') in ('ftp', 'ftps', 'sftp') and record.get('manage_site') == 'Yes':
            raise ProfileError('External hosting cannot manage Nginx or DNS')
        port = record.get('port') or '22'
        preview_port = record.get('preview_port') or '8080'
        for label, value in (('port', port), ('preview_port', preview_port)):
            if not value.isascii() or not value.isdecimal() or not 1 <= int(value) <= 65535:
                raise ProfileError(f'Invalid {label}')
    else:
        if record.get('transport', 'local') not in ('local', 'remote'):
            raise ProfileError('Invalid SDK transport')
        if record.get('since_last', 'No') not in ('Yes', 'No'):
            raise ProfileError('Invalid since-last selection')


def blank(namespace: str) -> dict:
    return {'version': VERSION, 'namespace': namespace, 'selected': '',
            'migrations': [], 'profiles': []}


def load(path: Path, namespace: str) -> dict:
    if not path.exists():
        return blank(namespace)
    if path.is_symlink():
        raise ProfileError(f'Refusing symbolic link: {path}')
    with path.open(encoding='utf-8') as handle:
        data = json.load(handle)
    if not isinstance(data, dict) or data.get('version') != VERSION or data.get('namespace') != namespace:
        raise ProfileError('Unsupported profile store format or namespace')
    if not isinstance(data.get('profiles'), list) or not isinstance(data.get('migrations'), list) or not isinstance(data.get('selected'), str):
        raise ProfileError('Invalid profile store')
    names = set()
    for profile in data['profiles']:
        if not isinstance(profile, dict):
            raise ProfileError('Invalid profile record')
        validate_record(namespace, profile)
        if profile['name'] in names:
            raise ProfileError('Duplicate profile name')
        names.add(profile['name'])
    return data


@contextmanager
def locked_store(namespace: str):
    directory = config_dir()
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.is_symlink():
        raise ProfileError('Refusing symbolic link profile directory')
    os.chmod(directory, 0o700)
    lock_path = directory / f'.{namespace}.lock'
    if lock_path.is_symlink():
        raise ProfileError('Refusing symbolic link lock file')
    with lock_path.open('a+b') as handle:
        os.chmod(lock_path, 0o600)
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        path = directory / f'{namespace}.json'
        data = load(path, namespace)
        yield data, path


def write(path: Path, data: dict) -> None:
    fd, temp_path = tempfile.mkstemp(prefix=f'.{path.stem}.', suffix='.tmp', dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            json.dump(data, handle, indent=2, ensure_ascii=False)
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
        dir_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)


def find(data: dict, name: str) -> dict:
    return next((r for r in data['profiles'] if r['name'] == name), None)


def fields_from_args(namespace: str, values: list[str]) -> dict:
    result = {}
    for raw in values:
        if '=' not in raw:
            raise ProfileError('Fields must be supplied as key=value')
        key, value = raw.split('=', 1)
        if key not in EDITABLE[namespace]:
            raise ProfileError(f'Field is read-only or unknown: {key}')
        result[key] = value
    return result


def insert(data: dict, namespace: str, name: str, fields: dict, *, replace: bool) -> bool:
    record = find(data, name)
    if record is not None and not replace:
        return False
    new = dict(record or {})
    new.update(fields)
    new['name'] = name
    validate_record(namespace, new)
    if record is None:
        data['profiles'].append(new)
    else:
        record.clear()
        record.update(new)
    data['profiles'].sort(key=lambda r: (r.get('website', '').lower(), r['name'].lower()))
    return True


def migrate_wcm(data: dict, args: argparse.Namespace) -> int:
    marker = args.migration_id or 'legacy-wcm-2631102'
    if marker in data['migrations']:
        return 0
    entries = []
    current = fields_from_args('wcm', args.field)
    if any(current.get(key) for key in ('source', 'host', 'path', 'hostname')):
        current.setdefault('method', 'rsync')
        current.setdefault('manage_site', 'Yes')
        current.setdefault('strategy', 'Update')
        current['website'] = current.get('website') or current.get('hostname') or 'Legacy website'
        entries.append(('Legacy publication', current))
    count = 0
    for name, record in entries:
        name = validate_name(name)
        base = name
        suffix = 2
        while find(data, name):
            if find(data, name) == {**record, 'name': name}:
                break
            name = validate_name(f'{base} ({suffix})')
            suffix += 1
        if insert(data, 'wcm', name, record, replace=False):
            count += 1
    if entries:
        data['migrations'].append(marker)
        if count and not data['selected']:
            data['selected'] = entries[0][0]
    return count


def migrate_sdk(data: dict, args: argparse.Namespace) -> int:
    marker = args.migration_id or 'legacy-sdk-2631102'
    if marker in data['migrations']:
        return 0
    fields = fields_from_args('sdk', args.field)
    if not any(fields.get(key) for key in ('remote', 'product_root', 'source', 'target')):
        return 0
    fields.setdefault('transport', 'local')
    if args.timestamp:
        fields['last_success'] = args.timestamp
    fields['since_last'] = 'Yes' if fields.get('since_last', '').lower() in ('1', 'yes', 'y') else 'No'
    name = 'Legacy deployment'
    if find(data, name):
        name = 'Legacy deployment (2631102)'
    if insert(data, 'sdk', name, fields, replace=False):
        data['migrations'].append(marker)
        data['selected'] = data['selected'] or name
        return 1
    return 0


def execute(args: argparse.Namespace) -> int:
    namespace = args.namespace
    with locked_store(namespace) as (data, path):
        command = args.command
        if command == 'list':
            for profile in data['profiles']:
                if args.display and namespace == 'wcm':
                    print(profile.get('website', 'Website') + '\t' + profile['name'])
                else:
                    print(profile['name'])
            return 0
        if command == 'selected':
            print(data.get('selected', ''))
            return 0
        if command == 'get':
            record = find(data, args.name)
            if record is None:
                raise ProfileError(f'Profile does not exist: {args.name}')
            for field in FIELDS[namespace]:
                sys.stdout.buffer.write(field.encode('ascii') + b'\0')
                sys.stdout.buffer.write(record.get(field, '').encode('utf-8') + b'\0')
            return 0
        if command == 'save':
            name = validate_name(args.name)
            fields = fields_from_args(namespace, args.field)
            insert(data, namespace, name, fields, replace=True)
            if not data['selected']:
                data['selected'] = name
            write(path, data)
            return 0
        if command == 'delete':
            name = validate_name(args.name)
            if find(data, name) is None:
                raise ProfileError(f'Profile does not exist: {name}')
            data['profiles'] = [r for r in data['profiles'] if r['name'] != name]
            if data['selected'] == name:
                data['selected'] = ''
            write(path, data)
            return 0
        if command == 'select':
            name = validate_name(args.name)
            if find(data, name) is None:
                raise ProfileError(f'Profile does not exist: {name}')
            data['selected'] = name
            write(path, data)
            return 0
        if command == 'success':
            name = validate_name(args.name)
            record = find(data, name)
            if record is None:
                raise ProfileError(f'Profile does not exist: {name}')
            record['last_success'] = args.timestamp or datetime.now(timezone.utc).isoformat(timespec='seconds')
            write(path, data)
            return 0
        if command == 'migrate':
            count = migrate_wcm(data, args) if namespace == 'wcm' else migrate_sdk(data, args)
            if count:
                write(path, data)
            print(count)
            return 0
    raise ProfileError('Unsupported command')


def main() -> int:
    parser = argparse.ArgumentParser(description='SolidGroundUX shared deployment profile store')
    parser.add_argument('namespace', choices=('wcm', 'sdk'))
    parser.add_argument('command', choices=('list', 'selected', 'get', 'save', 'delete', 'select', 'success', 'migrate'))
    parser.add_argument('--name', default='')
    parser.add_argument('--display', action='store_true')
    parser.add_argument('--field', action='append', default=[], help='Named setting (key=value)')
    parser.add_argument('--migration-id', default='')
    parser.add_argument('--timestamp', default='')
    args = parser.parse_args()
    try:
        return execute(args)
    except (ProfileError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f'Profile store: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
