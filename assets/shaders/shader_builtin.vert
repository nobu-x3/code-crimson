#version 450
#extension GL_ARB_separate_shader_objects : enable

layout (location = 0) in vec3 in_position;

layout(push_constant) uniform constants{
    mat4 render_matrix;
} push_constants;

void main () {
	gl_Position = push_constants.render_matrix * vec4 (in_position, 1.0);
}
