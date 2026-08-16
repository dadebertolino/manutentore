#!/usr/bin/env bash
#
# Rigenera le icone di iOS e Android da design/icona.svg.
#
#     ./tool/genera_icone.sh
#
# I PNG nel repo sono prodotti da questo script: non modificarli a mano, si
# perderebbe la sorgente. Se cambia il disegno, cambia l'SVG e rilancia.
#
# Serve rsvg-convert (librsvg) e magick (ImageMagick):
#     brew install librsvg imagemagick
#
# Due dettagli che non sono capricci:
#   - le icone iOS non possono avere il canale alfa, App Store Connect rifiuta
#     il pacchetto senza spiegare granche';
#   - il primo piano dell'icona adattiva Android vive su una tela da 108 dp di
#     cui solo il 66% centrale e' garantito visibile: il resto lo mangia la
#     maschera del launcher, che cambia da telefono a telefono. La sagoma
#     occupa il 57,8% del lato, quindi ci sta.

set -euo pipefail

cd "$(dirname "$0")/.."

for strumento in rsvg-convert magick; do
  if ! command -v "$strumento" > /dev/null; then
    echo "manca $strumento — brew install librsvg imagemagick"
    exit 1
  fi
done

SORGENTE=design/icona.svg
PRIMO_PIANO=design/icona-primo-piano.svg
IOS=manutentore_app/ios/Runner/Assets.xcassets/AppIcon.appiconset
RES=manutentore_app/android/app/src/main/res

# --- iOS: le misure le detta Contents.json, non una lista scritta a mano ---
python3 - "$IOS" <<'PY' > /tmp/misure_icone_ios.txt
import json, sys, pathlib
contenuti = json.loads((pathlib.Path(sys.argv[1]) / 'Contents.json').read_text())
viste = set()
for i in contenuti['images']:
    nome = i.get('filename')
    if not nome or nome in viste:
        continue
    viste.add(nome)
    lato = float(i['size'].split('x')[0]) * float(i['scale'].rstrip('x'))
    print(round(lato), nome)
PY

while read -r lato nome; do
  rsvg-convert -w "$lato" -h "$lato" "$SORGENTE" -o /tmp/_icona.png
  # `-strip` non e' cosmesi: senza, ImageMagick infila la data di creazione nel
  # PNG e ogni rigenerazione sporca il diff con venti file "cambiati" che sono
  # identici a vedersi.
  magick /tmp/_icona.png -background '#171A1D' -alpha remove -alpha off \
    -strip "$IOS/$nome"
done < /tmp/misure_icone_ios.txt
echo "iOS   $(wc -l < /tmp/misure_icone_ios.txt | tr -d ' ') icone"

# --- Android: PNG classico piu' primo piano adattivo, per densita' ---
while IFS=' ' read -r densita classico adattivo; do
  [ -z "$densita" ] && continue
  rsvg-convert -w "$classico" -h "$classico" "$SORGENTE" \
    -o "$RES/mipmap-$densita/ic_launcher.png"
  rsvg-convert -w "$adattivo" -h "$adattivo" "$PRIMO_PIANO" \
    -o "$RES/mipmap-$densita/ic_launcher_foreground.png"
done <<'EOF'
mdpi 48 108
hdpi 72 162
xhdpi 96 216
xxhdpi 144 324
xxxhdpi 192 432
EOF
echo "Android  5 densita', classiche e adattive"

rm -f /tmp/_icona.png /tmp/misure_icone_ios.txt
echo "OK  icone rigenerate da $SORGENTE"
