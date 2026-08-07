#!/bin/bash
# shellcheck disable=SC2250

set -euo pipefail

asset_root="$(cd "${1:-.}" && pwd)"
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_catalog="$asset_root/QuestKeeper/Assets.xcassets"
widget_catalog="$asset_root/QuestKeeperWidget/Assets.xcassets"

if ! command -v magick >/dev/null 2>&1; then
	echo "magick is required" >&2
	exit 69
fi

validate_imageset() {
	catalog_root="$1"
	asset_name="$2"
	imageset="$catalog_root/$asset_name.imageset"
	png="$imageset/$asset_name.png"
	manifest="$imageset/Contents.json"

	if [[ ! -f $png || ! -f $manifest ]]; then
		echo "missing imageset: $imageset" >&2
		exit 1
	fi
	plutil -convert xml1 -o /dev/null "$manifest"

	dimensions="$(magick identify -quiet -format '%wx%h' "$png")"
	width="${dimensions%x*}"
	height="${dimensions#*x}"
	if [[ $width -ne $height ]]; then
		echo "sprite is not square: $png ($dimensions)" >&2
		exit 1
	fi

	channels="$(magick identify -quiet -format '%[channels]' "$png")"
	case "$channels" in
	*a*) ;;
	*)
		echo "sprite has no alpha channel: $png ($channels)" >&2
		exit 1
		;;
	esac

	alpha_max="$(magick "$png" -alpha extract -format '%[fx:maxima]' info:)"
	if [[ $alpha_max == "0" ]]; then
		echo "sprite has no visible pixels: $png" >&2
		exit 1
	fi
}

monster_names="slime bat mushroom skeleton orc mimic dragon golem lich"
monster_count=0
for monster_name in $monster_names; do
	validate_imageset "$app_catalog" "sprite-$monster_name"
	validate_imageset "$widget_catalog" "sprite-$monster_name"
	monster_count=$((monster_count + 1))
done

hero_frames="idle breathe-in breathe-out wind-up strike"
hero_genders="male female"
hair_colors="black brown blue red"
hero_dimensions=""
hero_count=0
for hero_gender in $hero_genders; do
	for hair_color in $hair_colors; do
		for hero_frame in $hero_frames; do
			asset_name="sprite-hero-$hero_gender-$hair_color-$hero_frame"
			validate_imageset "$app_catalog" "$asset_name"
			current_dimensions="$(magick identify -quiet -format '%wx%h' "$app_catalog/$asset_name.imageset/$asset_name.png")"
			if [[ -z $hero_dimensions ]]; then
				hero_dimensions="$current_dimensions"
			elif [[ $hero_dimensions != "$current_dimensions" ]]; then
				echo "hero frame dimensions differ: $asset_name ($current_dimensions != $hero_dimensions)" >&2
				exit 1
			fi

			png="$app_catalog/$asset_name.imageset/$asset_name.png"
			geometry="$(magick "$png" -alpha extract -threshold 0 -format '%@' info:)"
			geometry_size="${geometry%%+*}"
			geometry_offset="${geometry#*+}"
			opaque_width="${geometry_size%x*}"
			opaque_height="${geometry_size#*x}"
			opaque_x="${geometry_offset%%+*}"
			opaque_y="${geometry_offset##*+}"
			center_delta=$((2 * opaque_x + opaque_width - 512))
			if ((center_delta < -1 || center_delta > 1)); then
				echo "hero frame is not horizontally centered: $asset_name ($geometry)" >&2
				exit 1
			fi
			if ((opaque_y + opaque_height != 384)); then
				echo "hero frame baseline differs: $asset_name ($geometry)" >&2
				exit 1
			fi
			hero_count=$((hero_count + 1))
		done
	done
done

temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT HUP INT TERM
for output_name in first second; do
	/bin/bash "$script_root/process-combat-assets.sh" \
		"$asset_root/docs/assets/pixel-combat-customization/questkeeper-monsters-left-source.png" \
		"$asset_root/docs/assets/pixel-combat-customization/questkeeper-heroes-source.png" \
		"$temporary_root/$output_name" >/dev/null
done
if ! diff -qr "$temporary_root/first" "$temporary_root/second" >/dev/null; then
	echo "combat asset generation is not byte-identical across runs" >&2
	exit 1
fi

echo "validated $monster_count monster kinds in app and widget catalogs, plus $hero_count app hero sprites"
