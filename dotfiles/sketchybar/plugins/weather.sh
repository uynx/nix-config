#!/usr/bin/env bash
# Fetches local weather from wttr.in using geocoordinates extracted from the native macOS Weather app cache database (falling back to ~/.weather_location).

LOCATION=""

DB_PATH="$HOME/Library/Containers/com.apple.weather/Data/Library/Caches/com.apple.weather/Cache.db"
if [ -f "$DB_PATH" ]; then
  URL=$(sqlite3 "$DB_PATH" "SELECT request_key FROM cfurl_cache_response WHERE request_key LIKE '%weatherkit.apple.com/api/v2/weather%' AND request_key LIKE '%locationInfo%' ORDER BY entry_ID DESC LIMIT 1;" 2>/dev/null)
  if [[ "$URL" =~ weather/[a-zA-Z-]+/([0-9.-]+)/([0-9.-]+) ]]; then
    LOCATION="${BASH_REMATCH[1]},${BASH_REMATCH[2]}"
    echo "$LOCATION" > "$HOME/.weather_location"
  fi
fi

if [ -z "$LOCATION" ] && [ -f "$HOME/.weather_location" ]; then
  LOCATION=$(cat "$HOME/.weather_location" | xargs)
fi

if [ -z "$LOCATION" ]; then
  sketchybar --set "$NAME" label=" N/A"
  exit 0
fi

LAT=${LOCATION%,*}
LON=${LOCATION#*,}

STATION_FILE="$HOME/.weather_station"
PREV_LOC_FILE="$HOME/.weather_location_prev"
STATION=""

if [ -f "$PREV_LOC_FILE" ]; then
  PREV_LOC=$(cat "$PREV_LOC_FILE" | xargs)
else
  PREV_LOC=""
fi

if [ "$LOCATION" != "$PREV_LOC" ] || [ ! -f "$STATION_FILE" ]; then
  GRID_RESPONSE=$(curl -s -H "User-Agent: (myweatherapp, brandonwalex@pm.me)" "https://api.weather.gov/points/${LAT},${LON}" 2>/dev/null)
  STATIONS_URL=$(echo "$GRID_RESPONSE" | jq -r '.properties.observationStations' 2>/dev/null)
  
  if [ -n "$STATIONS_URL" ] && [ "$STATIONS_URL" != "null" ]; then
    STATION_RESPONSE=$(curl -s -H "User-Agent: (myweatherapp, brandonwalex@pm.me)" "$STATIONS_URL" 2>/dev/null)
    STATION=$(echo "$STATION_RESPONSE" | jq -r '.features[0].properties.stationIdentifier' 2>/dev/null)
    
    if [ -n "$STATION" ] && [ "$STATION" != "null" ]; then
      echo "$STATION" > "$STATION_FILE"
      echo "$LOCATION" > "$PREV_LOC_FILE"
    fi
  fi
fi

if [ -z "$STATION" ] && [ -f "$STATION_FILE" ]; then
  STATION=$(cat "$STATION_FILE" | xargs)
fi

if [ -z "$STATION" ]; then
  STATION="KDFW"
fi

RESPONSE=$(curl -s -H "User-Agent: (myweatherapp, brandonwalex@pm.me)" "https://api.weather.gov/stations/${STATION}/observations/latest" 2>/dev/null)

if [ -n "$RESPONSE" ] && [[ ! "$RESPONSE" =~ "error" ]]; then
  TEMP_C=$(echo "$RESPONSE" | jq -r '.properties.temperature.value')
  if [ "$TEMP_C" != "null" ] && [ -n "$TEMP_C" ]; then
    TEMP=$(awk -v tc="$TEMP_C" 'BEGIN { printf "%.0f", (tc * 9 / 5) + 32 }')
  else
    TEMP="N/A"
  fi
  
  ICON_URL=$(echo "$RESPONSE" | jq -r '.properties.icon')
  ICON_BASE="${ICON_URL%%\?*}"
  ICON_CODE="${ICON_BASE##*/}"
  ICON_CODE="${ICON_CODE%%,*}"
  
  case "$ICON_CODE" in
    skc|few)
      if [[ "$ICON_URL" =~ "/night/" ]]; then
        ICON="🌙"
      else
        ICON="☀️"
      fi
      ;;
    sct|bkn) ICON="🌤️" ;;
    ovc) ICON="☁️" ;;
    wind*) ICON="💨" ;;
    fog|smoke|haze|dust) ICON="🌫️" ;;
    rain*|showers*) ICON="🌧️" ;;
    sleet*|snow*|fzra*) ICON="❄️" ;;
    tsra*) ICON="⛈️" ;;
    tornado*) ICON="🌪️" ;;
    *) ICON="" ;;
  esac
  
  if [ "$TEMP" != "N/A" ]; then
    sketchybar --set "$NAME" label="$ICON ${TEMP}°F"
  else
    sketchybar --set "$NAME" label=" N/A"
  fi
else
  sketchybar --set "$NAME" label=" N/A"
fi
