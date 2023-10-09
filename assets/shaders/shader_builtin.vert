#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (location = 0) in vec3 in_position;

layout(push_constant) uniform constants{
    mat4 render_matrix;
} push_constants;

layout(set = 0, binding = 0) uniform  CameraBuffer{
	mat4 proj;
	mat4 viewproj;
} cameraData;

void main () {
    mat4 transformMatrix = (push_constants.render_matrix * cameraData.viewproj);
	gl_Position = transformMatrix * vec4 (in_position, 1.0);
}
