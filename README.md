# V2bX

本分支修复多节点向导中 TLS / Reality 状态跨节点残留的问题，覆盖 `V2bX.sh` 和首次安装使用的 `initconfig.sh`。例如 AnyTLS 后添加 Shadowsocks，不会再自动进入证书选择；Reality 后添加 AnyTLS 也会正常配置证书。

脚本安装和更新地址指向本仓库，V2bX 核心程序仍从原上游下载。

回归测试（无需 root，不安装服务）：`python3 test_node_tls.py`。

## 本地配置包

支持把面板地址、API Key、固定面板选项和审计选项保存在一个本地 JSON 文件中。真实密钥不要提交到仓库；仓库中的 `profile.example.json` 只有示例值。

默认配置：`FixedAPI: false`（对应 N），`Audit: "builtin"`（使用本版本 V2bX 自带审计规则）。规则随脚本提供，配置包保存选择，不包含节点 ID 或协议。

### 新服务器

通过 FinalShell 上传你的配置包到 `/root/v2bx.private.json`，再执行：

```bash
curl -fLsS https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/install.sh -o install.sh
V2BX_PROFILE=/root/v2bx.private.json bash install.sh
```

安装程序会把配置包保存到 `/etc/V2bX/profile.json`，权限设为 600。进入生成向导后，第一个节点自动读取面板地址、API Key 和固定面板选项，并使用自带审计规则。只需配置节点 ID、内核和协议等节点信息。

固定面板选 N 时，后续节点会询问是否继续使用预设，回车即可，也可以选 n 输入另一套面板信息；选 Y 时所有节点自动共用预设。

### 已安装的服务器

首次启用本功能，先下载管理脚本和配置包助手（不重新安装核心、不重启服务）：

```bash
curl -fLsS https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/V2bX.sh -o /tmp/V2bX-profile-update.sh
bash -n /tmp/V2bX-profile-update.sh && bash /tmp/V2bX-profile-update.sh update_shell
```

需要已安装 Python 3；新安装流程会安装它。然后导入并生成节点配置：

```bash
v2bx profile-import /root/v2bx.private.json
v2bx generate
```

导入和导出只管理本地预设；`generate` 会按照原脚本行为覆盖节点配置并重启服务。

### 查看和迁移

```bash
v2bx profile-show
v2bx profile-show --show-key
v2bx profile-export /root/v2bx.private.json
```

默认只显示密钥末尾四位，`--show-key` 会在本机终端显示完整密钥。读取成功不代表面板鉴权成功。导出的配置包包含完整密钥，只通过可信的 SSH 文件传输分发；请勿提交到 GitHub 或放到公开下载链接。新服务器导入同一文件即可复用。

配置包测试：`python3 test_profile.py`。测试覆盖导入导出、权限、错误配置保护，以及两个向导生成多节点配置的完整流程，不修改系统服务。

A V2board node server based on Xray-Core.

一个基于Xray的V2board节点服务端，支持V2ay,Trojan,Shadowsocks协议

Find the source code here: [InazumaV/V2bX](https://github.com/InazumaV/V2bX)

如对脚本不放心，可使用此沙箱先测一遍再使用：https://killercoda.com/playgrounds/scenario/ubuntu

# 详细使用教程

[教程](https://v2bx.v-50.me/)

# 一键安装

```
wget -N https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/install.sh && bash install.sh
```
