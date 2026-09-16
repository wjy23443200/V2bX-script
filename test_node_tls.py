"""Run only the node builder; never source the installer or touch services."""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parent

class NodeTLS(unittest.TestCase):
    def run_nodes(self, filename, answers, fixed=True):
        source = (ROOT / filename).read_text()
        function = source[source.index('add_node_config() {'):source.index('generate_config_file() {')]
        if not fixed:
            function = function.replace('    local istls="n" isreality="n"\n', '')
        script = function + '\ncheck_ipv6_support() { echo 0; }\n'
        script += 'core_xray=false; core_sing=false; core_hysteria2=false\n'
        script += 'ApiHost=https://example.com; ApiKey=test; nodes_config=()\n'
        for answer in answers:
            script += "add_node_config <<'ANSWERS' >/dev/null\n" + answer + '\nANSWERS\n'
        script += "printf '%s\\n' \"${nodes_config[@]}\"\n"
        result = subprocess.run(['bash'], input=script, text=True, capture_output=True, timeout=10, check=True)
        return json.loads('[' + result.stdout.rstrip().rstrip(',') + ']')

    def test_sequences(self):
        ss = '2\n2\n1\nn'
        anytls = '2\n1\n8\n3\nexample.com'
        reality = '2\n3\n2\ny'
        tls = '2\n4\n3\ny\n3\nexample.com'
        for filename in ['V2bX.sh', 'initconfig.sh']:
            for sequence, modes in [([ss], ['none']), ([anytls, ss], ['self', 'none']),
                                    ([reality, anytls], ['none', 'self']),
                                    ([tls, ss], ['self', 'none']),
                                    ([ss, anytls], ['none', 'self'])]:
                with self.subTest(file=filename, modes=modes):
                    nodes = self.run_nodes(filename, sequence)
                    self.assertEqual([n['CertConfig']['CertMode'] for n in nodes], modes)
            # Regression proof: the upstream function misconfigures the second node.
            old_nodes = self.run_nodes(filename, [anytls, ss], fixed=False)
            self.assertNotEqual(old_nodes[1]['CertConfig']['CertMode'], 'none')

if __name__ == '__main__':
    unittest.main()
