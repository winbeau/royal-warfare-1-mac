#!/bin/sh
# 共享工作区里多个子代理并行修改，禁止会丢弃未提交改动的 git 命令。
cmd=$(python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+(reset|restore|stash|clean)([[:space:]]|$)|git[[:space:]]+checkout[[:space:]].*--|git[[:space:]]+checkout[[:space:]]+-[fb]|git[[:space:]]+switch'; then
  echo "已拦截：共享工作区禁止 git reset/restore/stash/clean/checkout --/switch。需要对比基线请用 git show HEAD:<path> 或 git diff，只用 Edit/Write 手工恢复自己改过的文件。" >&2
  exit 2
fi
exit 0
