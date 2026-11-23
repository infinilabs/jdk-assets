# jdk-assets

为 [INFINI Easysearch](https://github.com/infinilabs/easysearch) 及相关项目的 CI/CD 构建提供统一命名、固定直链与完整校验文件的构建资产镜像仓库（包含多品牌安全补丁版 JDK、Agent 压缩包与构建辅助脚本）。

所有同步发布的 JDK 均通过上游官方校验（MD5 / SHA256），默认启用安全基线检查以确保已修复 **Java4Shell (`CVE-2026-114938`)** 漏洞，并统一生成 `.sha512` 与汇总校验文件。

---

## 目录结构

```text
.
├── .github/workflows/
│   ├── cleanup.yml        # 按品牌与版本清理 Release / Tag / 资产
│   ├── sync-assets.yml    # 将 agents 与 scripts 目录同步到 Release
│   ├── sync-graalvm.yml   # 通过 Oracle GDS 同步 Oracle GraalVM 25 LTS
│   └── sync-jdk.yml       # 同步 Tencent Kona / Eclipse Temurin / Amazon Corretto
├── agents/                # 预打包 Agent 二进制及其 .sha512
├── scripts/               # 构建与下载辅助脚本 (get_release_url.sh)
└── README.md
```

---

## 资产与 Release 矩阵

### 1. JDK 品牌与版本矩阵

| 品牌 | Release Tag | 支持主版本 | 最低安全版本基线 | 支持平台 | 开源/分发协议 |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Tencent Kona** | `kona` | `17` / `21` / `25` | `17.0.21.1` / `21.0.13.1` / `25.0.5.1` | `linux-x64`, `linux-aarch64`, `macos-aarch64`, `macos-x64`, `windows-x64` | GPLv2 + CE |
| **Eclipse Temurin** | `temurin` | `17` / `21` / `25` | `17.0.21.1` / `21.0.13.1` / `25.0.5.1` | `linux-x64`, `linux-aarch64`, `macos-aarch64`, `macos-x64`, `windows-x64` | GPLv2 + CE |
| **Amazon Corretto** | `corretto` | `17` / `21` / `25` | `17.0.21.1` / `21.0.13.1` / `25.0.5.1` | `linux-x64`, `linux-aarch64`, `macos-aarch64`, `macos-x64`, `windows-x64` | GPLv2 + CE |
| **Oracle GraalVM** | `graalvm` | `25` | `25.0.5.1` | `linux-x64`, `linux-aarch64`, `macos-aarch64`, `windows-x64` | GFTC |

> **说明**：
> * Oracle GraalVM 25 从 `25.0.2` 起已移除 `macos-x64`，且官方不提供 `windows-aarch64`。
> * Oracle GraalVM 17 / 21 最新安全补丁已转为 OTN 商业许可，不纳入本公开仓库分发。

### 2. Agents 与 Scripts 资产

| 资产类型 | Release Tag | 包含文件 |
| :--- | :---: | :--- |
| **Agents** | `agents` | `agent-1.30.3-2407-linux-amd64.tar.gz`（含 `.sha512`）、`agent-1.30.3-2407-linux-arm64.tar.gz`（含 `.sha512`） |
| **Scripts** | `scripts` | `get_release_url.sh`（含 `.sha512`） |

---

## 命名与直链规范

所有 JDK 资产均按以下固定规则命名，后续小版本安全更新不改变下载 URL：

* **JDK 安装包**：`<brand>-jdk-<major_version>_<os>-<arch>_bin.<ext>`
* **单文件校验**：`<brand>-jdk-<major_version>_<os>-<arch>_bin.<ext>.sha512`
* **版本汇总校验**：`<brand>-jdk-<major_version>_SHA256SUMS.txt` / `<brand>-jdk-<major_version>_SHA512SUMS.txt`

常用直链示例：

```text
# JDK
https://github.com/infinilabs/jdk-assets/releases/download/graalvm/graalvm-jdk-25_linux-aarch64_bin.tar.gz
https://github.com/infinilabs/jdk-assets/releases/download/kona/kona-jdk-17_windows-x64_bin.zip
https://github.com/infinilabs/jdk-assets/releases/download/temurin/temurin-jdk-25_linux-aarch64_bin.tar.gz
https://github.com/infinilabs/jdk-assets/releases/download/corretto/corretto-jdk-25_macos-aarch64_bin.tar.gz

# Agents
https://github.com/infinilabs/jdk-assets/releases/download/agents/agent-1.30.3-2407-linux-amd64.tar.gz
https://github.com/infinilabs/jdk-assets/releases/download/agents/agent-1.30.3-2407-linux-arm64.tar.gz

# Scripts
https://github.com/infinilabs/jdk-assets/releases/download/scripts/get_release_url.sh
```

---

## 使用 `get_release_url` 获取 JDK 下载链接

[`scripts/get_release_url.sh`](scripts/get_release_url.sh) 支持 `source` 引入并导出 `get_release_url` 函数（在 Bash 中自动 `export -f get_release_url`），也支持直接作为命令行执行。

### 1. 在 Shell / 构建脚本中导出并调用

```bash
# 方式 A：从本地引入
source scripts/get_release_url.sh

# 方式 B：直接从 Release（或 raw）在线加载
source <(curl -fsSL https://github.com/infinilabs/jdk-assets/releases/download/scripts/get_release_url.sh)

# 语法: get_release_url [brand] [major_version] [os] [arch] [type]
# 省略 os / arch 时自动探测当前机器系统与架构
get_release_url kona 21
get_release_url graalvm 25 macos aarch64
get_release_url temurin 25 linux aarch64 sha512
get_release_url corretto 25 macos aarch64 sha512sums
```

导出后，在子 Shell 中也可以直接调用：

```bash
bash -c 'get_release_url kona 21 linux x64'
```

### 2. 下载并校验 JDK（示例）

```bash
source scripts/get_release_url.sh

URL="$(get_release_url kona 21 linux x64)"
SHA_URL="$(get_release_url kona 21 linux x64 sha512)"
FILE="$(basename "${URL}")"

curl -fsSL -O "${URL}"
curl -fsSL -O "${SHA_URL}"

# Linux 校验
sha512sum -c "${FILE}.sha512"
# macOS 校验: shasum -a 512 -c "${FILE}.sha512"
```

### 3. 在 GitHub Actions 中使用

```yaml
- name: Download & verify JDK
  run: |
    source <(curl -fsSL https://github.com/infinilabs/jdk-assets/releases/download/scripts/get_release_url.sh)
    url="$(get_release_url kona 21 linux x64)"
    sha_url="$(get_release_url kona 21 linux x64 sha512)"
    curl -fsSL -o jdk.tar.gz "${url}"
    curl -fsSL -o jdk.sha512 "${sha_url}"
    expected="$(awk '{print $1}' jdk.sha512)"
    echo "${expected}  jdk.tar.gz" | sha512sum -c -
```

---

## GitHub Actions 维护指南

| 工作流 | 文件 | 触发方式 | 作用 |
| :--- | :--- | :--- | :--- |
| **Sync JDK to Releases** | `.github/workflows/sync-jdk.yml` | 手动触发 | 同步 `tencent-kona`、`eclipse-temurin`、`amazon-corretto`（支持 `17` / `21` / `25`） |
| **Sync Oracle GraalVM 25 (via GDS)** | `.github/workflows/sync-graalvm.yml` | 手动触发 | 通过 Oracle GDS 拉取并打包最新 `Oracle GraalVM 25 LTS` |
| **Sync Agents & Scripts to Releases** | `.github/workflows/sync-assets.yml` | 手动触发 / Push 自动触发 | 分别由 `publish-agents` 与 `publish-scripts` 两个独立 Job 发布 `agents` 和 `scripts` |
| **Cleanup JDK Releases** | `.github/workflows/cleanup.yml` | 手动触发（需输入 `DELETE`） | 按品牌与版本清理指定 Release、Tag 或资产 |