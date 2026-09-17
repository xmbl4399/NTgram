#!/usr/bin/env bash
# 用 DeepSeek 官方 API 跑测试台（key 从 Z 盘凭据文件现读，不落盘、不入库）
#
# 用法：
#   bash tools/run_deepseek.sh tools/prompt_compare.py --only "v23,v29" --n 5 --msg "你还好吗？"
#   bash tools/run_deepseek.sh tools/llm_rp_test.py --prompt docs/system_prompt_v23.md --msg "你还好吗？"
#
# 可用环境变量覆盖：
#   NTGRAM_TEST_MODEL=deepseek-reasoner   换成思考模型
#   NTGRAM_TEST_MERGE_SYSTEM=1            合并前导 system（默认 0，保持 App 原生拼装）
set -u

CRED="${NTGRAM_CRED_FILE:-/z/备份误删.txt}"
KEY=$(grep -aA1 -E "^chat\r?$" "$CRED" 2>/dev/null | grep -aoE "sk-[A-Za-z0-9]{20,}" | head -1)
if [ -z "$KEY" ]; then
  echo "[run_deepseek] 未能从 $CRED 取到 DeepSeek key（检查 'chat' 标签下那行）" >&2
  exit 1
fi

export NTGRAM_TEST_API="https://api.deepseek.com/chat/completions"
export NTGRAM_TEST_KEY="$KEY"
export NTGRAM_TEST_MODEL="${NTGRAM_TEST_MODEL:-deepseek-chat}"
export NTGRAM_TEST_MERGE_SYSTEM="${NTGRAM_TEST_MERGE_SYSTEM:-0}"
export NTGRAM_TEST_NO_THINK=0
export NTGRAM_TEST_ALLOW_SEED=0

echo "[run_deepseek] model=$NTGRAM_TEST_MODEL merge_system=$NTGRAM_TEST_MERGE_SYSTEM key=${KEY:0:6}…(len ${#KEY})"

PY="C:/Users/ASUS/.workbuddy/binaries/python/versions/3.13.12/python.exe"
exec "$PY" "$@"
