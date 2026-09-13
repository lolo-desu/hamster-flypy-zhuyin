#!/usr/bin/env python3
"""Fail the build if the extension, offline data or unsigned layout is missing."""
from pathlib import Path
import plistlib
import sys
import zipfile
app = Path(sys.argv[1])
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert (app / info['CFBundleExecutable']).is_file()
extensions = list((app / 'PlugIns').glob('*.appex'))
assert extensions, 'No keyboard extensions'
assert any(plistlib.loads((p / 'Info.plist').read_bytes()).get('NSExtension', {}).get('NSExtensionPointIdentifier') == 'com.apple.keyboard-service' for p in extensions)
assert not list(app.rglob('_CodeSignature')), 'Unexpected signature'
assert not list(app.rglob('embedded.mobileprovision')), 'Unexpected provisioning profile'
archives = list(app.rglob('rime-ice.zip'))
assert len(archives) == 1, 'Offline Frost archive not bundled'
with zipfile.ZipFile(archives[0]) as z:
    for required in ['rime_frost_double_pinyin_flypy.schema.yaml', 'rime_frost.dict.yaml', 'default.custom.yaml', 'zh-moqi.gram', 'lua/aux_lookup_filter.lua']:
        assert required in z.namelist(), required
    assert 'rime_frost_double_pinyin_flypy' in z.read('default.custom.yaml').decode()
assert list(app.rglob('SharedSupport.zip'))
print('Unsigned app, keyboard extension and offline Frost resources verified')
