#!/usr/bin/env bash
# Generate readme-preview/ thumbnails from all wallpapers (recursive) and update README.md.
# Requires ImageMagick (magick). Run from repo root.

set -e
cd "$(git rev-parse --show-toplevel)"
PREVIEW_DIR=.github/readme-preview
# 16:9 thumbnails
THUMB_W=320
THUMB_H=180
QUALITY=82

shopt -s nullglob
mkdir -p "$PREVIEW_DIR"

# Find all images recursively, excluding .git and .github
while IFS= read -r -d '' f; do
  # Get relative path from repo root
  rel_path="${f#./}"
  # Get directory (empty if root)
  dir_path=$(dirname "$rel_path")
  base=$(basename "$rel_path")
  base_no_ext="${base%.*}"
  
  # Create thumbnail path preserving directory structure
  if [ "$dir_path" = "." ]; then
    thumb="$PREVIEW_DIR/${base_no_ext}.jpg"
  else
    thumb="$PREVIEW_DIR/${dir_path}/${base_no_ext}.jpg"
    mkdir -p "$PREVIEW_DIR/${dir_path}"
  fi
  
  # Generate thumbnail if needed
  if [ ! -f "$thumb" ] || [ "$f" -nt "$thumb" ]; then
    magick "$f" -auto-orient -resize "${THUMB_W}x${THUMB_H}^" -gravity center -extent "${THUMB_W}x${THUMB_H}" -quality "$QUALITY" "$thumb"
    echo "  $rel_path -> $thumb"
  fi
done < <(find . -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) ! -path "./.git/*" ! -path "./.github/*" -print0)

# Build README with preview grid: 3 per row, organized by folder
cat > README.md << 'README_HEAD'
README_HEAD

# Process root-level images first
root_count=0
while IFS= read -r -d '' f; do
  [ $root_count -eq 0 ] && echo "## Root" >> README.md && echo "" >> README.md && echo '<table align="center"><tr>' >> README.md
  rel_path="${f#./}"
  base=$(basename "$rel_path")
  base_no_ext="${base%.*}"
  thumb="$PREVIEW_DIR/${base_no_ext}.jpg"
  [ -f "$thumb" ] || continue
  [ $root_count -gt 0 ] && [ $((root_count % 3)) -eq 0 ] && echo '</tr><tr>' >> README.md
  echo "  <td align=\"center\"><a href=\"$rel_path\"><img src=\"$thumb\" width=\"320\" height=\"180\" style=\"object-fit: cover;\" alt=\"$base_no_ext\"></a></td>" >> README.md
  root_count=$((root_count + 1))
done < <(find . -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -print0 | sort -z)

[ $root_count -gt 0 ] && echo '</tr></table>' >> README.md && echo "" >> README.md

# Process subdirectories (most recent month first, sorted by YY-MM in folder name)
# Extract year-month from folder names like "26 - 02 - February" and sort descending
sorted_dirs=()
while IFS= read -r line; do
  sorted_dirs+=("$line")
done < <(
  for d in */; do
    [ -d "$d" ] || continue
    dir_name="${d%/}"
    [[ "$dir_name" == .git* ]] && continue
    # Extract YY-MM from "YY - MM - MonthName" format
    if [[ "$dir_name" =~ ^([0-9]+)[[:space:]]*-[[:space:]]*([0-9]+) ]]; then
      year="${BASH_REMATCH[1]}"
      month="${BASH_REMATCH[2]}"
      # Format as YYMM for sorting (use 10# to force decimal interpretation)
      printf "%02d%02d %s\n" "$((10#$year))" "$((10#$month))" "$d"
    else
      # Fallback: put non-matching folders at the very end
      printf "0000 %s\n" "$d"
    fi
  done | sort -rn | cut -d' ' -f2-
)

for dir in "${sorted_dirs[@]}"; do
  dir_name="${dir%/}"
  
  dir_count=0
  while IFS= read -r -d '' f; do
    [ $dir_count -eq 0 ] && echo "## ${dir_name}" >> README.md && echo "" >> README.md && echo '<table align="center"><tr>' >> README.md
    rel_path="${f#./}"
    base=$(basename "$rel_path")
    base_no_ext="${base%.*}"
    thumb="$PREVIEW_DIR/${rel_path%.*}.jpg"
    [ -f "$thumb" ] || continue
    [ $dir_count -gt 0 ] && [ $((dir_count % 3)) -eq 0 ] && echo '</tr><tr>' >> README.md
    echo "  <td align=\"center\"><a href=\"$rel_path\"><img src=\"$thumb\" width=\"320\" height=\"180\" style=\"object-fit: cover;\" alt=\"$base_no_ext\"></a></td>" >> README.md
    dir_count=$((dir_count + 1))
  done < <(find "$dir" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -print0 | sort -z)
  
  [ $dir_count -gt 0 ] && echo '</tr></table>' >> README.md && echo "" >> README.md
done

echo "Done. README.md and $PREVIEW_DIR/ updated."
