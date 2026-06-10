# Claude Code StatusLine

一键安装脚本，为 Claude Code 添加自定义 4 行状态栏。

## 效果

安装后在 Claude Code 终端底部持续显示：

```
html-anything | DeepSeek V4 Pro | thinking:on | effort:max | 16%
/Users/ouxingxing/Desktop/project
main | f0671e8 修复 BUG (#78) | 2未暂存 | 1未跟踪 | 3分支 | https://github.com/user/repo.git
* f0671e8 (HEAD -> main) 修复 BUG (#78)
* 2be9310 fix: validate header
```

| 行 | 内容 |
|---|---|
| 1 | 目录名 \| 模型名 \| thinking:on/off \| effort:级别 \| 上下文使用% |
| 2 | 当前工作目录绝对路径 |
| 3 | Git 分支 \| 最近 commit \| 未暂存文件数 \| 未跟踪文件数 \| 分支数 \| remote 地址 |
| 4 | `git log --graph --oneline --decorate -2` |

非 git 仓库时第 3 行显示「无git仓库」。

## 依赖

- [jq](https://jqlang.github.io/jq/) — JSON 解析
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

## 安装

```bash
git clone https://github.com/ostar999/ostar-claude-code-statusline.git
cd ostar-claude-code-statusline
bash install.sh
```

## 使用方式

安装完成后，下次与 Claude Code 交互时状态栏会自动出现在终端底部。如果未立即显示，发送一条消息即可触发刷新。

### 状态栏字段说明

| 字段 | 说明 |
|---|---|
| `目录名` | 当前工作目录的名称 |
| `模型名` | 当前使用的模型（如 DeepSeek V4 Pro、Opus、Sonnet） |
| `thinking:on/off` | 扩展思考是否启用 |
| `effort:级别` | 当前推理努力程度（low/medium/high/xhigh/max） |
| `上下文使用%` | 上下文窗口已使用的百分比 |
| `工作目录` | 当前工作目录的绝对路径 |
| `Git 分支` | 当前所在分支名 |
| `最近 commit` | 最新一次提交的 hash + message（截取前 60 字符） |
| `未暂存文件数` | 已修改但未 `git add` 的文件数量（`git diff --name-only`） |
| `未跟踪文件数` | 完全未被 git 跟踪的新文件数量（`git ls-files --others --exclude-standard`） |
| `分支数` | 本地分支总数 |
| `remote` | origin 远程仓库地址 |
| `Git graph` | 最近 2 条 commit 的图形化历史 |

### 验证安装

```bash
# 用示例 JSON 测试脚本是否正常
echo '{
  "cwd": "/tmp/test",
  "session_id": "test",
  "model": {"id": "test-model", "display_name": "Test"},
  "context_window": {"used_percentage": 0},
  "effort": {"level": "high"},
  "thinking": {"enabled": true}
}' | ~/.claude/statusline.sh
```

预期输出：
```
test | Test | thinking:on | effort:high | 0%
/tmp/test
无git仓库
```

## 卸载

```bash
# 删除 statusLine 配置（保留其他配置）
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/settings.json \
  && mv /tmp/settings.json ~/.claude/settings.json

# 删除状态栏脚本
rm ~/.claude/statusline.sh
```
