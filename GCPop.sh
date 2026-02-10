#!/bin/bash

# =================== Colors & UI ===================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
RESET='\033[0m'
BOLD='\033[1m'

# Clear screen and show Banner
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${RED}${BOLD}    🚀 ALPHA${YELLOW}0x1 ${BLUE}HYBRID BEAST ${PURPLE}[LAB EDITION]${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# =================== 1. Setup & Auth ===================
if [[ -f .env ]]; then source ./.env; fi

if [[ -z "${TELEGRAM_TOKEN:-}" ]]; then
    echo -ne " ${YELLOW}➤${RESET} ${BOLD}Enter Bot Token:${RESET} "
    read -r TELEGRAM_TOKEN
fi

if [[ -z "${TELEGRAM_CHAT_IDS:-}" ]]; then
    echo -ne " ${YELLOW}➤${RESET} ${BOLD}Enter Chat ID:${RESET} "
    read -r TELEGRAM_CHAT_IDS
fi

# =================== 2. Config ===================
# Lab အတွင်းရှိနေတဲ့ Region ကို Auto ရှာဖွေခြင်း
DETECTED_REGION=$(gcloud container clusters list --format="value(location)" | head -n 1 | sed 's/-[a-z]$//')
REGION="${DETECTED_REGION:-us-central1}"
SERVER_NAME="Alpha0x1-$(date +%s | tail -c 4)"
GEN_UUID=$(cat /proc/sys/kernel/random/uuid)
SERVICE_NAME="alpha0x1"
IMAGE="a0x1/al0x1"

echo -e "\n${BLUE}┌──────────────── CONFIGURATION ────────────────┐${RESET}"
echo -e "${BLUE}│${RESET}  ${BOLD}Region  :${RESET} ${GREEN}${REGION}${RESET}"
echo -e "${BLUE}│${RESET}  ${BOLD}Service :${RESET} ${GREEN}${SERVICE_NAME}${RESET}"
echo -e "${BLUE}│${RESET}  ${BOLD}UUID    :${RESET} ${CYAN}${GEN_UUID}${RESET}"
echo -e "${BLUE}└────────────────────────────────────────────────┘${RESET}\n"

# =================== 3. Deploying ===================
echo -e "${YELLOW}🔄 Deploying to Cloud Run (High-Perf Mode)...${RESET}"

# Step A: Deployment
gcloud run deploy "$SERVICE_NAME" \
  --image="$IMAGE" \
  --platform=managed \
  --region="$REGION" \
  --memory="4Gi" \
  --cpu="4" \
  --timeout="3600" \
  --no-allow-unauthenticated \
  --use-http2 \
  --no-cpu-throttling \
  --execution-environment=gen2 \
  --concurrency=1000 \
  --session-affinity \
  --set-env-vars UUID="${GEN_UUID}",GOMAXPROCS="4",GOMEMLIMIT="3600MiB",TZ="Asia/Yangon" \
  --port="8080" \
  --min-instances=1 \
  --max-instances=2 \
  --quiet

# Step B: Public Access & Traffic
echo -e "${YELLOW}🔓 Unlocking Public Access & Optimizing Route...${RESET}"
gcloud run services add-iam-policy-binding "$SERVICE_NAME" --region="$REGION" --member="allUsers" --role="roles/run.invoker" --quiet >/dev/null 2>&1
gcloud run services update-traffic "$SERVICE_NAME" --to-latest --region="$REGION" --quiet >/dev/null 2>&1

# Get URL
URL=$(gcloud run services describe "$SERVICE_NAME" --platform managed --region "$REGION" --format 'value(status.url)')
DOMAIN=${URL#https://}

# =================== 4. Notification ===================
echo -e "${YELLOW}📤 Sending Keys to Telegram...${RESET}"

URI="vless://${GEN_UUID}@vpn.googleapis.com:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=Tg-@Alpha0x1&sni=${DOMAIN}#${SERVER_NAME}"

export TZ="Asia/Yangon"
START_LOCAL="$(date +'%d.%m.%Y %I:%M %p')"
# 6 နာရီ ပြောင်းလဲသတ်မှတ်ခြင်း
END_LOCAL="$(date -d '+6 hours' +'%d.%m.%Y %I:%M %p')"

MSG="<blockquote>🚀 ${SERVER_NAME} V2RAY SERVICE</blockquote>
<blockquote>⏰ 6-Hour Free Service</blockquote>
<blockquote>📡Mytel 4G လိုင်းဖြတ် ဘယ်နေရာမဆိုသုံးလို့ရပါတယ်</blockquote>
<pre><code>${URI}</code></pre>
<blockquote>✅ စတင်ချိန်: <code>${START_LOCAL}</code></blockquote>
<blockquote>⏳ပြီးဆုံးအချိန်: <code>${END_LOCAL}</code></blockquote>"

if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_IDS" ]]; then
    IFS=',' read -r -a CHAT_ID_ARR <<< "${TELEGRAM_CHAT_IDS}"
    for chat_id in "${CHAT_ID_ARR[@]}"; do
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
            -d "chat_id=${chat_id}" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=${MSG}" > /dev/null
    done
    echo -e "${GREEN}✅ Telegram Notifications Sent Successfully!${RESET}"
else
    echo -e "${RED}❌ Telegram config missing. Skip notification.${RESET}"
fi

echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}             🎉 DEPLOYMENT FINISHED!${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
