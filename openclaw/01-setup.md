CONTEXT: AI agent executing this file. Two required steps, two optional:
- STEP 1: Install OpenClaw and get the gateway running (no API key needed)
- STEP 2: Connect BytePlus Coding Plan using the user's API key
- STEP 3 (optional): Test the embeddings model
- STEP 4 (optional): Set up Telegram bot

PAUSE: Ask the user which OS they are on (macOS, Ubuntu, Windows 10, or Windows 11). Run only the block labelled with that OS for every subsequent block.
If openclaw is already installed, the installer upgrades it automatically.

CONSTRAINTS:
- Supported OS: macOS (Apple Silicon or Intel), Ubuntu 20.04+, Windows 10, Windows 11
- macOS/Ubuntu blocks: bash — run in Terminal
- Windows blocks: PowerShell 5.1+ — run in PowerShell (not cmd)
- non_interactive: true — all blocks run unattended unless marked PAUSE
- pause_policy: PAUSE blocks require the human to act; agent stops, surfaces the question to the user, waits for their answer, then continues
- api_key: stored in openclaw.json under models.providers.byteplus.apiKey — never in shell profiles
- timeoutSeconds: 600
- Default model: ark-code-latest (routes to model selected in BytePlus console)
- Base URL: https://ark.ap-southeast.bytepluses.com/api/coding/v3 (fixed)

---

## STEP 1 — INSTALL OPENCLAW

### macOS / Ubuntu

```bash
curl -fsSL https://openclaw.ai/install.sh | bash

eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
export PATH="$(npm prefix -g 2>/dev/null)/bin:$PATH"

command -v openclaw &>/dev/null && echo "PASS: openclaw $(openclaw --version 2>/dev/null)" || { echo "FAIL: install failed"; exit 1; }

command -v jq &>/dev/null \
  || { command -v brew &>/dev/null && brew install jq; } \
  || sudo apt-get install -y jq
echo "PASS: jq=$(jq --version)"

if openclaw gateway status 2>/dev/null | grep -qi "running"; then
  echo "SKIP: gateway already running"
elif [[ -f ~/.openclaw/openclaw.json ]] && jq -e '.models.providers.byteplus.apiKey' ~/.openclaw/openclaw.json &>/dev/null; then
  echo "INFO: existing config preserved — restarting gateway"
  openclaw gateway restart
else
  if lsof -i :18789 &>/dev/null 2>&1 || ss -tlnp 2>/dev/null | grep -q ':18789'; then
    echo "FAIL: port 18789 already in use — run: sudo lsof -i :18789"; exit 1
  fi
  openclaw onboard \
    --non-interactive --accept-risk \
    --auth-choice skip \
    --gateway-port 18789 --gateway-bind loopback \
    --install-daemon \
    --skip-channels --skip-skills --skip-search --skip-ui
fi

openclaw config set gateway.mode local \
  && echo "PASS: gateway.mode=local" \
  || { echo "FAIL: could not set gateway.mode — run: openclaw doctor"; exit 1; }

for i in {1..15}; do
  openclaw gateway status 2>/dev/null | grep -qi "running" && break
  sleep 1
done
openclaw gateway status 2>&1 | grep -qi "running" \
  && echo "PASS: gateway running — Step 1 complete" \
  || { echo "FAIL: gateway not running — run: openclaw doctor"; exit 1; }
```

---

### Windows

```powershell
irm https://openclaw.ai/install.ps1 | iex
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
if (Get-Command openclaw -EA SilentlyContinue) { Write-Host "PASS: openclaw $(openclaw --version 2>$null)" }
else { Write-Host "FAIL: install failed"; exit 1 }

if (-not (Get-Command jq -EA SilentlyContinue)) {
  winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
}
Write-Host "PASS: jq=$(jq --version)"

$configFile = "$env:USERPROFILE\.openclaw\openclaw.json"
$hasKey = $false
if (Test-Path $configFile) {
  jq -e '.models.providers.byteplus.apiKey' $configFile 2>$null | Out-Null
  $hasKey = ($LASTEXITCODE -eq 0)
}

$s = openclaw gateway status 2>&1
if ($s -match "running") {
  Write-Host "SKIP: gateway already running"
} elseif ($hasKey) {
  Write-Host "INFO: existing config preserved — restarting gateway"
  openclaw gateway restart
} else {
  $port = Get-NetTCPConnection -LocalPort 18789 -State Listen -EA SilentlyContinue
  if ($port) { Write-Host "FAIL: port 18789 in use (PID $($port.OwningProcess))"; exit 1 }
  openclaw onboard `
    --non-interactive --accept-risk `
    --auth-choice skip `
    --gateway-port 18789 --gateway-bind loopback `
    --install-daemon `
    --skip-channels --skip-skills --skip-search --skip-ui
}

openclaw config set gateway.mode local
if ($LASTEXITCODE -eq 0) { Write-Host "PASS: gateway.mode=local" }
else { Write-Host "FAIL: could not set gateway.mode — run: openclaw doctor"; exit 1 }

$ok = $false
for ($i = 0; $i -lt 15; $i++) {
  if ((openclaw gateway status 2>&1) -match "running") { $ok = $true; break }
  Start-Sleep 1
}
if ($ok) { Write-Host "PASS: gateway running — Step 1 complete" }
else { Write-Host "FAIL: gateway not running — run: openclaw doctor"; exit 1 }
```

---

## STEP 2 — CONNECT BYTEPLUS

Don't have a BytePlus Coding Plan account yet? First month is $9 USD — sign up with a discount:
https://www.byteplus.com/activity/codingplan?ac=MMAUCIS9NT1S&rc=HJA73DT3

Once signed up, choose your preferred model in the web console (`ark-code-latest` routes to it automatically):
https://console.byteplus.com/ark/region:ark+ap-southeast-1/openManagement

PAUSE: Ask the user: "What is your BytePlus Coding Plan API key? You can find it at: https://console.byteplus.com/ark/region:ark+ap-southeast-1/apikey — click Create API Key if you don't have one yet." Wait for their answer, substitute it in place of `your-api-key-here` in the block below, then run it.

### macOS / Ubuntu

```bash
BYTEPLUS_KEY="your-api-key-here"
BYTEPLUS_BASE="https://ark.ap-southeast.bytepluses.com/api/coding/v3"

[[ "$BYTEPLUS_KEY" == "your-api-key-here" || -z "$BYTEPLUS_KEY" ]] && { echo "FAIL: replace the placeholder with the actual key"; exit 1; }

jq -n --arg base "$BYTEPLUS_BASE" --arg key "$BYTEPLUS_KEY" '{
  models: { mode: "merge", providers: { byteplus: { baseUrl: $base, api: "openai-completions", apiKey: $key, models: [] } } },
  agents: { defaults: { model: { primary: "byteplus/ark-code-latest" }, timeoutSeconds: 600 } }
}' | openclaw config patch --stdin \
  && echo "PASS: config written" \
  || { echo "FAIL: config patch failed — run: openclaw config validate"; exit 1; }

openclaw gateway restart
for i in {1..15}; do
  openclaw gateway status 2>/dev/null | grep -qi "running" && break
  sleep 1
done
openclaw gateway status 2>&1 | grep -qi "running" \
  && echo "PASS: gateway running" \
  || { echo "FAIL: gateway not running — run: openclaw doctor"; exit 1; }

curl -s -X POST "$BYTEPLUS_BASE/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BYTEPLUS_KEY" \
  -d '{"model":"ark-code-latest","messages":[{"role":"user","content":"Say hi."}],"max_tokens":20}' \
  | jq -r '.choices[0].message.content // .error.message // .'

openclaw dashboard
```

### Windows

```powershell
$BYTEPLUS_KEY  = "your-api-key-here"
$BYTEPLUS_BASE = "https://ark.ap-southeast.bytepluses.com/api/coding/v3"

if ($BYTEPLUS_KEY -eq "your-api-key-here" -or -not $BYTEPLUS_KEY) { Write-Host "FAIL: replace the placeholder with the actual key"; exit 1 }

$patch = [ordered]@{
  models = [ordered]@{
    mode = "merge"
    providers = [ordered]@{
      byteplus = [ordered]@{
        baseUrl = $BYTEPLUS_BASE
        api     = "openai-completions"
        apiKey  = $BYTEPLUS_KEY
        models  = @()
      }
    }
  }
  agents = [ordered]@{
    defaults = [ordered]@{
      model          = [ordered]@{ primary = "byteplus/ark-code-latest" }
      timeoutSeconds = 600
    }
  }
} | ConvertTo-Json -Depth 10 -Compress
$patch | openclaw config patch --stdin
if ($LASTEXITCODE -eq 0) { Write-Host "PASS: config written" } else { Write-Host "FAIL: config patch failed — run: openclaw config validate"; exit 1 }

openclaw gateway restart
$ok = $false
for ($i = 0; $i -lt 15; $i++) {
  if ((openclaw gateway status 2>&1) -match "running") { $ok = $true; break }
  Start-Sleep 1
}
if ($ok) { Write-Host "PASS: gateway running" }
else { Write-Host "FAIL: gateway not running — run: openclaw doctor"; exit 1 }

try {
  $r = Invoke-RestMethod -Uri "$BYTEPLUS_BASE/chat/completions" -Method POST -ContentType "application/json" `
    -Headers @{Authorization="Bearer $BYTEPLUS_KEY"} `
    -Body '{"model":"ark-code-latest","messages":[{"role":"user","content":"Say hi."}],"max_tokens":20}'
  Write-Host "PASS: $($r.choices[0].message.content)"
} catch { Write-Host "FAIL: $($_.Exception.Message)" }

openclaw dashboard
```

---

## STEP 3 — EMBEDDINGS (OPTIONAL)

`doubao-embedding-vision` uses the same API key and base URL. No extra config needed.

### macOS / Ubuntu

```bash
BYTEPLUS_KEY=$(jq -r '.models.providers.byteplus.apiKey // empty' ~/.openclaw/openclaw.json)
BYTEPLUS_BASE="https://ark.ap-southeast.bytepluses.com/api/coding/v3"
[[ -z "$BYTEPLUS_KEY" ]] && { echo "FAIL: complete Step 2 first"; exit 1; }

curl -s -X POST "$BYTEPLUS_BASE/embeddings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BYTEPLUS_KEY" \
  -d '{"model":"doubao-embedding-vision","input":["Hello, OpenClaw!"]}' \
  | jq '{model: .model, dims: (.data[0].embedding | length), tokens: .usage.total_tokens}'
```

### Windows

```powershell
$configFile    = "$env:USERPROFILE\.openclaw\openclaw.json"
$BYTEPLUS_KEY  = jq -r '.models.providers.byteplus.apiKey // empty' $configFile
$BYTEPLUS_BASE = "https://ark.ap-southeast.bytepluses.com/api/coding/v3"
if (-not $BYTEPLUS_KEY) { Write-Host "FAIL: complete Step 2 first"; exit 1 }

try {
  $r = Invoke-RestMethod -Uri "$BYTEPLUS_BASE/embeddings" -Method POST -ContentType "application/json" `
    -Headers @{Authorization="Bearer $BYTEPLUS_KEY"} `
    -Body '{"model":"doubao-embedding-vision","input":["Hello, OpenClaw!"]}'
  Write-Host "PASS: model=$($r.model) dims=$($r.data[0].embedding.Count) tokens=$($r.usage.total_tokens)"
} catch { Write-Host "FAIL: $($_.Exception.Message)" }
```

---

## STEP 4 — TELEGRAM BOT (OPTIONAL)

To chat with OpenClaw and approve agent actions from your phone: read and execute `setup-telegram.md` (in the same directory as this file).

## TROUBLESHOOTING

Run `openclaw doctor` for most issues.
