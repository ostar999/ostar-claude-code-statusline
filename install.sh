#!/bin/bash
# ============================================================
# Claude Code StatusLine 一键安装脚本
# 在任何 macOS/Linux 设备上运行即可完成相同配置
# 用法: bash install.sh
# ============================================================
set -e

echo "=========================================="
echo "  Claude Code StatusLine 一键安装"
echo "=========================================="

# --- 1. 检查依赖 ---
echo ""
echo "[1/4] 检查依赖..."

if ! command -v jq &>/dev/null; then
    echo "❌ 缺少 jq，请先安装: brew install jq"
    exit 1
fi
echo "  ✅ jq 已安装"

if ! command -v git &>/dev/null; then
    echo "⚠️  git 未安装，git 仓库信息将无法显示"
fi

# --- 2. 写入 statusline 脚本 ---
echo ""
echo "[2/4] 创建 ~/.claude/statusline.sh ..."

cat > ~/.claude/statusline.sh << 'SCRIPT_EOF'
#!/bin/bash
# Claude Code Statusline - 4-line display
# Reads session JSON from stdin

INPUT=$(cat)

# --- Parse JSON fields ---
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // .model.id // "?"')
THINKING=$(echo "$INPUT" | jq -r '.thinking.enabled // false')
EFFORT=$(echo "$INPUT" | jq -r '.effort.level // "N/A"')
CTX_USED=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# --- Line 1: DirName | Model | Thinking | Effort | Context% ---
DIR_NAME=$(basename "$CWD")
if [ "$THINKING" = "true" ]; then
    T_DISPLAY="thinking:on"
else
    T_DISPLAY="thinking:off"
fi

# Format context percentage (handle null)
if [ "$CTX_USED" = "null" ] || [ -z "$CTX_USED" ]; then
    CTX_FMT="0"
else
    CTX_FMT=$(printf "%.0f" "$CTX_USED" 2>/dev/null || echo "0")
fi
echo "${DIR_NAME} | ${MODEL} | ${T_DISPLAY} | effort:${EFFORT} | ${CTX_FMT}%"

# --- Line 2: Absolute CWD path ---
echo "${CWD}"

# --- Git info with simple cache (5s TTL) ---
CACHE_DIR="${TMPDIR:-/tmp}/.claude-sl"
mkdir -p "$CACHE_DIR"
CACHE_FILE="${CACHE_DIR}/$(echo "$SESSION_ID" | md5 2>/dev/null || echo "$SESSION_ID" | md5sum 2>/dev/null | cut -d' ' -f1 || echo 'default')"
NOW=$(date +%s)

GIT_RESULT=""
if [ -f "$CACHE_FILE" ]; then
    CACHE_AGE=$(head -1 "$CACHE_FILE")
    if [ -n "$CACHE_AGE" ] && [ $((NOW - CACHE_AGE)) -lt 5 ]; then
        GIT_RESULT=$(tail -n +3 "$CACHE_FILE")
    fi
fi

if [ -z "$GIT_RESULT" ]; then
    if git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
        BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "HEAD")
        COMMIT=$(git -C "$CWD" log -1 --format="%h %s" 2>/dev/null | cut -c1-60)
        UNSTAGED=$(git -C "$CWD" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
        UNTRACKED=$(git -C "$CWD" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        BCOUNT=$(git -C "$CWD" branch 2>/dev/null | wc -l | tr -d ' ')
        REMOTE=$(git -C "$CWD" remote get-url origin 2>/dev/null || echo "无remote")
        GRAPH=$(git -C "$CWD" log --graph --oneline --decorate -2 2>/dev/null)
        {
            echo "$NOW"
            echo "${CWD}"
            echo "${BRANCH} | ${COMMIT} | ${UNSTAGED}未暂存 | ${UNTRACKED}未跟踪 | ${BCOUNT}分支 | ${REMOTE}"
            echo "${GRAPH}"
        } > "$CACHE_FILE"
        GIT_RESULT=$(tail -n +3 "$CACHE_FILE")
    else
        {
            echo "$NOW"
            echo "${CWD}"
            echo "无git仓库"
        } > "$CACHE_FILE"
        GIT_RESULT="无git仓库"
    fi
fi

echo "$GIT_RESULT"
SCRIPT_EOF

chmod +x ~/.claude/statusline.sh
echo "  ✅ ~/.claude/statusline.sh 已创建"

# --- 3. 合并 statusLine 配置到 settings.json ---
echo ""
echo "[3/4] 配置 ~/.claude/settings.json ..."

SETTINGS_FILE="$HOME/.claude/settings.json"

# 如果 settings.json 不存在，创建一个空的
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "{}" > "$SETTINGS_FILE"
    echo "  📄 新建 settings.json"
fi

# 用 jq 合并 statusLine 配置（保留已有配置）
NEW_SETTINGS=$(jq '. + {
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}' "$SETTINGS_FILE")

echo "$NEW_SETTINGS" > "$SETTINGS_FILE"
echo "  ✅ statusLine 配置已写入 settings.json"

# --- 4. 验证 ---
echo ""
echo "[4/4] 验证安装..."

# 验证 JSON 合法性
if echo "$NEW_SETTINGS" | jq empty 2>/dev/null; then
    echo "  ✅ settings.json JSON 合法"
else
    echo "  ❌ settings.json JSON 不合法！请检查"
    exit 1
fi

# 验证脚本可执行
if [ -x ~/.claude/statusline.sh ]; then
    echo "  ✅ statusline.sh 可执行"
else
    echo "  ❌ statusline.sh 不可执行"
    exit 1
fi

# 验证脚本能解析示例 JSON
TEST_OUTPUT=$(echo '{
  "cwd": "/tmp/test",
  "session_id": "test",
  "model": {"id": "test-model", "display_name": "Test"},
  "context_window": {"used_percentage": 0},
  "effort": {"level": "high"},
  "thinking": {"enabled": true}
}' | ~/.claude/statusline.sh 2>&1 || true)

if echo "$TEST_OUTPUT" | grep -q "|"; then
    echo "  ✅ statusline.sh 测试通过"
else
    echo "  ⚠️  statusline.sh 测试输出异常（可能不影响使用）"
    echo "  $TEST_OUTPUT"
fi

echo ""
echo "=========================================="
echo "  ✅ 安装完成！"
echo "=========================================="
echo ""
echo "显示效果预览："
echo ""
echo "  test | Test | thinking:on | effort:high | 0%"
echo "  /tmp/test"
echo "  无git仓库"
echo ""
echo "配置的 4 行信息："
echo "  Line 1: 目录名 | 模型名 | thinking:on/off | effort:级别 | 上下文%"
echo "  Line 2: 当前工作目录绝对路径"
echo "  Line 3: Git分支 | 最近commit | 未暂存文件数 | 未跟踪文件数 | 分支数 | remote地址"
echo "  Line 4: Git graph（最近2条commit）"
echo ""
echo "下次与 Claude Code 交互时自动生效。"
echo "如果未立即出现，发送一条新消息即可。"
echo ""
