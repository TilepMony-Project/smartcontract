#!/usr/bin/env bash

if [ "$GITHUB_EVENT_NAME" == "push" ]; then
  COMMITS=$(echo "$GITHUB_EVENT_COMMITS" | jq -r '.[] | "- [" + (.message | split("\n")[0]) + "](" + .url + ")"')
else
  COMMITS="Manual Trigger / Not a push event"
fi

echo "COMMITS<<EOF" >>$GITHUB_ENV
echo "$COMMITS" >>$GITHUB_ENV
echo "EOF" >>$GITHUB_ENV
