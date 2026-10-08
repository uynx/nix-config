steam_root=$1 appid=$2
for f in "$steam_root/appcache/librarycache/$appid"/*.jpg; do
  if [[ ${f##*/} =~ ^[0-9a-f]{40}\.jpg$ ]]; then
    echo "$f"
    exit 0
  fi
done
echo steam
