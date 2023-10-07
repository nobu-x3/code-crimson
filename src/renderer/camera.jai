
Camera :: struct {
    projection : Matrix4 = Matrix4_Identity;
    view_proj : Matrix4 = Matrix4_Identity;
}

camera_create :: (fov: float, aspect: float, near: float, far: float) -> Camera {
    camera := Camera.{projection = make_projection_matrix(fov, aspect, near, far)};
    camera.projection._11 *= -1;
    return camera;
}
