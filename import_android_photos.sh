#!/bin/bash

DEST_DIR="$HOME/Pictures/Photos/2026"
FILE_LIST="missing_on_mac.txt"

# Forcer PATH pour adb et autres
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

[ -f "$FILE_LIST" ] || { echo "❌ Fichier $FILE_LIST introuvable"; exit 1; }

mkdir -p "$DEST_DIR"

FOUND_LOCAL=0
COPIED=0
NOT_FOUND=0

# Lecture ligne par ligne, même si retour chariot Windows ou caractères spéciaux
while IFS= read -r LINE || [ -n "$LINE" ]; do
    # Nettoyer CR si présent
    LINE="${LINE//$'\r'/}"

    [ -z "$LINE" ] && continue

    FILENAME="$(basename "$LINE")"
    LOCAL_FILE="$DEST_DIR/$FILENAME"

    if [ -f "$LOCAL_FILE" ]; then
        echo "✅ Déjà présent : $FILENAME"
        ((FOUND_LOCAL++))
        continue
    fi

    # Recherche sur Mac avec Spotlight uniquement dans le dossier 2026
    if mdfind -onlyin "$DEST_DIR" "kMDItemFSName == '$FILENAME'" | grep -q .; then
        echo "✅ Trouvé ailleurs sur Mac : $FILENAME"
        ((FOUND_LOCAL++))
        continue
    fi

    FOUND_ON_PHONE=false
    ANDROID_DIRS=(
      "storage/self/primary/DCIM/Camera"
      "storage/sdcard0/DCIM/Camera"
      "storage/4FBD-AF15/DCIM/Camera/"
    )

    for DIR in "${ANDROID_DIRS[@]}"; do
        REMOTE_PATH="/$DIR/$FILENAME"
        if adb shell "[ -f \"$REMOTE_PATH\" ]" >/dev/null 2>&1; then
            echo "⬇️  Copie depuis téléphone : $REMOTE_PATH"
            adb pull "$REMOTE_PATH" "$DEST_DIR/" && ((COPIED++))
            FOUND_ON_PHONE=true
            break
        fi
    done

    if [ "$FOUND_ON_PHONE" = false ]; then
        echo "❌ Introuvable sur Mac et téléphone : $FILENAME"
        ((NOT_FOUND++))
    fi

done < "$FILE_LIST"

echo
echo "📊 Résumé"
echo "   ✔️ Déjà présents sur Mac : $FOUND_LOCAL"
echo "   ⬇️ Copiés depuis Android : $COPIED"
echo "   ❌ Introuvables téléphone : $NOT_FOUND"
echo "✨ Terminé"
