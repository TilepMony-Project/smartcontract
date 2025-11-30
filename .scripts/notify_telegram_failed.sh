#!/usr/bin/env bash

TEXT=$(cat <<'EOF'
❌ *Smart Contract Test Failed!*

Repository: [${{ github.repository }}](${{ github.server_url }}/${{ github.repository }})
Branch: [${{ github.ref_name }}](${{ github.server_url }}/${{ github.repository }}/tree/${{ github.ref_name }})
By: [${{ github.actor }}](${{ github.server_url }}/${{ github.actor }})

*Commits:*
${{ env.COMMITS }}

🧩 [View Workflow Logs](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})
EOF
)
TEXT_URLENCODED=$(echo "$TEXT" | jq -s -R -r @uri)
curl -s -X POST "https://api.telegram.org/bot${{ secrets.TELEGRAM_BOT_TOKEN }}/sendMessage" \
  -d chat_id="${{ secrets.TELEGRAM_CHAT_ID }}" \
  -d message_thread_id="${{ secrets.TELEGRAM_TOPIC_ID }}" \
  -d text="$TEXT_URLENCODED" \
  -d parse_mode="Markdown" \
  -d disable_web_page_preview="true"
