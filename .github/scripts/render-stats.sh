#!/usr/bin/env bash
set -uo pipefail

USER="HazemMarrakchi"
API="https://api.github.com"
AUTH="Authorization: Bearer ${GH_TOKEN}"
JSON="Accept: application/vnd.github+json"
OUT="profile-summary-card-output"
YEAR_AGO=$(date -u -d "1 year ago" +%Y-%m-%d)

api_get() { curl -sS -H "$AUTH" -H "$JSON" "$@"; }
jget() { echo "$1" | jq -r "$2 // 0"; }

profile=$(api_get "$API/users/${USER}")
repos=$(api_get "$API/users/${USER}/repos?per_page=100&sort=updated")

public_repos=$(jget "$profile" '.public_repos')
followers=$(jget "$profile" '.followers')
following=$(jget "$profile" '.following')
stars=$(echo "$repos" | jq '[.[].stargazers_count] | add // 0')

commits_1y=$(api_get -G "$API/search/commits" --data-urlencode "q=author:${USER} committer-date:>${YEAR_AGO}" --data-urlencode "per_page=1" | jget '.total_count')
prs=$(api_get -G "$API/search/issues" --data-urlencode "q=author:${USER} type:pr" --data-urlencode "per_page=1" | jget '.total_count')
issues=$(api_get -G "$API/search/issues" --data-urlencode "q=author:${USER} type:issue" --data-urlencode "per_page=1" | jget '.total_count')
reviews=$(api_get -G "$API/search/issues" --data-urlencode "q=reviewed-by:${USER} type:pr" --data-urlencode "per_page=1" | jget '.total_count')

theme_colors() {
  if [ "$1" = "github_dark" ]; then
    BG="#0A0F1C"; BORDER="#1C2740"; TITLE="#22D3EE"; VALUE="#E2E8F0"; LABEL="#94A3B8"
  else
    BG="#FFFFFF"; BORDER="#D0D7DE"; TITLE="#0891B2"; VALUE="#24292F"; LABEL="#57606A"
  fi
}

card_head() {
  local theme="$1" title="$2"
  local uid=$(echo "${theme}_${title}" | tr -c 'a-zA-Z0-9' '_')
  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="430" height="170" viewBox="0 0 430 170" fill="none" role="img">
  <defs><linearGradient id="acc_$uid" x1="0" y1="0" x2="430" y2="0" gradientUnits="userSpaceOnUse"><stop stop-color="#22D3EE"/><stop offset="1" stop-color="#A78BFA"/></linearGradient></defs>
  <rect x="0.5" y="0.5" width="429" height="169" rx="12" fill="$BG" stroke="$BORDER"/>
  <rect x="14" y="14" width="402" height="4" rx="2" fill="url(#acc_$uid)"/>
  <text x="24" y="48" font-family="'Segoe UI',Helvetica,Arial,sans-serif" font-size="17" font-weight="700" letter-spacing="2" fill="$TITLE">$title</text>
EOF
}

card_item() {
  local x="$1" y="$2" value="$3" label="$4"
  cat <<EOF
  <text x="$x" y="$y" font-family="'Segoe UI',Helvetica,Arial,sans-serif" font-size="26" font-weight="700" fill="$VALUE">$value</text>
  <text x="$x" y="$((y+20))" font-family="'Segoe UI',Helvetica,Arial,sans-serif" font-size="12" fill="$LABEL">$label</text>
EOF
}

write_card() {
  local theme="$1" file="$2" title="$3"; shift 3
  local dir="$OUT/$theme"
  mkdir -p "$dir"
  theme_colors "$theme"
  {
    card_head "$theme" "$title"
    local i=0 xs=(24 230) ys=(92 148)
    while [ $# -gt 0 ]; do
      local v="$1" l="$2"; shift 2
      card_item "${xs[$((i % 2))]}" "${ys[$((i / 2))]}" "$v" "$l"
      i=$((i + 1))
    done
    echo '</svg>'
  } > "$dir/$file"
}

for theme in github_dark github; do
  write_card "$theme" "profile-details.svg" "PROFILE" \
    "$public_repos" "Public Repositories" \
    "$stars" "Stars Earned" \
    "$followers" "Followers" \
    "$following" "Following"

  write_card "$theme" "stats.svg" "ACTIVITY · LAST 12 MONTHS" \
    "${commits_1y:-0}" "Commits · 1 Year" \
    "${prs:-0}" "Pull Requests" \
    "${reviews:-0}" "Code Reviews" \
    "${issues:-0}" "Issues Opened"
done

echo "Cards rendered:"
find "$OUT" -name "*.svg" -exec ls -la {} \;
