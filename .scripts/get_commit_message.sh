#!/usr/bin/env bash

if [ "${{ github.event_name }}" == "push" ]; then
  COMMITS=$(echo '${{ toJSON(github.event.commits) }}' | jq -r '.[] | "- [" + (.message | split("\n")[0]) + "](" + .url + ")"')
else
  COMMITS="Manual Trigger / Not a push event"
fi
echo "COMMITS<<EOF" >> $GITHUB_ENV
echo "$COMMITS" >> $GITHUB_ENV
echo "EOF" >> $GITHUB_ENV
