#version 450

layout(location = 0) out vec4 out_colour;

layout(set = 0, binding = 1) uniform Backdrop {
    vec4 color;
} backdrop;

void main() {
    out_colour = backdrop.color;
}
