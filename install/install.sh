#!/bin/sh
# Instalador do "CarPlay map -> cluster" para iDrive7 MGU.
# Roda NO carro, como root. Monta o pacote mgu-deploy do produtor.
# cluster_render_client.js (GPL, robertn) NAO e redistribuido: em runtime o
# produtor carrega /var/opt/cluster-render/current/cluster_render_client.js.
#
# Uso (no carro):
#   ./install/install.sh [/caminho/opcional/para/cluster_render_client.js]
set -e

HERE=$(cd "$(dirname "$0")/.." && pwd)
PRODUCER="$HERE/native/carplay-map/carplay-map-cluster.js"
[ -f "$PRODUCER" ] || PRODUCER="$HERE/producer/carplay-map-cluster.js"
PKG="$HERE/packages/carplay-map-tool"
APP_TGZ="$HERE/app/carplay_map_toggle/carplay_map_toggle.src.tgz"
MD=/var/opt/mgu-deploy/mgu-deploy.sh
CLIENT="${1:-$HERE/producer/cluster_render_client.js}"

echo "== CarPlay map -> cluster: instalador =="
[ "$(id -u)" = 0 ] || { echo "ERRO: rode como root."; exit 1; }
[ -x "$MD" ] || { echo "ERRO: mgu-deploy nao encontrado ($MD). Instale o MGU Store primeiro."; exit 1; }
[ -f "$PRODUCER" ] || { echo "ERRO: produtor nao encontrado em $PRODUCER"; exit 1; }

echo "-- checando pre-requisitos --"
# Separate product from robertn's waze-on-cluster; both fight the cluster map slot.
if [ -e /var/opt/waze-on-cluster/current ] || "$MD" status 2>/dev/null | grep -qi 'waze-on-cluster'; then
  echo "ERRO: waze-on-cluster esta instalado."
  echo "      CarPlay map -> cluster e outro app (espelho). Desinstale waze-on-cluster no Store antes."
  exit 1
fi
if ! "$MD" status 2>/dev/null | grep -qi 'cluster-render'; then
  echo "ERRO: cluster-render nao detectado. Instale-o pelo MGU Store antes (ele faz o trabalho pesado)."
  exit 1
fi
"$MD" status 2>/dev/null | grep -qi 'app-privacy' || \
  echo "AVISO: app-privacy nao detectado — necessario SO para o app de liga/desliga (MGU Store)."

if [ -f /var/opt/cluster-render/current/cluster_render_client.js ]; then
  echo "OK: cluster_render_client.js no cluster-render instalado."
elif [ -f "$CLIENT" ]; then
  echo "OK: usando client local: $CLIENT"
else
  echo "AVISO: sem cluster_render_client.js visivel agora — o servico falhara ate o cluster-render estar completo."
  CLIENT=""
fi
if [ ! -f "$CLIENT" ]; then
  CLIENT=""
fi

echo "-- montando o pacote do produtor (com shas corretos) --"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/files" "$TMP/units"
cp "$PRODUCER" "$TMP/files/carplay-map-cluster.js"
CHECK="$HERE/native/carplay-map/check-conflict.js"
[ -f "$CHECK" ] && cp "$CHECK" "$TMP/files/check-conflict.js"
UNIT_SRC="$HERE/native/carplay-map/carplay-map.service"
[ -f "$UNIT_SRC" ] || UNIT_SRC="$PKG/units/carplay-map.service"
cp "$UNIT_SRC" "$TMP/units/carplay-map.service"

CLIENT_SHA=""
if [ -n "$CLIENT" ] && [ -f "$CLIENT" ]; then
  cp "$CLIENT" "$TMP/files/cluster_render_client.js"
  CLIENT_SHA=$(sha256sum "$TMP/files/cluster_render_client.js" | awk '{print $1}')
fi
SHA_P=$(sha256sum "$TMP/files/carplay-map-cluster.js" | awk '{print $1}')

# Avoid set -e abort from a failed command-substitution when CLIENT_SHA is empty.
node -e '
  var fs=require("fs");
  var d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  var shaP=process.argv[2], clientSha=process.argv[3] || "";
  d.files=(d.files||[]).filter(function(f){
    return f.path!=="cluster_render_client.js" || !!clientSha;
  });
  if (clientSha) {
    var has=false;
    (d.files||[]).forEach(function(f){ if(f.path==="cluster_render_client.js") has=true; });
    if (!has) d.files.push({ path: "cluster_render_client.js", mode: "0644" });
  }
  (d.files||[]).forEach(function(f){
    if(f.path==="carplay-map-cluster.js") f.sha256=shaP;
    if(f.path==="cluster_render_client.js" && clientSha) f.sha256=clientSha;
  });
  fs.writeFileSync(process.argv[4], JSON.stringify(d,null,2));
' "$PKG/component.json" "$SHA_P" "$CLIENT_SHA" "$TMP/component.json"

( cd "$TMP" && tar czf /tmp/carplay-map.tool.tgz component.json files units )

echo "-- instalando o produtor (tool) --"
"$MD" check   --artifact /tmp/carplay-map.tool.tgz
"$MD" install --artifact /tmp/carplay-map.tool.tgz --yes

if [ -f "$APP_TGZ" ]; then
  echo "-- instalando o app 'Mapa no Cluster' (liga/desliga) --"
  "$MD" install --artifact "$APP_TGZ" --yes || \
    echo "AVISO: app nao instalou (app-privacy esta instalado? ele e obrigatorio pro app)."
fi

systemctl restart carplay-map.service 2>/dev/null || true
echo ""
echo "== PRONTO =="
echo "Abra o CarPlay num mapa (layout Dashboard: mapa + os cards do lado) e olhe o cluster."
echo "Liga/desliga pelo app 'Mapa no Cluster'. Sobe sozinho no boot."
echo "Se waze-on-cluster tambem estiver ativo, desligue-o — os dois disputam o slot do mapa."
"$MD" status 2>/dev/null | grep -iE 'carplay-map|cluster-render|carplay_map_toggle' || true
