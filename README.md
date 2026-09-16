# V2bX

本分支修复多节点向导中 TLS / Reality 状态跨节点残留的问题，覆盖 `V2bX.sh` 和首次安装使用的 `initconfig.sh`。例如 AnyTLS 后添加 Shadowsocks，不会再自动进入证书选择；Reality 后添加 AnyTLS 也会正常配置证书。

脚本安装和更新地址指向本仓库，V2bX 核心程序仍从原上游下载。

回归测试（无需 root，不安装服务）：`python3 test_node_tls.py`。

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
