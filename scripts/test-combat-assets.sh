#!/bin/bash
# shellcheck disable=SC2016,SC2250

set -euo pipefail

asset_root="$(cd "${1:-.}" && pwd)"
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_catalog="$asset_root/QuestKeeper/Assets.xcassets"
widget_catalog="$asset_root/QuestKeeperWidget/Assets.xcassets"

if ! command -v magick >/dev/null 2>&1; then
	echo "magick is required" >&2
	exit 69
fi

temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT HUP INT TERM
hair_region_mask="$temporary_root/hero-hair-region-mask.png"
magick -size 512x512 xc:black -fill white -draw 'rectangle 0,0 511,259' "$hair_region_mask"

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

	fringe_edge_mask="$temporary_root/fringe-edge-mask.png"
	fringe_chroma_mask="$temporary_root/fringe-chroma-mask.png"
	fringe_mask="$temporary_root/fringe-mask.png"
	fringe_allowed_mask="$temporary_root/fringe-allowed-mask.png"
	magick "$png" -alpha extract -threshold 0 -morphology EdgeIn Diamond:1 "$fringe_edge_mask"
	magick "$png" -alpha on \
		-fx '((a > 0) * (r > 1.5 * g) * (b > 1.5 * g) * (r + b > 0.25)) ? 1 : 0' \
		-alpha off "$fringe_chroma_mask"
	magick "$fringe_edge_mask" "$fringe_chroma_mask" -compose multiply -composite "$fringe_mask"
	magick -size "${width}x${height}" xc:black "$fringe_allowed_mask"
	case "$asset_name" in
	sprite-bat) magick "$fringe_allowed_mask" -fill white -draw 'rectangle 152,261 206,279' "$fringe_allowed_mask" ;;
	sprite-lich) magick "$fringe_allowed_mask" -fill white -draw 'rectangle 170,127 211,138' "$fringe_allowed_mask" ;;
	*) ;;
	esac
	fringe_max="$(magick "$fringe_mask" \( "$fringe_allowed_mask" -negate \) \
		-compose multiply -composite -format '%[fx:maxima]' info:)"
	if [[ $fringe_max != "0" ]]; then
		echo "sprite retains chroma fringe outside approved detail regions: $png" >&2
		exit 1
	fi
}

monster_names="slime bat mushroom skeleton orc mimic dragon golem lich"
monster_count=0
for monster_name in $monster_names; do
	validate_imageset "$app_catalog" "sprite-$monster_name"
	validate_imageset "$widget_catalog" "sprite-$monster_name"
	if ! cmp -s \
		"$app_catalog/sprite-$monster_name.imageset/sprite-$monster_name.png" \
		"$widget_catalog/sprite-$monster_name.imageset/sprite-$monster_name.png"; then
		echo "app and widget monster assets differ: $monster_name" >&2
		exit 1
	fi
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

for hero_gender in $hero_genders; do
	for hero_frame in $hero_frames; do
		blue_name="sprite-hero-$hero_gender-blue-$hero_frame"
		blue_png="$app_catalog/$blue_name.imageset/$blue_name.png"
		color_mask="$temporary_root/$hero_gender-$hero_frame-color-mask.png"
		hair_mask="$temporary_root/$hero_gender-$hero_frame-hair-mask.png"
		visible_mask="$temporary_root/$hero_gender-$hero_frame-visible-mask.png"
		outside_mask="$temporary_root/$hero_gender-$hero_frame-outside-mask.png"
		magick "$blue_png" -alpha off -fuzz 12% -fill black +opaque '#0346AA' -fill white -opaque '#0346AA' "$color_mask"
		magick "$color_mask" "$hair_region_mask" -compose multiply -composite "$hair_mask"
		magick "$blue_png" -alpha extract -threshold 0 "$visible_mask"
		magick "$hair_mask" -negate "$visible_mask" -compose multiply -composite "$outside_mask"

		for hair_color in black brown red; do
			variant_name="sprite-hero-$hero_gender-$hair_color-$hero_frame"
			variant_png="$app_catalog/$variant_name.imageset/$variant_name.png"
			difference="$temporary_root/$hero_gender-$hair_color-$hero_frame-difference.png"
			magick "$blue_png" -alpha off "$variant_png" -alpha off -compose difference -composite -threshold 0 "$difference"
			difference_geometry="$(magick "$difference" -format '%@' info:)"
			difference_size="${difference_geometry%%+*}"
			difference_offset="${difference_geometry#*+}"
			difference_height="${difference_size#*x}"
			difference_y="${difference_offset##*+}"
			outside_max="$(magick "$difference" "$outside_mask" -compose multiply -composite -format '%[fx:maxima]' info:)"
			inside_max="$(magick "$difference" "$hair_mask" -compose multiply -composite -format '%[fx:maxima]' info:)"
			if [[ $outside_max != "0" ]]; then
				echo "hero recoloring changed a non-hair pixel: $variant_name" >&2
				exit 1
			fi
			if [[ $inside_max == "0" ]]; then
				echo "hero recoloring did not change any hair pixels: $variant_name" >&2
				exit 1
			fi
			if ((difference_y + difference_height > 260)); then
				echo "hero recoloring changed pixels below the approved hair region: $variant_name ($difference_geometry)" >&2
				exit 1
			fi
		done
	done
done

if [[ ${QUESTKEEPER_SKIP_GENERATION_CHECK:-0} != 1 ]]; then
	fake_bin="$temporary_root/fake-bin"
	fake_magick="$fake_bin/magick"
	magick_marker="$temporary_root/magick-invoked"
	mkdir -p "$fake_bin"
	printf '%s\n' '#!/bin/bash' ': >"${QUESTKEEPER_MAGICK_MARKER:?}"' 'exit 99' >"$fake_magick"
	chmod +x "$fake_magick"
	if QUESTKEEPER_MAGICK_MARKER="$magick_marker" PATH="$fake_bin:$PATH" /bin/bash "$script_root/process-combat-assets.sh" \
		"$asset_root/docs/assets/pixel-combat-customization/questkeeper-heroes-source.png" \
		"$asset_root/docs/assets/pixel-combat-customization/questkeeper-heroes-source.png" \
		"$temporary_root/rejected" >/dev/null 2>&1; then
		echo "generator accepted an unapproved monster source" >&2
		exit 1
	fi
	if [[ -e $temporary_root/rejected ]]; then
		echo "generator wrote output before rejecting an unapproved source" >&2
		exit 1
	fi
	if [[ -e $magick_marker ]]; then
		echo "generator parsed an unapproved source with ImageMagick" >&2
		exit 1
	fi

	approved_monster_source="$asset_root/docs/assets/pixel-combat-customization/questkeeper-monsters-left-source.png"
	approved_hero_source="$asset_root/docs/assets/pixel-combat-customization/questkeeper-heroes-source.png"
	real_magick="$(command -v magick)"
	monitor_bin="$temporary_root/monitor-bin"
	monitor_magick="$monitor_bin/magick"
	source_marker="$temporary_root/original-source-reopened"
	mkdir -p "$monitor_bin"
	printf '%s\n' \
		'#!/bin/bash' \
		'for argument in "$@"; do' \
		'  if [[ $argument == "$QUESTKEEPER_ORIGINAL_MONSTER" || $argument == "$QUESTKEEPER_ORIGINAL_HERO" ]]; then' \
		'    : >"${QUESTKEEPER_SOURCE_MARKER:?}"' \
		'  fi' \
		'done' \
		'exec "${QUESTKEEPER_REAL_MAGICK:?}" "$@"' >"$monitor_magick"
	chmod +x "$monitor_magick"
	stale_imageset="$temporary_root/first/QuestKeeper/Assets.xcassets/sprite-hero-idle.imageset"
	mkdir -p "$stale_imageset"
	: >"$stale_imageset/sprite-hero-idle.png"
	QUESTKEEPER_ORIGINAL_MONSTER="$approved_monster_source" \
		QUESTKEEPER_ORIGINAL_HERO="$approved_hero_source" \
		QUESTKEEPER_REAL_MAGICK="$real_magick" \
		QUESTKEEPER_SOURCE_MARKER="$source_marker" \
		PATH="$monitor_bin:$PATH" \
		/bin/bash "$script_root/process-combat-assets.sh" \
		"$approved_monster_source" \
		"$approved_hero_source" \
		"$temporary_root/first" >/dev/null
	if [[ -e $source_marker ]]; then
		echo "generator reopened an approved source path after copying it" >&2
		exit 1
	fi
	if [[ -e $stale_imageset ]]; then
		echo "generator retained a stale managed imageset: $stale_imageset" >&2
		exit 1
	fi
	/bin/bash "$script_root/process-combat-assets.sh" \
		"$approved_monster_source" \
		"$approved_hero_source" \
		"$temporary_root/second" >/dev/null
	if ! diff -qr "$temporary_root/first" "$temporary_root/second" >/dev/null; then
		echo "combat asset generation is not byte-identical across runs" >&2
		exit 1
	fi
fi

echo "validated $monster_count monster kinds in app and widget catalogs, plus $hero_count app hero sprites"
