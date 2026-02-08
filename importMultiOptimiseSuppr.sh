#!/bin/bash

############################################
# CONFIG
############################################

EXIFTOOL="/opt/homebrew/bin/exiftool"
DEST="/Users/thomasdalmayrac/Pictures/Photos"
LOCALSEND="/Users/thomasdalmayrac/Pictures/Photos/ImportsLocalSendNew"

SOURCES=(
  "/Volumes/Lumix G80/DCIM"
  "/Volumes/DJI Mini 4k"
  "/Volumes/Insta360"
  "$LOCALSEND"
)

PARALLEL_JOBS=$(sysctl -n hw.ncpu)
echo "⚡ Import avec $PARALLEL_JOBS jobs parallèles"

############################################
# FONCTION DE COPIE
############################################

copy_file() {
    file="$1"
    filename="$(basename "$file")"
    date=""

    # 1️⃣ Date depuis le nom de fichier (YYYYMMDD)
    if [[ "$filename" =~ ([0-9]{4})(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01]) ]]; then
        year="${BASH_REMATCH[1]}"
        month="${BASH_REMATCH[2]}"
        day="${BASH_REMATCH[3]}"
        date="$year-$month-$day"
    else
        # 2️⃣ EXIF
        date=$("$EXIFTOOL" -s -s -s -DateTimeOriginal "$file" 2>/dev/null \
               | awk '{print $1}' | tr ':' '-')
    fi

    # 3️⃣ Fallback stat
    if [[ -z "$date" ]]; then
        echo "⚠️ Date inconnue → stat : $file"
        date=$(stat -f "%Sm" -t "%Y-%m-%d" "$file")
    fi

    year="${date:0:4}"
    month="${date:0:7}"

    target_dir="$DEST/$year/$month/$date"
    mkdir -p "$target_dir"

    target_file="$target_dir/$filename"

    if [[ ! -e "$target_file" ]]; then
        cp "$file" "$target_file" && echo "✔ Copié : $file → $target_file"
    fi
}

export -f copy_file
export DEST EXIFTOOL

############################################
# IMPORT
############################################

for SRC in "${SOURCES[@]}"; do
    if [[ -d "$SRC" ]]; then
        echo "🔎 Scan de $SRC"

        find "$SRC" -type f \( \
            -iname "*.jpg" \
            -o -iname "*.rw2" \
            -o -iname "*.mp4" \
            -o -iname "*.insv" \
	    -o -iname "*.insp" \
            -o -iname "*.dng" \
        \) -print0 | \
        xargs -0 -n1 -P "$PARALLEL_JOBS" bash -c 'copy_file "$0"' 
    else
        echo "⚠️ Source absente : $SRC"
    fi
done

############################################
# NETTOYAGE LOCALSEND
############################################

if [[ -d "$LOCALSEND" ]]; then
    echo "🧹 Nettoyage LocalSend..."

    find "$LOCALSEND" -type f \( \
        -iname "*.jpg" \
        -o -iname "*.rw2" \
        -o -iname "*.mp4" \
        -o -iname "*.dng" \
    \) | while read -r f; do
        # Décommente la ligne suivante si tu veux supprimer les fichiers après import
        rm "$f" && echo "🗑 Supprimé : $f"
        :
    done
fi

############################################
# ÉJECTION DES VOLUMES
############################################

echo "⏏️ Éjection des volumes externes..."

for vol in /Volumes/*; do
    case "$vol" in
        "/Volumes/Macintosh HD"*) ;;
        *)
            if mount | grep -q "$vol"; then
                echo "⏏️ $vol"
                diskutil eject "$vol" >/dev/null 2>&1
            fi
        ;;
    esac
done

echo "✅ Import terminé"
