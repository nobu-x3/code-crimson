Mesh_Push_Constants :: struct {
    render_matrix: Matrix4;
}

SRT :: struct {
    pos: Vector3;
    rot: Quaternion;
    euler: Vector3;
    scale: Vector3;
}

Transform :: struct {
    matrix: Matrix4 = Matrix4_Identity;
}

Mesh :: struct {
    vertices: [..]Vertex;
    indices: [..]u16;
}

Render_Object :: struct {
    mesh: Mesh;
    material: Material;
    transform: Matrix4;
}

Material :: struct {
    pipeline : Pipeline;
}

// Each member represents a new binding
Global_Descriptor_Set :: struct {
    camera: Camera; @Uniform @Vertex
    backdrop: Backdrop; @UniformDynamic @Vertex @Fragment
}

Object_Storage_Descriptor_Set :: struct {
    render_matrix: Render_Matrix; @Storage @Vertex
}

Render_Matrix :: struct {
    matrix: Matrix4;
}


Backdrop :: struct {
    color: Color;
}

Vertex :: struct {
    pos: [2]float32;
    color: [3]float32;
}

Color :: struct {
    r, g, b, a: float32;
}

Extent2D :: struct {
    x, y, w, h: float32;
}
