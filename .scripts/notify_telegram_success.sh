#!/usr/bin/env bash

TEXT=$(cat <<EOF
✅ *Smart Contract Test Passed!*

Repository: [${GITHUB_REPOSITORY}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY})
Branch: [${GITHUB_REF_NAME}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/tree/${GITHUB_REF_NAME})
By: [${GITHUB_ACTOR}](${GITHUB_SERVER_URL}/${GITHUB_ACTOR})

*Commits:*
${COMMITS}

🧩 [View Workflow Logs](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})
EOF
)
TEXT_URLENCODED=$(echo "$TEXT" | jq -s -R -r @uri)

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d message_thread_id="${TELEGRAM_TOPIC_ID}" \
  -d text="$TEXT_URLENCODED" \
  -d parse_mode="Markdown" \
  -d disable_web_page_preview="trueo
