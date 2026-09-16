"""Exercise local presets and the real configuration builders in a temporary directory."""
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
HELPER = ROOT / 'profile.py'

class Profiles(unittest.TestCase):
    def test_script_update_uses_system_install(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / 'bin').mkdir()
            script = (ROOT / 'V2bX.sh').read_text()
            function = script[script.index('update_shell() {'):script.index('# 0: running', script.index('update_shell() {'))]
            function = function.replace('/usr/local/V2bX', str(base / 'runtime')).replace('/usr/bin/V2bX', str(base / 'bin/V2bX'))
            script = 'install() { echo unexpected-core-install >&2; exit 95; }\n'
            script += 'curl() { while [ "$1" != "-o" ]; do shift; done; printf "#!/bin/bash\\n" > "$2"; }\n'
            script += function + '\nupdate_shell\n'
            result = subprocess.run(['bash'], input=script, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((base / 'runtime/profile.py').is_file())
            self.assertTrue((base / 'bin/V2bX').is_file())

    def test_import_export_and_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            original = base / 'input.json'
            stored = base / 'saved.json'
            exported = base / 'exported.json'
            data = dict(Version=1, ApiHost='https://panel.example.com', ApiKey='test-key', FixedAPI=False, Audit='builtin')
            original.write_text(json.dumps(data))
            for command, path in [('import', original), ('export', exported)]:
                subprocess.run(['python3', str(HELPER), '--profile', str(stored), command, str(path)], check=True, capture_output=True)
            self.assertEqual(json.loads(exported.read_text()), data)
            self.assertEqual(stat.S_IMODE(stored.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(exported.stat().st_mode), 0o600)
            original.write_text('{"ApiKey":"private-marker", invalid}')
            bad = subprocess.run(['python3', str(HELPER), '--profile', str(stored), 'import', str(original)], capture_output=True, text=True)
            self.assertNotEqual(bad.returncode, 0)
            self.assertNotIn('private-marker', bad.stderr)
            self.assertEqual(json.loads(stored.read_text()), data)

    def test_both_wizards_with_presets(self):
        for filename in ['V2bX.sh', 'initconfig.sh']:
            with self.subTest(wizard=filename), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                config_dir = base / 'config'
                config_dir.mkdir()
                (config_dir / 'config.json').write_text('{}')
                sentinel = base / 'must-not-exist'
                secret = 'test-"quote"-\\slash-$(touch ' + str(sentinel) + ')'
                profile = base / 'preset.json'
                profile.write_text(json.dumps(dict(Version=1, ApiHost='https://panel.example.com', ApiKey=secret, FixedAPI=False, Audit='builtin')))
                text = (ROOT / filename).read_text()
                text = text[text.index('# Local presets'):]
                if filename == 'V2bX.sh':
                    text = text[:text.index('# 放开防火墙端口')]
                text = text.replace('/etc/V2bX', str(config_dir))
                text += '\ncheck_ipv6_support() { echo 0; }\nrestart() { :; }\nbefore_show_menu() { :; }\nv2bx() { :; }\ngenerate_config_file\n'
                env = dict(os.environ, V2BX_PROFILE=str(profile), V2BX_PROFILE_HELPER=str(HELPER))
                # First panel is automatic; FixedAPI=false allows accepting the preset for node two.
                answers = '2\n11\n1\nn\n\n\n2\n12\n1\nn\nn\n'
                script = base / 'wizard.sh'
                script.write_text(text)
                result = subprocess.run(['bash', str(script)], input=answers, env=env, capture_output=True, text=True, timeout=15)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn(secret, result.stdout + result.stderr)
                self.assertFalse(sentinel.exists())
                nodes = json.loads((config_dir / 'config.json').read_text())['Nodes']
                self.assertEqual([node['NodeID'] for node in nodes], [11, 12])
                self.assertTrue(all(node['ApiKey'] == secret for node in nodes))
                self.assertTrue(all(node['CertConfig']['CertMode'] == 'none' for node in nodes))
                self.assertIn('bittorrent', (config_dir / 'route.json').read_text())
                self.assertIn('domain_regex', (config_dir / 'sing_origin.json').read_text())

if __name__ == '__main__':
    unittest.main()
