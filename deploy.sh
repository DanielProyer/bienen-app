#!/usr/bin/env bash
# Deploy bienen_app to GitHub Pages (gh-pages branch).
#
# Warum dieses Script: Flutter-Web auf GitHub Pages cached aggressiv.
# index.html + flutter_bootstrap.js werden über ?v=<version> (siehe
# web/index.html) frisch geholt – ABER main.dart.js (der App-Code) wird
# vom Bootstrap OHNE Query geladen und bleibt bis zu 10 Min im Browser-
# Cache. Ergebnis: normaler Refresh zeigt die alte App.
#
# Fix: hier main.dart.js pro Version cache-busten (?v=<version>). Damit
# holt ein normaler Refresh (dank Versions-Check-Redirect in index.html)
# zuverlässig den neuen Code – jetzt und in Zukunft.
#
# Nutzung:  bash deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

VER=$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//; s/+.*//')
echo ">> Building v${VER} (flutter build web) ..."
flutter build web

BOOT=build/web/flutter_bootstrap.js
echo ">> Cache-busting entrypoint (main.dart.js?v=${VER}) ..."
sed -i "s|\"main\.dart\.js\"|\"main.dart.js?v=${VER}\"|g" "$BOOT"
CNT=$(grep -c "main.dart.js?v=${VER}" "$BOOT" || true)
echo "   patched references: ${CNT}"
if [ "${CNT}" -lt 1 ]; then
  echo "!! WARN: entrypoint patch did not apply – Bootstrap-Format geändert? Bitte prüfen."
fi

echo ">> Deploying to gh-pages ..."
WT=$(mktemp -d)
git fetch origin gh-pages
git worktree add "$WT" gh-pages >/dev/null
git -C "$WT" merge --ff-only origin/gh-pages >/dev/null 2>&1 || true
cp -r build/web/. "$WT"/
git -C "$WT" add -A
git -C "$WT" commit -m "Deploy v${VER}" >/dev/null 2>&1 || echo "   (nothing new to deploy)"
git -C "$WT" push origin gh-pages
git worktree remove "$WT"
git worktree prune

# Live-Flip verifizieren. Ein erfolgreicher gh-pages-Push heisst NICHT, dass die neue
# Version schon live ist: GitHub Pages baut/publiziert asynchron (oft <2 min, gelegentlich
# deutlich mehr) und die Fastly-CDN cached version.json bis zu 10 min. Wir pollen die
# Live-version.json (cache-bustend), bis sie kippt – sonst faellt "gepusht, aber Live zeigt
# Alt" erst dem Nutzer auf. version.json ist der Anker: sobald sie neu ist, holt der 60s-Poll
# in index.html den neuen Code automatisch (auch ohne manuellen Refresh).
ORIGIN_URL=$(git config --get remote.origin.url || echo "")
SLUG=$(echo "$ORIGIN_URL" | sed -E 's#.*github\.com[:/]([^/]+)/([^/.]+)(\.git)?/?$#\1/\2#')
OWNER_LC=$(echo "${SLUG%%/*}" | tr '[:upper:]' '[:lower:]')
REPO=${SLUG##*/}
PAGES_JSON="https://${OWNER_LC}.github.io/${REPO}/version.json"

echo ">> Warte auf Live-Flip von GitHub Pages (${OWNER_LC}.github.io/${REPO}) ..."
LIVE=""
for i in $(seq 1 30); do   # bis ~5 min (30 × 10s)
  LIVE=$(curl -fsS "${PAGES_JSON}?_=$(date +%s%N)" 2>/dev/null \
           | grep -o '"version":"[^"]*"' | head -1 | sed 's/.*:"//; s/"$//')
  if [ "$LIVE" = "$VER" ]; then
    echo ">> ✓ Live bestaetigt: v${VER} ist publiziert. Ein Refresh (oder der 60s-Poll) zeigt die neue Version."
    exit 0
  fi
  printf "   Live noch v%s (Versuch %s/30) ...\r" "${LIVE:-?}" "$i"
  sleep 10
done

echo ""
echo "!! Nach ~5 min zeigt Live noch v${LIVE:-?} statt v${VER}."
echo "   Der gh-pages-Push ist erfolgt (siehe oben) – GitHub Pages haengt beim Publizieren"
echo "   (Build-Queue/Incident). Die laufende App holt die neue Version per version.json-Poll"
echo "   automatisch nach, sobald Pages publiziert (max. ~1 min danach)."
echo "   Bei anhaltendem Lag: GitHub → Repo → Actions/Settings→Pages → Deployment-Status pruefen,"
echo "   oder einen leeren Commit auf gh-pages pushen (Re-Trigger)."
