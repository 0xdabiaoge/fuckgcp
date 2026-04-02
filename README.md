# CDN 屏蔽管理工具

> GCP（Google Cloud Platform）免费服务器 CDN 流量屏蔽方案

GCP 免费套餐的出站流量有限，CDN 回源请求（Cloudflare、Fastly、Akamai 等）可能消耗大量配额产生额外费用。本工具通过 `iptables` + `ipset` 屏蔽 CDN IP 段的入站/出站流量，保护免费配额。

## ✨ 功能特性

- **一键屏蔽** — 内嵌 467 条 IPv4 + 9 条 IPv6 规则，无需外部下载
- **临时/永久模式** — 临时模式重启失效，永久模式通过 systemd 开机自启
- **流量监控** — 主菜单实时显示出站流量进度条（200GB 上限），颜色分级预警
- **月度自动重置** — cron 定时任务每月 1 号自动归档并重置流量统计
- **历史记录** — 保留最近 3 个月的流量数据
- **APT 换源** — 屏蔽后 `deb.debian.org`（走 Fastly CDN）不可用，内置清华源/美国直连切换
- **屏蔽测试** — 一键验证 Cloudflare/Fastly/Akamai 是否被成功屏蔽
- **完全卸载** — 一键清除所有规则、服务、cron、数据，并删除脚本自身

## 📋 覆盖的 CDN 提供商

| 提供商 | IPv4 网段数 | IPv6 网段数 | 数据来源 |
|--------|------------|------------|---------|
| Cloudflare | 15 | 7 | [官方](https://www.cloudflare.com/ips/) |
| Fastly | 19 | 2 | [官方 API](https://api.fastly.com/public-ip-list) |
| Akamai (含 Linode) | 433 | — | 第三方整理 |

## 🚀 快速开始

```
(curl -LfsS https://raw.githubusercontent.com/0xdabiaoge/fuckgcp/main/cdn_block.sh -o /usr/local/bin/fuckgcp || wget -q https://raw.githubusercontent.com/0xdabiaoge/fuckgcp/main/cdn_block.sh -O /usr/local/bin/fuckgcp) && chmod +x /usr/local/bin/fuckgcp && fuckgcp
```

**快捷命令：fuckgcp**

## 📖 菜单说明

```
  ╔══════════════════════════════════════╗
  ║       CDN 屏蔽管理工具 v3.0          ║
  ║   GCP 免费服务器 CDN 流量屏蔽方案    ║
  ╚══════════════════════════════════════╝

  当前状态: ● 屏蔽已启用
  开机自启: ● 已设置

  📊 本月流量: [████████░░░░░░░░░░░░░░░░░░░░░░] 42.50 GB / 200 GB (21.3%)

  ── 屏蔽控制 ──
  1) 临时启用 CDN 屏蔽   (重启后失效)
  2) 临时停用 CDN 屏蔽   (重启后恢复)
  3) 永久启用 CDN 屏蔽   (开机自动生效)
  4) 永久停用 CDN 屏蔽   (移除开机自启)

  ── 信息查看 ──
  5) 查看屏蔽状态
  6) 查看屏蔽 IP 列表

  ── IP 管理 ──
  7) 添加自定义 IP 段
  8) 删除指定 IP 段

  ── 流量监控 ──
  11) 流量记录

  ── 诊断工具 ──
  12) 测试屏蔽效果

  ── 系统设置 ──
  9) APT 换源管理
  10) 完全卸载

  0) 退出
```

## ⚙️ 非交互模式

供 systemd 和 cron 内部调用，一般无需手动使用：

```bash
sudo ./cdn_block.sh --apply           # 加载屏蔽规则
sudo ./cdn_block.sh --remove          # 卸载屏蔽规则
./cdn_block.sh --update-traffic       # 更新流量统计
./cdn_block.sh --reset-traffic        # 重置当月流量
```

## 📦 依赖

- `ipset` — IP 集合管理
- `iptables` — 防火墙规则
- `cron` — 定时任务（流量监控）
- `curl` — HTTP 测试（可选）

安装依赖：
```bash
sudo apt install -y ipset iptables cron
```

## 📁 文件路径

| 路径 | 说明 |
|------|------|
| `/etc/systemd/system/cdn-block.service` | systemd 服务文件（永久模式） |
| `/var/lib/cdn-block/traffic_state` | 当前月流量状态 |
| `/var/lib/cdn-block/traffic_history` | 历史流量记录 |
| `/etc/apt/sources.list.bak.cdn-block` | apt 源备份 |

## ⚠️ 注意事项

1. **APT 换源**：启用屏蔽后，`deb.debian.org` 走 Fastly CDN 会被屏蔽，导致 `apt update` 失败。请通过菜单 9 切换到清华源或美国直连镜像。
2. **Akamai/Linode IP**：列表中包含 Linode（现属 Akamai）的 IP 段。如果服务器需要与 Linode 实例通信，请通过菜单 8 删除相关 IP 段。
3. **流量统计**：基于 `/proc/net/dev` 出站字节增量计算，重启后计数器归零会自动处理。每 5 分钟通过 cron 更新一次。
4. **IPv6**：已内嵌 Cloudflare 和 Fastly 的 IPv6 段。如果服务器无 IPv6，`ip6tables` 规则会自动跳过。

## 📄 许可

自由使用，无限制。
