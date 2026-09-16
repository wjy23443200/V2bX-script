#!/usr/bin/env python3
"""Read portable panel presets as data, never as shell code."""
import argparse
import json
import os
from pathlib import Path
import tempfile
import sys
from urllib.parse import urlsplit

DEFAULT = '/etc/V2bX/profile.json'

def validate(data):
    if not isinstance(data, dict) or data.get('Version') != 1:
        raise ValueError('配置包版本不支持（需要 Version: 1）')
    if set(data) != {'Version', 'ApiHost', 'ApiKey', 'FixedAPI', 'Audit'}:
        raise ValueError('配置包字段不完整或包含未知字段')
    for key in ('ApiHost', 'ApiKey'):
        if not isinstance(data[key], str) or not data[key] or any(ord(c) < 32 for c in data[key]):
            raise ValueError(key + ' 不能为空或包含控制字符')
    url = urlsplit(data['ApiHost'])
    if url.scheme not in ('https', 'http') or not url.netloc or url.username or url.password or url.query or url.fragment:
        raise ValueError('面板地址必须是有效的 HTTP/HTTPS 地址，不能包含密码或查询参数')
    if type(data['FixedAPI']) is not bool:
        raise ValueError('FixedAPI 必须为 true 或 false')
    if data['Audit'] != 'builtin':
        raise ValueError('当前配置包仅支持 V2bX 自带审计规则（builtin）')
    return data

def load(path):
    with open(path, encoding='utf-8') as stream:
        return validate(json.load(stream))

def save(path, data):
    validate(data)
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.v2bx-profile-', dir=str(target.parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        os.replace(temporary, str(target))
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

def main():
    parser = argparse.ArgumentParser(description='V2bX 本地配置包')
    parser.add_argument('--profile', default=DEFAULT)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('validate')
    show = sub.add_parser('show')
    show.add_argument('--show-key', action='store_true', help='在本机终端显示完整密钥')
    value = sub.add_parser('value')
    value.add_argument('field', choices=['ApiHost', 'ApiKey', 'FixedAPI', 'Audit'])
    incoming = sub.add_parser('import')
    incoming.add_argument('source')
    outgoing = sub.add_parser('export')
    outgoing.add_argument('destination')
    sub.add_parser('encode')
    args = parser.parse_args()
    try:
        if args.command == 'encode':
            print(json.dumps(sys.stdin.read(), ensure_ascii=False)[1:-1])
        elif args.command == 'import':
            save(args.profile, load(args.source))
            print('配置包已导入；以后生成配置会自动读取。')
        elif args.command == 'export':
            save(args.destination, load(args.profile))
            print('配置包已导出，请通过 SSH 文件传输到新服务器。')
        elif args.command == 'value':
            value = load(args.profile)[args.field]
            print(str(value).lower() if isinstance(value, bool) else value)
        elif args.command == 'show':
            data = load(args.profile)
            key = data['ApiKey']
            shown = key if args.show_key else ('********' + (key[-4:] if len(key) > 4 else ''))
            print('面板地址：' + data['ApiHost'])
            print('API Key：' + shown)
            print('固定面板：' + ('Y' if data['FixedAPI'] else 'N'))
            print('审计规则：V2bX 自带')
            print('状态：本地配置已读取；尚未验证面板连接。')
        else:
            load(args.profile)
    except (OSError, ValueError, TypeError) as error:
        # Never print JSON contents or parser excerpts: they may contain the API key.
        print('配置包操作失败，请检查文件路径、权限及格式。', file=sys.stderr)
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
