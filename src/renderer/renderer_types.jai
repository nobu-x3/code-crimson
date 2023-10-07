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
