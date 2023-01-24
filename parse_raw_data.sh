#!/bin/bash
jq -r '.issues[] | [.key,.fields.created] | @csv' jira_raw.json >> created.csv;
jq -r '.issues[] | {key, changelog: .changelog.histories[]} | select(.changelog.items[].field=="status") | [.key,.changelog.created,.changelog.author.key,.changelog.author.displayName,(.changelog.items[]| select(.field=="status")|.fromString,.toString)] | @csv' jira_raw.json >> status.csv;
