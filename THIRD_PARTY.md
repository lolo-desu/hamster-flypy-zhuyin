# Third-party source and licenses

The lock file and preparation script identify exact primary source revisions. No upstream license is removed during assembly.

| Component | Source | License / role |
| --- | --- | --- |
| Hamster | https://github.com/imfuxiao/Hamster | MIT; app and keyboard |
| rime-frost | https://github.com/gaboolic/rime-frost | GPL-3.0 repository license; dictionaries, Lua, model; preserve per-file notices |
| LibrimeKit-iOS scripts | https://github.com/thomfang/LibrimeKit-iOS | MIT; cross compilation |
| librime | framework project's pinned submodule | BSD-3-Clause |
| librime-lua | https://github.com/hchunhui/librime-lua | BSD-3-Clause; Lua has its own MIT license |
| librime-octagram | https://github.com/lotem/librime-octagram | GPL-3.0 |
| Boost | framework project's dependency | BSL-1.0 |
| OpenCC, glog, leveldb, marisa, yaml-cpp | framework project's recursive sources | Preserve each upstream license |
| Swift packages | Hamster Package.swift / Package.resolved | Preserve each upstream license |

The display-only additions in src/FlypyZhuyin.swift are MIT; that does not relicense the assembled app. Distribute the combined binary with corresponding source and all applicable notices, including GPL requirements. The build uses no proprietary Apple keyboard assets.
