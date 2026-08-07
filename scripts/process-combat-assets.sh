#!/bin/bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
	echo "usage: $0 monster-source.png hero-source.png output-root" >&2
	exit 64
fi

monster_source="$1"
hero_source="$2"
output_root="$3"

if ! command -v magick >/dev/null 2>&1; then
	echo "magick is required" >&2
	exit 69
fi

for source_path in "$monster_source" "$hero_source"; do
	if [ ! -f "$source_path" ]; then
		echo "missing PNG source: $source_path" >&2
		exit 66
	fi
	if [ "$(magick identify -quiet -format '%m' "$source_path")" != "PNG" ]; then
		echo "source is not a PNG: $source_path" >&2
		exit 65
	fi
done

app_catalog="$output_root/QuestKeeper/Assets.xcassets"
widget_catalog="$output_root/QuestKeeperWidget/Assets.xcassets"
mkdir -p "$app_catalog" "$widget_catalog"

temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT HUP INT TERM

write_imageset() {
	catalog_root="$1"
	asset_name="$2"
	source_png="$3"
	imageset="$catalog_root/$asset_name.imageset"
	mkdir -p "$imageset"
	cp "$source_png" "$imageset/$asset_name.png"
	cat >"$imageset/Contents.json" <<JSON
{
  "images": [
    {
      "filename": "$asset_name.png",
      "idiom": "universal",
      "scale": "1x"
    },
    {
      "idiom": "universal",
      "scale": "2x"
    },
    {
      "idiom": "universal",
      "scale": "3x"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
JSON
}

crop_cell() {
	source_path="$1"
	columns="$2"
	rows="$3"
	column="$4"
	row="$5"
	inset_left="$6"
	inset_top="$7"
	inset_right="$8"
	inset_bottom="$9"
	destination="${10}"
	source_width="$(magick identify -quiet -format '%w' "$source_path")"
	source_height="$(magick identify -quiet -format '%h' "$source_path")"
	left=$(((column * source_width + columns / 2) / columns))
	right=$((((column + 1) * source_width + columns / 2) / columns))
	top=$(((row * source_height + rows / 2) / rows))
	bottom=$((((row + 1) * source_height + rows / 2) / rows))
	cell_width=$((right - left))
	cell_height=$((bottom - top))
	left=$((left + inset_left))
	top=$((top + inset_top))
	cell_width=$((cell_width - inset_left - inset_right))
	cell_height=$((cell_height - inset_top - inset_bottom))

	magick "$source_path" \
		-crop "${cell_width}x${cell_height}+${left}+${top}" +repage \
		-fuzz 38% -transparent '#FF00FF' \
		-background none -gravity center -extent 512x512 \
		"$destination"
}

monster_names="slime bat mushroom skeleton orc mimic dragon golem lich"
monster_index=0
for monster_name in $monster_names; do
	monster_column=$((monster_index % 3))
	monster_row=$((monster_index / 3))
	monster_bottom_inset=12
	monster_right_inset=12
	if [ "$monster_row" -eq 1 ]; then
		monster_bottom_inset=40
	fi
	if [ "$monster_name" = "golem" ]; then
		monster_right_inset=40
	fi
	monster_png="$temporary_root/sprite-$monster_name.png"
	crop_cell "$monster_source" 3 3 "$monster_column" "$monster_row" 12 12 "$monster_right_inset" "$monster_bottom_inset" "$monster_png"
	write_imageset "$app_catalog" "sprite-$monster_name" "$monster_png"
	write_imageset "$widget_catalog" "sprite-$monster_name" "$monster_png"
	monster_index=$((monster_index + 1))
done

hero_frames="idle breathe-in breathe-out wind-up strike"
hero_genders="male female"
hair_colors="black brown blue red"
hero_row=0
for hero_gender in $hero_genders; do
	hero_column=0
	for hero_frame in $hero_frames; do
		base_png="$temporary_root/$hero_gender-$hero_frame.png"
		hair_mask="$temporary_root/$hero_gender-$hero_frame-hair-mask.png"
		crop_cell "$hero_source" 5 2 "$hero_column" "$hero_row" 12 12 12 12 "$base_png"

		magick "$base_png" -alpha off -fuzz 12% -fill white -opaque '#0346AA' -fill black +opaque white "$hair_mask"

		for hair_color in $hair_colors; do
			hero_png="$temporary_root/sprite-hero-$hero_gender-$hair_color-$hero_frame.png"
			case "$hair_color" in
			blue)
				cp "$base_png" "$hero_png"
				;;
			black)
				matrix='0 0 0.12 0 0  0 0 0.14 0 0  0 0 0.18 0 0  0 0 0 1 0  0 0 0 0 1'
				magick "$base_png" -color-matrix "$matrix" "$temporary_root/recolored.png"
				magick "$base_png" "$temporary_root/recolored.png" "$hair_mask" -composite "$hero_png"
				;;
			brown)
				matrix='0 0 0.62 0 0  0 0 0.34 0 0  0 0 0.14 0 0  0 0 0 1 0  0 0 0 0 1'
				magick "$base_png" -color-matrix "$matrix" "$temporary_root/recolored.png"
				magick "$base_png" "$temporary_root/recolored.png" "$hair_mask" -composite "$hero_png"
				;;
			red)
				matrix='0 0 0.86 0 0  0 0 0.10 0 0  0 0 0.09 0 0  0 0 0 1 0  0 0 0 0 1'
				magick "$base_png" -color-matrix "$matrix" "$temporary_root/recolored.png"
				magick "$base_png" "$temporary_root/recolored.png" "$hair_mask" -composite "$hero_png"
				;;
			esac
			write_imageset "$app_catalog" "sprite-hero-$hero_gender-$hair_color-$hero_frame" "$hero_png"
		done

		hero_column=$((hero_column + 1))
	done
	hero_row=$((hero_row + 1))
done

echo "generated 49 app sprites and 9 widget sprites in $output_root"
