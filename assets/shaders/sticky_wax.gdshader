shader_type canvas_item;


// Because the shape is a circle (stretched to a capsule),
// the corners are guaranteed to be transparent
// This is the color that is clamped to for parts of the waist that are cut out
const vec2 TRANSPARENT_COLOR_POSITION = vec2(0.0, 0.0);

// How much more long than thick the sprite can be before a waist appears
const float WAIST_LENGTH_THICKNESS_RATIO = 3.0;

// How thin the waist can be compared to the thickness
const float WAIST_MINIMUM_RATIO = 0.5;

// The width and height of the scaled sprite
uniform float length = 0.0;
uniform float thickness = 0.0;


float remap(float value, float from_start, float from_end, float to_start, float to_end) {
	return to_start + (value - from_start) / (from_end - from_start) * (to_end - to_start);
}


float waist_thickness_ratio_at(float x) {
	float waist = max(WAIST_LENGTH_THICKNESS_RATIO / (length / thickness), WAIST_MINIMUM_RATIO);
	if (waist > 0.999) {
		return 1.0;
	}

	float cap_ratio = 0.5 / (length / thickness);

	float waist_cut_depth = 1.0 - waist;
	float body_half_length = (length / thickness) - 1.0;
	float waist_cut_radius = (body_half_length * body_half_length + waist_cut_depth * waist_cut_depth) / (2.0 * waist_cut_depth);
	float offset_from_center = remap(x, cap_ratio, 1.0 - cap_ratio, -body_half_length, body_half_length);

	return waist + waist_cut_radius - sqrt(max(waist_cut_radius * waist_cut_radius - offset_from_center * offset_from_center, 0.0));
}


void fragment() {
	vec2 source_uv = UV;

	float cap_ratio = 0.5 / (length / thickness);

	if (UV.x < cap_ratio) {
		// Left Cap
		source_uv.x = remap(UV.x, 0.0, cap_ratio, 0.0, 0.5);
	} else if (UV.x > 1.0 - cap_ratio) {
		// Right Cap
		source_uv.x = remap(UV.x, 1.0 - cap_ratio, 1.0, 0.5, 1.0);
	} else {
		// Stretchable Rectangle
		source_uv.x = 0.5;
		source_uv.y = 0.5 + (UV.y - 0.5) / waist_thickness_ratio_at(UV.x);
		if (source_uv.y < 0.0 || source_uv.y > 1.0) {
			source_uv = TRANSPARENT_COLOR_POSITION;
		}
	}

	COLOR = texture(TEXTURE, source_uv);
}
