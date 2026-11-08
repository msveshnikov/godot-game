extends StaticBody3D

const HAIR_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 strand_color : source_color;
uniform float strand_roughness : hint_range(0.0, 1.0);
uniform float strand_metallic : hint_range(0.0, 1.0);
uniform float strand_phase;
uniform float wind_strength = 1.0;
uniform vec3 root_anchor = vec3(0.0);

void vertex() {
	float distance_from_root = length(VERTEX - root_anchor);
	float along_strand = clamp(distance_from_root / 1.35, 0.0, 1.0);
	float root_falloff = smoothstep(0.12, 0.58, distance_from_root);
	float primary_wave = sin(TIME * 1.7 + strand_phase + along_strand * 4.6);
	float secondary_wave = sin(TIME * 2.6 + strand_phase * 1.73 + along_strand * 7.1);
	float flutter = cos(TIME * 1.25 + strand_phase * 0.81 + along_strand * 3.4);
	float strength = wind_strength * root_falloff;

	VERTEX.x += (primary_wave * 0.16 + secondary_wave * 0.045) * strength;
	VERTEX.y += (primary_wave * 0.035 + flutter * 0.018) * strength;
	VERTEX.z += (flutter * 0.10 + secondary_wave * 0.035) * strength;
}

void fragment() {
	ALBEDO = strand_color.rgb;
	ROUGHNESS = strand_roughness;
	METALLIC = strand_metallic;
}
"""

const MOVING_HAIR_PARTS := [
	"hair filament",
	"lower curl",
	"luminous strand",
	"outer wave",
	"flowing lower curl",
	"swept fringe",
]


func _ready() -> void:
	var model := get_node_or_null("Model")
	if model == null:
		push_error("Mermaid villager is missing its imported model.")
		return

	var shader := Shader.new()
	shader.code = HAIR_SHADER
	var animated_strands := 0

	for node in model.find_children("*", "MeshInstance3D", true, false):
		var hair_mesh := node as MeshInstance3D
		var part_name := String(hair_mesh.name).to_lower()
		if not _is_moving_hair_part(part_name):
			continue

		var base_material := hair_mesh.get_active_material(0) as BaseMaterial3D
		if base_material == null:
			push_error("Mermaid hair strand has no compatible base material: %s" % hair_mesh.name)
			continue

		var strand_material := ShaderMaterial.new()
		strand_material.shader = shader
		strand_material.set_shader_parameter("strand_color", base_material.albedo_color)
		strand_material.set_shader_parameter("strand_roughness", base_material.roughness)
		strand_material.set_shader_parameter("strand_metallic", base_material.metallic)
		strand_material.set_shader_parameter("strand_phase", float(part_name.hash() % 1000) / 1000.0 * TAU)
		strand_material.set_shader_parameter("wind_strength", _wind_strength_for(part_name))
		hair_mesh.material_override = strand_material
		animated_strands += 1

	if animated_strands == 0:
		push_error("No loose mermaid hair strands were found to animate.")


func _is_moving_hair_part(part_name: String) -> bool:
	for part in MOVING_HAIR_PARTS:
		if part in part_name:
			return true
	return false


func _wind_strength_for(part_name: String) -> float:
	if "outer wave" in part_name:
		return 1.35
	if "lower curl" in part_name:
		return 1.25
	if "filament" in part_name:
		return 1.15
	if "fringe" in part_name:
		return 0.85
	return 0.72
