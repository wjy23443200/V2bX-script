# 在全新 VPS 上安装 V2bX

这份仓库只提供**全新 VPS 的安装步骤**。安装脚本会检查服务器上是否已有 V2bX；如果已有文件或服务，会停止，不会覆盖原配置。V2bX 核心程序从 [上游项目](https://github.com/wyx2685/V2bX)下载。

准备一台能连接 GitHub、运行受支持 Debian / Ubuntu 版本的全新 VPS，并以 `root` 登录。旧系统的软件源可能无法下载依赖。

## 第 1 步：准备面板配置文件

在**自己的电脑**下载仓库中的 [profile.example.json](profile.example.json)，复制并重命名为 `v2bx.private.json`。用文本编辑器修改其中两项：

- `ApiHost`：你的面板地址，例如 `https://panel.example.com`。
- `ApiKey`：你的面板对接 API Key。

其余字段先保持示例值。`FixedAPI: false` 表示添加多个节点时可以选择不同面板；`Audit: "builtin"` 表示使用脚本自带规则。配置文件**不要提交到 GitHub**。

## 第 2 步：上传配置文件

在 Netcatty 的 SFTP 中，左栏选本机，右栏选这台 VPS。右栏进入 `/root`，把 `v2bx.private.json` 从左栏上传过去。上传完成后，右栏应看到 `/root/v2bx.private.json`。

## 第 3 步：在 VPS 的 SSH 终端依次执行

每行运行成功后再运行下一行：

```bash
apt-get update && apt-get install -y curl
curl -fL https://raw.githubusercontent.com/wjy23443200/V2bX-script/master/install.sh -o /root/install-v2bx.sh
bash /root/install-v2bx.sh
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

安装程序会将配置文件保存到 `/etc/V2bX/profile.json`，并把配置文件权限设为仅 root 可读写。`/root/v2bx.private.json` 含有 API Key，也应只在自己的设备和 VPS 上保存。
