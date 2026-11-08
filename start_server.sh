#!/usr/bin/env bash
# Starts the Arju Solars server with e-mail switched on.
#
# Your e-mail settings go in a file called  .env  in this folder, one per line, like this:
#     SMTP_USERNAME=youraddress@gmail.com
#     SMTP_PASSWORD=abcdefghijklmnop
#     MAIL_FROM="Arju Solars <youraddress@gmail.com>"
# (the Google App password has 16 letters and no spaces; no quotes are needed around it)
#
# Start the server with:   bash start_server.sh
# Keep .env private. Never upload it to GitHub or send it to anyone.

cd "$(dirname "$0")"

# read .env when it exists
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
else
  echo "NOTE: there is no .env file in this folder, so no e-mail login is set."
fi

# standard values, used only when .env does not set them
export SMTP_ADDRESS="${SMTP_ADDRESS:-smtp.gmail.com}"
export SMTP_PORT="${SMTP_PORT:-587}"
export PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-http://localhost:3000}"

# a check shown every time the server starts (the password itself is never printed)
echo "E-mail login : ${SMTP_USERNAME:-<not set>}"
echo "Sent as      : ${MAIL_FROM:-<not set>}"
echo "Password     : ${#SMTP_PASSWORD} letters"
if [ "${#SMTP_PASSWORD}" -ne 16 ]; then
  echo "WARNING: a Google App password has exactly 16 letters. The server sees ${#SMTP_PASSWORD}. Google will refuse this login."
fi

bin/rails server