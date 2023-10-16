#version 460
#extension GL_ARB_separate_shader_objects : enable

layout (location = 0) in vec3 in_position;

layout(push_constant) uniform constants{
    mat4 render_matrix;
} push_constants;

layout(set = 0, binding = 0) uniform  CameraBuffer{
	mat4 proj;
	mat4 viewproj;
} cameraData;

struct ObjectData{
	mat4 model;
};

//all object matrices
layout(std140,set = 1, binding = 0) readonly buffer ObjectBuffer{
	ObjectData objects[];
} objectBuffer;


void main () {
    mat4 modelMatrix = objectBuffer.objects[gl_BaseInstance].model;
    //mat4 modelMatrix = push_constants.render_matrix;
    mat4 transformMatrix = (modelMatrix * cameraData.viewproj);
	gl_Position = transformMatrix * vec4 (in_position, 1.0);
}
