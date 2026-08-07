#!/bin/bash
# shellcheck disable=SC2250

set -euo pipefail

if [[ $# -ne 3 ]]; then
	echo "usage: $0 monster-source.png hero-source.png output-root" >&2
	exit 64
fi

monster_source="$1"
hero_source="$2"
output_root="$3"
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for source_path in "$monster_source" "$hero_source"; do
	if [[ ! -f $source_path ]]; then
		echo "missing PNG source: $source_path" >&2
		exit 66
	fi
done

temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT HUP INT TERM
approved_monster_source="$temporary_root/approved-monster-source.png"
approved_hero_source="$temporary_root/approved-hero-source.png"
cp "$monster_source" "$approved_monster_source"
cp "$hero_source" "$approved_hero_source"
monster_source="$approved_monster_source"
hero_source="$approved_hero_source"

monster_hash_line="$(/usr/bin/shasum -a 256 "$monster_source")"
hero_hash_line="$(/usr/bin/shasum -a 256 "$hero_source")"
monster_hash="${monster_hash_line%% *}"
hero_hash="${hero_hash_line%% *}"
if [[ $monster_hash != "4d25b875f0c6801d13483e3c06432404aa13d67567cb261202212731e2f702d5" ]]; then
	echo "monster source does not match the approved sheet" >&2
	exit 65
fi
if [[ $hero_hash != "3a191d94842662fd729dfc75ab74e6cb85d89f6d77f250225627fc37a20ccce5" ]]; then
	echo "hero source does not match the approved sheet" >&2
	exit 65
fi

if ! command -v magick >/dev/null 2>&1; then
	echo "magick is required" >&2
	exit 69
fi

for source_path in "$monster_source" "$hero_source"; do
	source_format="$(magick identify -quiet -format '%m' "$source_path")"
	if [[ $source_format != "PNG" ]]; then
		echo "source is not a PNG: $source_path" >&2
		exit 65
	fi
done

generated_root="$temporary_root/generated"
app_catalog="$generated_root/QuestKeeper/Assets.xcassets"
widget_catalog="$generated_root/QuestKeeperWidget/Assets.xcassets"
output_app_catalog="$output_root/QuestKeeper/Assets.xcassets"
output_widget_catalog="$output_root/QuestKeeperWidget/Assets.xcassets"
mkdir -p "$app_catalog" "$widget_catalog"

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

remove_chroma_fringe() {
	source_path="$1"
	destination="$2"
	chroma_mask="$temporary_root/chroma-mask.png"
	opaque_mask="$temporary_root/opaque-mask.png"
	transparent_mask="$temporary_root/transparent-mask.png"
	traversable_mask="$temporary_root/traversable-mask.png"
	connected_mask="$temporary_root/connected-mask.png"
	fringe_mask="$temporary_root/fringe-mask.png"
	clean_alpha="$temporary_root/clean-alpha.png"

	magick "$source_path" -alpha on \
		-fx '((a > 0) * (r > 1.5 * g) * (b > 1.5 * g) * (r + b > 0.25)) ? 1 : 0' \
		-alpha off "$chroma_mask"
	magick "$source_path" -alpha extract -threshold 0 "$opaque_mask"
	magick "$opaque_mask" -negate "$transparent_mask"
	magick "$transparent_mask" "$chroma_mask" -compose Lighten -composite "$traversable_mask"
	magick "$traversable_mask" -fill '#808080' -draw 'color 0,0 floodfill' "$connected_mask"
	magick "$connected_mask" -alpha off -fuzz 1% \
		-fill black +opaque '#808080' -fill white -opaque '#808080' "$connected_mask"
	magick "$connected_mask" "$chroma_mask" -compose multiply -composite "$fringe_mask"
	magick "$source_path" -alpha extract "$clean_alpha"
	magick "$clean_alpha" \( "$fringe_mask" -negate \) -compose multiply -composite "$clean_alpha"
	magick "$source_path" "$clean_alpha" -compose CopyOpacity -composite -strip "$destination"
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

	unclean_destination="$temporary_root/cropped-with-fringe.png"
	magick "$source_path" \
		-crop "${cell_width}x${cell_height}+${left}+${top}" +repage \
		-fuzz 38% -transparent '#FF00FF' \
		-background none -gravity center -extent 512x512 \
		-strip "$unclean_destination"
	remove_chroma_fringe "$unclean_destination" "$destination"
}

monster_names="slime bat mushroom skeleton orc mimic dragon golem lich"
monster_index=0
for monster_name in $monster_names; do
	monster_column=$((monster_index % 3))
	monster_row=$((monster_index / 3))
	monster_bottom_inset=12
	monster_right_inset=12
	if [[ $monster_row -eq 1 ]]; then
		monster_bottom_inset=40
	fi
	if [[ $monster_name == "golem" ]]; then
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
hair_region_mask="$temporary_root/hero-hair-region-mask.png"
magick -size 512x512 xc:black -fill white -draw 'rectangle 0,0 511,259' "$hair_region_mask"
hero_row=0
for hero_gender in $hero_genders; do
	hero_column=0
	for hero_frame in $hero_frames; do
		base_png="$temporary_root/$hero_gender-$hero_frame.png"
		cropped_png="$temporary_root/$hero_gender-$hero_frame-cropped.png"
		color_mask="$temporary_root/$hero_gender-$hero_frame-color-mask.png"
		hair_mask="$temporary_root/$hero_gender-$hero_frame-hair-mask.png"
		crop_cell "$hero_source" 5 2 "$hero_column" "$hero_row" 12 12 12 12 "$cropped_png"
		magick "$cropped_png" -trim +repage \
			-background none -gravity south -extent 512x384 \
			-gravity north -extent 512x512 \
			-strip "$base_png"

		magick "$base_png" -alpha off -fuzz 12% -fill black +opaque '#0346AA' -fill white -opaque '#0346AA' "$color_mask"
		magick "$color_mask" "$hair_region_mask" -compose multiply -composite "$hair_mask"

		for hair_color in $hair_colors; do
			hero_png="$temporary_root/sprite-hero-$hero_gender-$hair_color-$hero_frame.png"
			case "$hair_color" in
			blue)
				magick "$base_png" -strip "$hero_png"
				;;
			black)
				matrix='0 0 0.12 0 0  0 0 0.14 0 0  0 0 0.18 0 0  0 0 0 1 0  0 0 0 0 1'
				magick "$base_png" -color-matrix "$matrix" "$temporary_root/recolored.png"
				magick "$base_png" "$temporary_root/recolored.png" "$hair_mask" -composite -strip "$hero_png"
				;;
			brown)
				matrix='0 0 0.62 0 0  0 0 0.34 0 0  0 0 0.14 0 0  0 0 0 1 0  0 0 0 0 1'
				magick "$base_png" -color-matrix "$matrix" "$temporary_root/recolored.png"
				magick "$base_png" "$temporary_root/recolored.png" "$hair_mask" -composite -strip "$hero_png"
				;;
			red)
				matrix='0 0 0.86 0 0  0 0 0.10 0 0  0 0 0.09 0 0  0 0 0 1 0  0 0 0 0 1'
				magick "$base_png" -color-matrix "$matrix" "$temporary_root/recolored.png"
				magick "$base_png" "$temporary_root/recolored.png" "$hair_mask" -composite -strip "$hero_png"
				;;
			*)
				echo "unsupported hair color: $hair_color" >&2
				exit 65
				;;
			esac
			write_imageset "$app_catalog" "sprite-hero-$hero_gender-$hair_color-$hero_frame" "$hero_png"
		done

		hero_column=$((hero_column + 1))
	done
	hero_row=$((hero_row + 1))
done

/usr/bin/env QUESTKEEPER_SKIP_GENERATION_CHECK=1 /bin/bash "$script_root/test-combat-assets.sh" "$generated_root" >/dev/null
mkdir -p "$output_app_catalog" "$output_widget_catalog"
cp -R "$app_catalog"/. "$output_app_catalog"/
cp -R "$widget_catalog"/. "$output_widget_catalog"/

echo "generated 49 app sprites and 9 widget sprites in $output_root"
