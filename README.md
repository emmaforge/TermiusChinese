# TermiusChinese — Termius iOS 汉化插件

Termius iOS 的运行时汉化插件：不改 IPA、不改账号数据，只在界面显示层把英文换成中文。

适用于两种装法，二选一即可：

| 装法 | 适合 | 原理 |
|---|---|---|
| 越狱安装 `.deb` | 已越狱（包括 Relaxin / RootHide，Sileo 安装） | ElleKit 注入，`TermiusChinese.plist` 只对 Termius 生效 |
| 巨魔注入 dylib | 有 TrollStore、无越狱，或越狱后不想装 deb | TrollFools 把编译出的 dylib 注入 Termius，词典编译在 dylib 里，不依赖外部文件 |

> 状态：**v0.1.0 可用框架 + 1278 条词条，未经真机 IPA 验证。**
> 词条来自桌面版汉化规则，iOS 真实文案还没对过——先装上看效果，再按下面“补 iOS 真实词条”一节把没翻到的补齐。
> 这不是“全局改所有文字”：终端会话内容、输入框内容、主机名、用户名、文件名、命令一律不翻译（见“安全边界”）。

## 先核对一件事：你的 Termius 是不是这个包

插件的 Filter 写的是：

- Bundle ID：`com.crystalnix.ServerAuditor`
- 可执行文件名：`Termius`

如果装上没效果，先别怀疑词典，先在手机上核对这两项（Filza / 终端，Termius 已安装时）：

```sh
# 找到 Termius.app 后看 Info.plist
plutil -p Termius.app/Info.plist | grep -E 'CFBundleIdentifier|CFBundleExecutable'
ls Termius.app/ | head
```

`CFBundleIdentifier` 或可执行文件名对不上，插件根本不会加载，把 `TermiusChinese.plist` 改成实测值、重新编译即可。
App Store 版 IPA 是加密的，电脑上解包看不到真实字符串；要对词条，必须在已越狱手机上用解密后的应用做提取（见下）。

## 安装

### A. 越狱（Relaxin / RootHide）

需要先装好 ElleKit（Relaxin 自带 Sileo 源里有）。本插件不需要 PreferenceLoader，没有设置面板，装上即生效。

```sh
# 在装有 Theos 的 Mac / Linux 上
git clone https://github.com/emmaforge/TermiusChinese.git
cd TermiusChinese
make package
# 得到的 .deb 传到手机，用 Sileo / Filza 安装，注销或重启 Termius
```

RootHide 说明：本插件是 rootless 包（`THEOS_PACKAGE_SCHEME = rootless`），
不写系统目录；如果你的环境提示“不支持隐根插件请转换”，用 RootHide Patcher 转换一次再装，
不要改回 rootful 路径。

### B. TrollStore / TrollFools（无越狱也行）

1. 在 Theos 环境 `make` 一次，拿到 `.theos/obj/TermiusChinese.dylib`
   （不要只拿 deb 里的，TrollFools 要的就是这个 dylib）。
2. 手机上装好 TrollStore 版 Termius（App Store 版），再装 TrollFools。
3. TrollFools 里选 Termius → 注入 `TermiusChinese.dylib`。
4. 彻底杀掉 Termius 后台再重开。

注意：TrollStore 本身只支持到 iOS 17.0（CoreTrust 漏洞范围），17.0.1+ 不适用；
Relaxin 越狱覆盖的是 iOS 17.0–17.3.1 等机型，以各自工具的官方支持列表为准。

## 它到底翻译什么

只翻译 UIKit 显示层，且**整句全匹配**才换：

- `UILabel`、`UIButton` 标题、`UINavigationItem` / `UITabBarItem` / `UIBarButtonItem` 标题
- `UITextField` / `UISearchBar` 的 placeholder（占位提示）
- `UIAlertController` 标题/消息、`UIAlertAction` 按钮、`UISegmentedControl` 分段标题
- `NSBundle localizedStringForKey:`（`.strings` / `NSLocalizedString` 走这条路的）

整句全匹配的意思：界面文字必须和词典 key 一字不差（首尾空格除外）才换，
不会把“Connect to xxx”里的 Connect 抠出来换，也不会动任何带换行符的长文本。
这就是它“全局”但又不伤数据的关键。

### 安全边界（特意不做的）

- ❌ 不 hook `UITextView.text`、`UITextField.text`：那是终端输出和你输入的主机/账号/命令。
- ❌ 不做子串、正则替换：桌面版 `localize.txt` 里 113 条正则和 JS 结构改写
  在 iOS 上没有意义，照搬会改坏界面甚至闪退，本项目已全部丢弃。
- ❌ 不碰登录、订阅、同步逻辑：只改显示文字，不改 Pro / 试用 / 跳过登录。
  桌面版脚本里的 `--trial`、`--skip-login` 在此项目里**没有、也不打算有**。

## 词典来源与数量

- 来源：[ArcSurge/Termius-Pro-zh_CN](https://github.com/ArcSurge/Termius-Pro-zh_CN)
  的桌面版 `rules/localize.txt`（1634 行，2026-11-03 取）。
- 转换：`tools/convert_localize.py`，规则见文件头注释。
  丢弃：85 条注释、113 条正则、42 条左右引号数对不上的规则；
  保留：**1278 条**整句 UI 短语，见 `TermiusChinese/zh_dict.json`。
- 人工修正了 3 个桌面版上下文歧义：`Hosts → 主机`（不是“远程主机”）、
  `Advanced → 高级`、`Team → 团队`；删了单字 `no`（太泛，容易误伤）。

桌面版是 Electron JS bundle 字符串替换，iOS 是另一套 UI：
桌面有、iOS 没有的词条无害（永远匹配不上）；iOS 有、桌面没有的
（如 Face ID、iCloud、App Store 订阅、iOS 专属提示）目前一定缺，
必须用下面方法从真机提取后补。

## 补 iOS 真实词条（最重要的一步）

在手机上（已越狱、Termius 已解密安装）跑：

```sh
sh tools/extract_ios_strings.sh /path/to/Termius.app > ios_strings.txt
```

脚本只做三件事：列出 `.lproj`、用 `strings` 扫主二进制、
列出 `*.strings` / `*.storyboard` 文件名；不上传、不改应用。
把 `ios_strings.txt` 里没翻到的英文发回来（或自己按 `zh_dict.json` 格式补），
重新生成 `zh_dict.h`、重新编译即可。

没有 IPA 也能做第一步核对：先确认上面 Bundle ID / 可执行文件名，
再在 Termius 里逐页截图，记下仍显示英文的界面文字——那就是下一批词条。

## 常见问题

- **装上完全没变化**：先核对 Bundle ID / 可执行文件名；再看日志有没有
  `[TermiusChinese] loaded`；TrollFools 注入后必须杀后台重开。
- **有的页面翻了、有的没翻**：正常。没翻的页面大概率是 SwiftUI / 自定义绘制 /
  网页视图，不走 UILabel；或者它的英文和桌面版措辞不一样，等提取后补词条。
- **终端里命令输出变了**：不应该发生。本插件不 hook 终端文本，
  如果真遇到，先停用插件并把那行原样记下来——那是需要修的 bug，不是“词典问题”。
- **Termius 更新后失效**：新版文案变了就匹配不上，重新提取、更新词典即可；
  更新前备份好能用的 deb / dylib。

## 免责与来源声明

- 本项目仅供学习和交流，禁止商业用途与二次出售；词典部分沿用上游桌面汉化项目的
  学习交流性质，版权归原作者与 Termius 官方所有。
- 插件代码（`Tweak.m` 等）为本项目原创；词典译文来自 ArcSurge 桌面版规则转换，
  已在上文注明来源与改动。
- 使用修改版应用可能影响官方更新与账号安全，请自行判断风险，改动前备份。
