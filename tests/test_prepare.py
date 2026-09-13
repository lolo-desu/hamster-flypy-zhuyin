import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prepare', ROOT / 'scripts/prepare.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)

class OfflinePackagingTests(unittest.TestCase):
    def test_offline_payload_preserves_weights_lua_and_model(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            frost, app = root/'frost', root/'Hamster'
            fixture = {
                'default.yaml': b'schema_list: []\n',
                'key_bindings.yaml': b'key_bindings: {}\n',
                'punctuation.yaml': b'punctuator: {}\n',
                'rime_frost.dict.yaml': '测试\tce shi\t123456\n'.encode(),
                'rime_frost_double_pinyin_flypy.schema.yaml': b'grammar:\n  language: zh-moqi\n',
                'lua/filter.lua': b'return function() end\n',
                'zh-moqi.gram': b'original binary model\x00',
                'opencc/t2s.json': b'{}',
                'LICENSE': b'upstream license',
            }
            for name, data in fixture.items():
                p=frost/name; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(data)
            resources=app/'Resources/SharedSupport'
            resources.mkdir(parents=True)
            (resources/'hamster.yaml').write_text('general:\n  enableAppleCloud: false\n')
            prepare.package_frost(frost,app)
            with zipfile.ZipFile(resources/'rime-ice.zip') as z:
                for name,data in fixture.items(): self.assertEqual(z.read(name),data)
                self.assertEqual(z.read('default.custom.yaml').decode(), 'patch:\n  schema_list:\n    - schema: rime_frost_double_pinyin_flypy\n')
                self.assertIsNone(z.testzip())
            with zipfile.ZipFile(resources/'SharedSupport.zip') as z:
                self.assertIn('opencc/t2s.json',z.namelist())
                self.assertIn('hamster.yaml',z.namelist())
                self.assertNotIn('zh-moqi.gram',z.namelist())

if __name__ == '__main__': unittest.main()
