CONTEXT: AI agent executing this file. Configure OpenClaw to accept messages via a Telegram bot.
Prereq: OpenClaw installed and gateway running (README.md Step 1 complete).
Run only the block matching the user's OS.

CONSTRAINTS:
- non_interactive: true — run unattended unless marked PAUSE
- pause_policy: PAUSE blocks require the human to act; agent stops, surfaces the question, waits for their answer, then continues

---

## STEP 1 — CREATE TELEGRAM BOT

PAUSE: The bot must be created manually in Telegram. Ask the user to do the following, then continue:

1. Open Telegram → search **@BotFather** → send `/newbot`
2. Follow the prompts, copy the bot token (format: `123456789:ABCdef...`)
3. To receive all group messages (not just `/commands`): send `/setprivacy` → select bot → **Disable**

---

## STEP 2 — VALIDATE TOKEN + WRITE CONFIG

PAUSE: Ask the user for:
1. **BOT_TOKEN** — token from @BotFather
2. **DM_POLICY** — `pairing` (new users need approval) or `open` (anyone can DM)
3. **GROUP_POLICY** — `open` (all group messages), `allowlist` (specific user IDs only), or `disabled`

Substitute their answers below and run the block for their OS.

### macOS / Ubuntu

```bash
BOT_TOKEN="123456789:ABCdef..."
DM_POLICY="pairing"
GROUP_POLICY="open"

[[ "$BOT_TOKEN" == "123456789:ABCdef..."* || -z "$BOT_TOKEN" ]] && { echo "FAIL: replace BOT_TOKEN"; exit 1; }

RESPONSE=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe")
[[ -z "$RESPONSE" ]] && { echo "FAIL: could not reach Telegram API"; exit 1; }
echo "$RESPONSE" | jq -e '.ok == true' &>/dev/null \
  || { echo "FAIL: $(echo "$RESPONSE" | jq -r '.description // "invalid token"')"; exit 1; }
echo "PASS: bot @$(echo "$RESPONSE" | jq -r '.result.username') (ID: $(echo "$RESPONSE" | jq -r '.result.id'))"

TG_PATCH=$(jq -n --arg token "$BOT_TOKEN" --arg dmp "$DM_POLICY" --arg grp "$GROUP_POLICY" \
  '{channels:{telegram:{enabled:true,botToken:$token,dmPolicy:$dmp,groupPolicy:$grp,groups:{"*":{requireMention:true}}}}}')
[[ "$DM_POLICY" == "open" ]] && TG_PATCH=$(echo "$TG_PATCH" | jq '.channels.telegram.allowFrom=["*"]')

echo "$TG_PATCH" > /tmp/tg.json
jq -s '.[0]*.[1]' ~/.openclaw/openclaw.json /tmp/tg.json > /tmp/tg-m.json \
  && mv /tmp/tg-m.json ~/.openclaw/openclaw.json && echo "PASS: config written" \
  || { echo "FAIL: config write failed"; exit 1; }
rm -f /tmp/tg.json
```

### Windows

```powershell
$BOT_TOKEN    = "123456789:ABCdef..."
$DM_POLICY    = "pairing"
$GROUP_POLICY = "open"

if ($BOT_TOKEN -like "123456789:ABCdef*" -or -not $BOT_TOKEN) { Write-Host "FAIL: replace BOT_TOKEN"; exit 1 }

try {
  $r = Invoke-RestMethod "https://api.telegram.org/bot${BOT_TOKEN}/getMe"
  Write-Host "PASS: bot @$($r.result.username) (ID: $($r.result.id))"
} catch { Write-Host "FAIL: $($_.Exception.Message)"; exit 1 }

$cfg = "$env:USERPROFILE\.openclaw\openclaw.json"
if (-not (Test-Path $cfg)) { New-Item -Force -Path (Split-Path $cfg) -ItemType Directory | Out-Null; '{}' | Set-Content -Encoding UTF8 $cfg }

$patch = jq -n --arg t $BOT_TOKEN --arg d $DM_POLICY --arg g $GROUP_POLICY `
  '{channels:{telegram:{enabled:true,botToken:$t,dmPolicy:$d,groupPolicy:$g,groups:{"*":{requireMention:true}}}}}'
if ($DM_POLICY -eq "open") { $patch = $patch | jq '.channels.telegram.allowFrom=["*"]' }
$patch | Set-Content -Encoding UTF8 "$env:TEMP\tg.json"
jq -s '.[0]*.[1]' $cfg "$env:TEMP\tg.json" | Set-Content -Encoding UTF8 "$env:TEMP\tg-m.json"
if ($LASTEXITCODE -eq 0) { Move-Item -Force "$env:TEMP\tg-m.json" $cfg; Write-Host "PASS: config written" } else { exit 1 }
Remove-Item -EA SilentlyContinue "$env:TEMP\tg.json"
```

---

## STEP 3 — RESTART GATEWAY

### macOS / Ubuntu
```bash
openclaw gateway restart
for i in {1..15}; do
  openclaw gateway status 2>/dev/null | grep -qi "running" && break
  sleep 1
done
openclaw gateway status 2>&1 | grep -qi "running" \
  && echo "PASS: gateway running" \
  || { echo "FAIL: gateway not running — run: openclaw doctor"; exit 1; }
```

### Windows
```powershell
openclaw gateway restart
$ok = $false
for ($i = 0; $i -lt 15; $i++) {
  if ((openclaw gateway status 2>&1) -match "running") { $ok = $true; break }
  Start-Sleep 1
}
if ($ok) { Write-Host "PASS: gateway running" } else { Write-Host "FAIL: not running"; exit 1 }
```

---

## STEP 4 — PAIR AND TEST

PAUSE: Ask the user to open Telegram, find **@YourBotUsername**, and tap **Start**. If `dmPolicy` is `pairing`, the bot replies with a pairing code. Then run:

```bash
openclaw pairing list telegram
openclaw pairing approve telegram <code>
```

Then send a test message to the bot. It should respond via OpenClaw.

---

## OPTIONAL — FIND YOUR TELEGRAM USER ID

Required for `groupPolicy: allowlist` or restricting `allowFrom`. Numeric IDs only — @usernames are ignored.

Send any message to your bot in Telegram, then check OpenClaw logs:

```bash
# macOS / Ubuntu
openclaw logs --follow 2>&1 | grep -o '"from":{"id":[0-9]*' | head -5
```

```powershell
# Windows
openclaw logs --follow 2>&1 | Select-String -Pattern '"from":\{"id":\d+'
```

The number after `"id":` is your Telegram user ID. Add it to the allowlist:

```bash
# macOS / Ubuntu
jq '.channels.telegram.allowFrom=["YOUR_NUMERIC_ID"]' ~/.openclaw/openclaw.json > /tmp/oc-tmp.json \
  && mv /tmp/oc-tmp.json ~/.openclaw/openclaw.json && openclaw gateway restart
```

```powershell
# Windows
jq '.channels.telegram.allowFrom=["YOUR_NUMERIC_ID"]' "$env:USERPROFILE\.openclaw\openclaw.json" | `
  Set-Content -Encoding UTF8 "$env:TEMP\oc-tmp.json"
Move-Item -Force "$env:TEMP\oc-tmp.json" "$env:USERPROFILE\.openclaw\openclaw.json"
openclaw gateway restart
```

---

## OPTIONAL — EXEC APPROVALS

Sends approval requests to Telegram before agent actions. Users approve/deny via inline buttons.

```bash
# macOS / Ubuntu
jq '.channels.telegram.execApprovals={"enabled":true,"timeoutSeconds":60}' \
  ~/.openclaw/openclaw.json > /tmp/oc-tmp.json \
  && mv /tmp/oc-tmp.json ~/.openclaw/openclaw.json && openclaw gateway restart
```

```powershell
# Windows
jq '.channels.telegram.execApprovals={"enabled":true,"timeoutSeconds":60}' `
  "$env:USERPROFILE\.openclaw\openclaw.json" | Set-Content -Encoding UTF8 "$env:TEMP\oc-tmp.json"
Move-Item -Force "$env:TEMP\oc-tmp.json" "$env:USERPROFILE\.openclaw\openclaw.json"
openclaw gateway restart
```

---

## TROUBLESHOOTING

| symptom | fix |
|---------|-----|
| Bot does not respond | Send `/start` to the bot in Telegram first |
| Pairing code never arrives | Send `/start` to the bot first |
| Pairing code expired | Send `/start` again (codes last 1 hour) |
| "You are not authorized" in DMs | Add `"allowFrom": ["*"]` to telegram config |
| "You are not authorized" (specific user) | Add numeric user ID to `allowFrom` (not @username) |
| Group messages not arriving | Set `"groupPolicy": "open"` — absence silently drops all group messages |
| Group messages not arriving (not mentioned) | `/setprivacy` → your bot → Disable; restart gateway |
| Approval buttons not appearing | Add `"execApprovals": {"enabled": true}` to telegram config |

```bash
openclaw doctor
```

---

## UNINSTALL

### macOS / Ubuntu
```bash
jq 'del(.channels.telegram)' ~/.openclaw/openclaw.json > /tmp/no-tg.json \
  && mv /tmp/no-tg.json ~/.openclaw/openclaw.json && openclaw gateway restart
```

### Windows
```powershell
jq 'del(.channels.telegram)' "$env:USERPROFILE\.openclaw\openclaw.json" | Set-Content -Encoding UTF8 "$env:TEMP\no-tg.json"
Move-Item -Force "$env:TEMP\no-tg.json" "$env:USERPROFILE\.openclaw\openclaw.json"
openclaw gateway restart
```
