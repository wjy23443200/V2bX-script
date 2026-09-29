# 在全新 VPS 上安装 V2bX

这份仓库提供**全新 VPS 的安装步骤**和 [V2bX 核心程序包](https://github.com/wjy23443200/V2bX-script/releases/tag/core-v0.4.0)。安装脚本会检查服务器上是否已有 V2bX；如果已有文件或服务，会停止，不会覆盖原配置。核心程序固定为 v0.4.0，直接从**本仓库的 Release**下载，不再依赖已归档的上游发布地址。

准备一台能连接 GitHub、运行受支持 Debian / Ubuntu 版本的全新 VPS，并以 `root` 登录。旧系统的软件源可能无法下载依赖。

## 第 1 步：准备面板配置文件

在**自己的电脑**下载仓库中的 [profile.example.json](profile.example.json)，复制并重命名为 `v2bx.private.json`。用文本编辑器修改其中两项：

- `ApiHost`：你的面板地址，例如 `https://panel.example.com`。
- `ApiKey`：你的面板对接 API Key。

其余字段先保持示例值。`FixedAPI: false` 表示添加多个节点时可以选择不同面板；`Audit: "builtin"` 表示使用脚本自带规则。配置文件**不要提交到 GitHub**。

## 第 2 步：上传配置文件

在 Netcatty 的 SFTP 中，左栏选本机，右栏选这台 VPS。右栏进入 `/root`，把 `v2bx.private.json` 从左栏上传过去。上传完成后，右栏应看到 `/root/v2bx.private.json`。

## 第 3 步：在 VPS 的 SSH 终端执行一行命令

复制下面整行执行。它会安装所需的下载工具、运行本仓库的安装脚本，并从本仓库的 Release 下载对应架构的 V2bX 核心；无需手工再下载程序包。

```bash
apt-get update && apt-get install -y curl && curl -fLsS https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/install.sh -o /root/install-v2bx.sh && bash /root/install-v2bx.sh
```

安装脚本会读取刚上传的配置文件、安装依赖与 V2bX，然后自动进入**首次节点配置向导**。按屏幕提示依次选择节点核心、输入面板中的 Node ID、选择协议及其选项；第一个节点的面板地址和 API Key 会从配置文件读取，不用再输入。如果继续添加节点，询问是否使用同一面板时直接回车即可。配置完成后，脚本会启动服务。

## 第 4 步：确认安装结果

```bash
v2bx status
```

如果状态不是运行中，查看日志：

```bash
v2bx log
```

## 安装中断后重试

如果 SSH 掉线后再次安装提示“检测到已有 V2bX 文件或服务”，并且输入 `v2bx` 显示 `command not found`，先执行下面这一整行清理残留：

```bash
curl -fLsS https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/cleanup-partial.sh -o /root/cleanup-v2bx.sh && bash /root/cleanup-v2bx.sh
```

清理脚本会拒绝处理正在运行的 V2bX 或已存在 `v2bx` 命令的安装。它把本安装程序可能留下的目录、服务文件和命令移到 `/root/v2bx-recovery.*` 备份目录；**不会删除**你上传的 `/root/v2bx.private.json`。清理成功后，重新执行第 3 步的安装命令。

安装程序会将配置文件保存到 `/etc/V2bX/profile.json`，并把配置文件权限设为仅 root 可读写。`/root/v2bx.private.json` 含有 API Key，也应只在自己的设备和 VPS 上保存。

## 核心程序来源

本仓库的 [core-v0.4.0 Release](https://github.com/wjy23443200/V2bX-script/releases/tag/core-v0.4.0) 镜像了上游 [wyx2685/V2bX v0.4.0](https://github.com/wyx2685/V2bX/tree/v0.4.0) 的 Linux x86_64、ARM64、s390x 程序包，并附有对应源码归档。原项目采用 MPL-2.0 许可证；这里没有修改核心程序。安装脚本会核对每个程序包的 SHA-256。此镜像版本不会自动跟随上游更新。
