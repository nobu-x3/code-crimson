#import "gltf-parser";
#import "Basic";

Mesh :: struct {
    vertices: [..]Vertex;
    indices: [..]u16;
}

Vertex :: struct {
    pos: [2]float32;
    color: [3]float32;
}

main :: () {
    gltf_data := gltf_parse_file("assets/models/box/Box.gltf");
    defer gltf_free(*gltf_data);
    gltf_load_buffers(*gltf_data);
    vertices : [..] float;
    indices : [..] u16;
    data := gltf_data.meshes[0];
    for primitive: data.primitives {
        using primitive;
        if position_accessor != -1 {
            accessor := gltf_data.accessors[position_accessor];
            read_buffer_from_accessor(*gltf_data, accessor, *vertices);
        }
        if indices_accessor != -1 {
            accessor := gltf_data.accessors[indices_accessor];
            read_buffer_from_accessor(*gltf_data, accessor, *indices);
        }
    }
    mesh := Mesh.{};
    index := 0;
    while (index < vertices.count){
        vertex := Vertex.{
            pos = .[vertices[index], vertices[index + 1]]
        };
        array_add(*mesh.vertices, vertex);
        index += 2;
    }
    print("%\n", indices);
    print("%\n", mesh.vertices);
}
