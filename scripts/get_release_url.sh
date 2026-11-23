#!/usr/bin/env bash
# 用法:
#   1) 作为库引入并导出函数:
#      source scripts/get_release_url.sh
#      get_release_url kona 21 linux x64
#      get_release_url graalvm 25 macos aarch64 sha512
#
#   2) 直接执行:
#      ./scripts/get_release_url.sh [brand] [major_version] [os] [arch] [type]
#
# 参数说明:
#   brand         : kona (默认) | temurin | corretto | graalvm
#                   (兼容传入 tencent-kona / eclipse-temurin / amazon-corretto / oracle-graalvm)
#   major_version : 17 | 21 (默认) | 25
#   os            : linux | macos | windows (省略时自动探测当前系统，兼容 darwin/mac/win)
#   arch          : x64 | aarch64 (省略时自动探测当前架构，兼容 x86_64/amd64/arm64)
#   type          : archive (默认) | sha512 | sha256sums | sha512sums
#
# 可选环境变量:
#   JDK_ASSETS_REPO : 默认 infinilabs/jdk-assets
#   GITHUB_MIRROR   : 可选加速前缀，例如 https://gh-proxy.example.com/

get_release_url() {
  local brand="${1:-kona}"
  local major="${2:-21}"
  local os="${3:-}"
  local arch="${4:-}"
  local asset_type="${5:-archive}"
  local repo="${JDK_ASSETS_REPO:-infinilabs/jdk-assets}"
  local mirror="${GITHUB_MIRROR:-}"

  # 1. 归一化品牌名 (即 Release Tag)
  case "${brand}" in
    kona|tencent-kona|tencent)       brand="kona" ;;
    temurin|eclipse-temurin|adoptium) brand="temurin" ;;
    corretto|amazon-corretto|aws)    brand="corretto" ;;
    graalvm|oracle-graalvm|oracle)   brand="graalvm" ;;
    *)
      echo "ERROR: Unsupported brand '${brand}' (expected: kona|temurin|corretto|graalvm)" >&2
      return 1
      ;;
  esac

  # 2. 校验主版本
  case "${major}" in
    17|21|25) ;;
    *)
      echo "ERROR: Unsupported major version '${major}' (expected: 17|21|25)" >&2
      return 1
      ;;
  esac

  if [ "${brand}" = "graalvm" ] && [ "${major}" != "25" ]; then
    echo "ERROR: Release tag 'graalvm' only provides JDK 25 (Oracle GraalVM 25 LTS)." >&2
    return 1
  fi

  # 3. 探测并归一化 OS
  if [ -z "${os}" ]; then
    case "$(uname -s 2>/dev/null || echo unknown)" in
      Linux*)                    os="linux" ;;
      Darwin*)                   os="macos" ;;
      MINGW*|MSYS*|CYGWIN*|Windows_NT) os="windows" ;;
      *)
        echo "ERROR: Cannot auto-detect OS, please pass os explicitly (linux|macos|windows)." >&2
        return 1
        ;;
    esac
  fi

  case "${os}" in
    linux|Linux)                 os="linux" ;;
    macos|mac|darwin|Darwin)     os="macos" ;;
    windows|win|Windows*)        os="windows" ;;
    *)
      echo "ERROR: Unsupported OS '${os}' (expected: linux|macos|windows)" >&2
      return 1
      ;;
  esac

  # 4. 探测并归一化架构
  if [ -z "${arch}" ]; then
    case "$(uname -m 2>/dev/null || echo unknown)" in
      x86_64|amd64|x64) arch="x64" ;;
      aarch64|arm64)    arch="aarch64" ;;
      *)
        echo "ERROR: Cannot auto-detect arch, please pass arch explicitly (x64|aarch64)." >&2
        return 1
        ;;
    esac
  fi

  case "${arch}" in
    x64|x86_64|amd64) arch="x64" ;;
    aarch64|arm64)    arch="aarch64" ;;
    *)
      echo "ERROR: Unsupported arch '${arch}' (expected: x64|aarch64)" >&2
      return 1
      ;;
  esac

  # 5. 检查平台组合合法性
  if [ "${os}" = "windows" ] && [ "${arch}" != "x64" ]; then
    echo "ERROR: Windows builds only support x64." >&2
    return 1
  fi
  if [ "${brand}" = "graalvm" ] && [ "${os}" = "macos" ] && [ "${arch}" = "x64" ]; then
    echo "ERROR: Oracle GraalVM 25 does not provide macos-x64 builds." >&2
    return 1
  fi

  # 6. 拼接目标链接
  local ext="tar.gz"
  [ "${os}" = "windows" ] && ext="zip"

  local base_url="https://github.com/${repo}/releases/download/${brand}"
  local filename="${brand}-jdk-${major}_${os}-${arch}_bin.${ext}"
  local final_url=""

  case "${asset_type}" in
    archive|bin|"") final_url="${base_url}/${filename}" ;;
    sha512)         final_url="${base_url}/${filename}.sha512" ;;
    sha256sums)     final_url="${base_url}/${brand}-jdk-${major}_SHA256SUMS.txt" ;;
    sha512sums)     final_url="${base_url}/${brand}-jdk-${major}_SHA512SUMS.txt" ;;
    *)
      echo "ERROR: Unsupported type '${asset_type}' (expected: archive|sha512|sha256sums|sha512sums)" >&2
      return 1
      ;;
  esac

  if [ -n "${mirror}" ]; then
    mirror="${mirror%/}/"
  fi
  printf '%s%s\n' "${mirror}" "${final_url}"
}

# 在 Bash 中导出函数，便于子 Shell 直接调用
if [ -n "${BASH_VERSION:-}" ]; then
  export -f get_release_url
fi

# 如果不是通过 source 引入，而是直接执行脚本，则透传参数调用
_is_sourced=false
if [ -n "${BASH_VERSION:-}" ]; then
  [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ] && _is_sourced=true
elif [ -n "${ZSH_VERSION:-}" ]; then
  case "${ZSH_EVAL_CONTEXT:-}" in *:file*) _is_sourced=true ;; esac
fi

if [ "${_is_sourced}" != "true" ]; then
  get_release_url "$@"
fi
unset _is_sourced