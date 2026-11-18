#!/bin/zsh
# Creates the Play Store upload key for Clockwork Calc and android/key.properties.
# Run once, in a terminal:  zsh tool/create_upload_key.sh
set -e

KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
KEYSTORE="$HOME/clockworkcalc-upload-keystore.jks"
PROPS="$(cd "$(dirname "$0")/.." && pwd)/android/key.properties"

if [[ -e "$KEYSTORE" ]]; then
  echo "$KEYSTORE already exists. Not overwriting it."
  exit 1
fi

read -s "KS_PASS?Choose a password for the upload key (at least 6 characters): "; echo
read -s "KS_PASS2?Type it again: "; echo
if [[ "$KS_PASS" != "$KS_PASS2" ]]; then echo "Passwords don't match."; exit 1; fi
if (( ${#KS_PASS} < 6 )); then echo "Too short."; exit 1; fi
export KS_PASS

echo
echo "Now a few questions for the certificate (name, organisation, city, country)."
echo "Any honest answers are fine; users never see them."
echo
"$KEYTOOL" -genkeypair -v \
  -keystore "$KEYSTORE" -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload -storepass:env KS_PASS

umask 077
cat > "$PROPS" <<PROPS
storePassword=$KS_PASS
keyPassword=$KS_PASS
keyAlias=upload
storeFile=$KEYSTORE
PROPS
unset KS_PASS KS_PASS2

echo
echo "Done."
echo "  Key:      $KEYSTORE"
echo "  Settings: $PROPS"
echo "Back up the key file AND the password somewhere safe (e.g. a password manager)."
