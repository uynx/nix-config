set -eu
src=$1
policy=$2
out=$3
w=$(mktemp -d)
mkdir -p "$w/assets" "$w/classes" "$w/dex"
cp "$policy" "$w/assets/policy.json"
aapt2 compile --dir "$src/res" -o "$w/res.zip"
# targetSdk 29 keeps Android 11's 4-byte resources.arsc alignment rule off, so no zipalign is needed.
aapt2 link -I "$ANDROID_JAR" --manifest "$src/AndroidManifest.xml" -A "$w/assets" \
  --min-sdk-version 29 --target-sdk-version 29 --version-code 1 --version-name 1 \
  -o "$w/base.apk" "$w/res.zip"
javac --release 11 -cp "$ANDROID_JAR" -d "$w/classes" "$src/Admin.java"
java -cp "$R8_JAR" com.android.tools.r8.D8 --release --min-api 29 --lib "$ANDROID_JAR" \
  --output "$w/dex" "$w"/classes/dev/uynx/siteblock/*.class
cp "$w/base.apk" "$out"
chmod u+w "$out"
zip -qj "$out" "$w/dex/classes.dex"
rm -rf "$w"
