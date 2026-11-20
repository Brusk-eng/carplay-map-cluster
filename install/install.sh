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
if [ -e /var/opt/waze-on-cluster/current ]; then
  echo "ERRO: waze-on-cluster esta instalado (/var/opt/waze-on-cluster/current)."
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

if [ -n "$CLIENT" ] && [ -f "$CLIENT" ]; then
  cp "$CLIENT" "$TMP/files/cluster_render_client.js"
fi

# Hash every payload file — mgu-deploy refuses missing sha256.
node -e '
  var fs=require("fs"), path=require("path"), crypto=require("crypto");
  var d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  var filesDir=process.argv[2], out=process.argv[3];
  function sha(p){ return crypto.createHash("sha256").update(fs.readFileSync(p)).digest("hex"); }
  var onDisk={};
  fs.readdirSync(filesDir).forEach(function(n){
    var p=path.join(filesDir,n);
    if (fs.statSync(p).isFile()) onDisk[n]=sha(p);
  });
  d.files=(d.files||[]).filter(function(f){ return !!onDisk[f.path]; });
  Object.keys(onDisk).forEach(function(n){
    if (!(d.files||[]).some(function(f){ return f.path===n; })) {
      d.files.push({ path: n, mode: n.slice(-3)===".js" ? "0755" : "0644" });
    }
  });
  (d.files||[]).forEach(function(f){ f.sha256=onDisk[f.path]; });
  if (!(d.files||[]).length) throw new Error("no payload files");
  fs.writeFileSync(out, JSON.stringify(d,null,2));
' "$PKG/component.json" "$TMP/files" "$TMP/component.json"

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
"$MD" status 2>/dev/null | grep -iE 'carplay-map|cluster-render|carplay_map_toggle' || true
