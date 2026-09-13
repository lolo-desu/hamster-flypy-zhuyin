# 仓 · 白霜小鹤动态注音

这是一个基于仓公开源码的最小改造工程：26 键位置仍为 QWERTY，发送给 Rime 的仍是小鹤双拼 ASCII 编码，键帽与按下气泡显示注音。声母输入后显示韵母，第二码输入后返回声母层。无声调选择，不改白霜候选排序配置。

**当前状态：Swift 状态测试、离线资源打包测试和干净上游补丁检查通过；未完成 GitHub macOS 构建和 iPhone 验收，尚无已验证的 IPA。**

工程以「固定上游提交 + 小补丁」组织。无需复制并维护整个仓源码，`scripts/prepare.py` 自动组装；源码、词库和依赖版本见 `upstream.lock.json`。

## 键盘行为

- 第一层：Q=ㄑ、W=ㄨ、E=ㄜ、R=ㄖ、U=ㄕ、I=ㄔ、V=ㄓ等。
- 第二层：H=ㄤ、J=ㄢ、M=ㄧㄢ；L 在 X 后是 ㄧㄤ，在 H 后是 ㄨㄤ。其余多韵母键依据小鹤前一码显示对应符号。
- Y/W 并非独立的注音声母，键帽用 ㄧ/ㄨ；A/E/O 是零声母起始键，显示 ㄚ/ㄜ/ㄛ。`aa/ee/oo/ah` 等仍按小鹤规则输入。
- `nihc` 仍输入「你好」。只改显示，候选区的拼音预编辑保留白霜原样。
- 删除、清空、上屏、移动组字光标后，从 Rime 原始编码及光标位置重算层级。不会使用已展开为完整拼音的 preedit 长度。
- 保留所有物理键；不按音节合法性隐藏按键。符号指令、辅码和大写英文编码回退到原字母显示。
- 生效范围是仓的标准中文 26 键与白霜小鹤方案；英文、数字、符号、自定义布局和九宫格沿用上游行为。

完整调查与验收规划见 [docs/调查与实施.md](docs/调查与实施.md)。

## GitHub Actions

1. 创建公开仓库，将本目录所有文件（包括 `.github`）放到仓库根目录，默认分支为 `main`。
2. 推送自动触发 **Build unsigned iOS IPA**，或在 Actions 手动运行。
3. 首次运行会复用 LibrimeKit-iOS 的构建脚本编译 Rime + Lua + octagram 并缓存框架。首次可能耗时一小时以上；超时上限三小时。
4. 成功后下载 `Hamster-Flypy-Zhuyin-unsigned` artifact，解压得到 IPA、SHA256SUMS 和版本记录。
5. IPA 构建关闭代码签名，直接以 `Payload/Hamster.app` 打包；不需要证书、Apple ID 或签名 secrets。

目前上游旧的 `imfuxiao/LibrimeKit/2.4.2` 下载链接返回 404，因此没有沿用它。可用的新框架发布包不含白霜语法插件，本工程用现有源码构建流程补齐插件，而不悄悄忽略排序模型。此外，Hamster 工程还引用了源码构建不产出的三个框架，`build-frameworks.sh` 按下述方式补齐，并逐项校验全部 12 个框架就位后才进入归档：

- `librime-sbxlm`：供独立的 SbxlmKeyboard target 链接，上游原包就是一个完整 librime 构建（含声笔插件）。本工程不含声笔方案，直接复用刚编好的 librime 副本提供 `rime_*` 符号；两个 slice 的库改名为 `librime-sbxlm.a` 后用 `xcodebuild -create-xcframework` 重新打包（Info.plist 由 Xcode 工具生成，不带 Headers），既避免与 `librime` 产生重复产物冲突，也避免手改 plist 带来的兼容性问题；打包后用 nm 自检副本确实携带 `RimeSetOption` 等链接期符号；
- `boost_atomic` / `boost_locale`：仅存在于工程链接阶段的引用，librime 与全部上层源码均未引用其符号（已逐字核查），用空桩静态库打包成 xcframework 满足引用，不增加体积。

## 本地检查与构建

```sh
bash scripts/test.sh
python3 scripts/prepare.py
bash scripts/build-frameworks.sh
bash scripts/build-ipa.sh
```

状态逻辑测试可在安装 Swift 的 macOS/Linux 运行。iOS 归档必须在 macOS + Xcode 环境进行。`work/` 是生成目录，`dist/` 是 IPA 输出目录。

## 安装与离线使用

- 用支持 iOS 键盘扩展的工具自行签名；必须一起签主 App 和 `PlugIns` 内的扩展。
- 当前沿用上游 Bundle IDs。共享组为 `group.dev.fuxiao.app.Hamster`。签名配置必须保留可工作的同一 App Group；仅修改主 App 标识而破坏共享组会使词库无法读取。若要改共享组，须同步修改源代码常量和所有 entitlement 后重新构建。不能保证所有免费重签工具都支持此场景。
- 安装后先打开主 App，完成本地初始化和 Rime 部署，选择「白霜小鹤双拼」，使用标准中文 26 键布局。
- 在 iOS 设置中添加 HamsterKeyboard。此公开版仓使用 App Group 读写本地部署数据，需要按上游要求开启「允许完全访问」；这与运行时必须联网是不同的事。
- 词库、Lua、OpenCC 和 `zh-moqi.gram` 均内置。输入过程无需在线服务。默认关闭 iCloud；本补丁移除未使用的 iCloud/推送签名 entitlement。不要启用旧版设置中的 iCloud 同步功能。
- 首次部署完成后用飞行模式测试输入。需要分别验收候选、删字、光标、横屏、深色模式以及重启后的个人词频。
- 普通键盘操作复用仓，不能承诺和苹果系统键盘所有功能相同。密码/部分电话输入框及禁止第三方键盘的 App 会切回系统键盘，这是 iOS 的平台约束。

## 许可

新增 Swift 文件为 MIT。仓上游 MIT 许可保留。白霜和 octagram 的许可证随其固定来源保留；octagram 使用 GPL-3.0，组合发布不能仅标注为 MIT。公开仓库应同时提供本工程与固定版本源码/构建脚本；分发二进制时还应提供对应源码与依赖许可。见 [THIRD_PARTY.md](THIRD_PARTY.md)。
