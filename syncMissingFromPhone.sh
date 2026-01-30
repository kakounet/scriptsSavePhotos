#!/bin/bash

DEST_DIR="$HOME/Pictures/Photos/2026"
FILE_LIST="liste.txt"

ANDROID_DIRS=(
  "storage/self/primary/DCIM/Camera"
  "storage/sdcard0/DCIM/Camera"
  "storage/4FBD-AF15/DCIM/Camera"
)

mkdir -p "$DEST_DIR"

# Charger toutes les lignes dans un tableau compatible bash 3.2
FILES=()
while IFS= read -r line; do
  [ -n "$line" ] && FILES+=("$line")
done < "$FILE_LIST"

FOUND_LOCAL=0
COPIED=0
NOT_FOUND=0
MISSING_LIST="$DEST_DIR/missing.txt"
> "$MISSING_LIST"

TOTAL=${#FILES[@]}

for i in "${!FILES[@]}"; do
  LINE="${FILES[$i]}"
  echo "🔹 [$((i+1))/$TOTAL] Traitement du fichier : '$LINE'"

  FILENAME="$(basename "$LINE")"
  LOCAL_FILE="$DEST_DIR/$FILENAME"

  if [ -f "$LOCAL_FILE" ]; then
    echo "✅ Déjà présent sur Mac : $FILENAME"
    ((FOUND_LOCAL++))
    continue
  fi

  FOUND_ON_PHONE=false

  for DIR in "${ANDROID_DIRS[@]}"; do
    REMOTE_PATH="/$DIR/$FILENAME"
    if adb shell "[ -f \"$REMOTE_PATH\" ]" >/dev/null 2>&1; then
      echo "⬇️  Copie depuis téléphone : $REMOTE_PATH"
      if adb pull "$REMOTE_PATH" "$DEST_DIR/" >/dev/null 2>&1; then
        ((COPIED++))
      else
        echo "⚠️ Erreur lors de la copie de $FILENAME"
      fi
      FOUND_ON_PHONE=true
      break
    fi
  done

  if [ "$FOUND_ON_PHONE" = false ]; then
    echo "❌ Introuvable sur Mac et téléphone : $FILENAME"
    ((NOT_FOUND++))
    echo "$FILENAME" >> "$MISSING_LIST"
  fi
done

echo
echo "📊 Résumé"
echo "   ✔️ Déjà présents sur Mac : $FOUND_LOCAL"
echo "   ⬇️ Copiés depuis Android : $COPIED"
echo "   ❌ Introuvables téléphone : $NOT_FOUND"
echo "   📄 Liste des manquants : $MISSING_LIST"
echo "✨ Terminé"
