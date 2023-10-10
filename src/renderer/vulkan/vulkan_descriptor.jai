#import "Hash_Table";

descriptor_set_destroy :: (device: VkDevice, set: *Descriptor_Set, pool: *VkDescriptorPool) {
    for set.buffers {
        buffer_destroy(device, it);
    }
    array_free(set.buffers);
    vkDestroyDescriptorSetLayout(device, set.layout, null);
    if pool {
        vkDestroyDescriptorPool(device, pool.*, null);
    }
    array_free(set.handles);
}

// All builders use temp allocator which gets freed at the end of the frame.
// Use this at initialization and cache stuff the procedures return because 
// all the maps get freed and become invalid pretty fast.
// To build all the stuff you may need this for, do the following:
// 1. Initialize.
// 2. Add all your types you wish to create descriptor sets for.
// 3. Create pool.
// 4. Build descriptor set layouts.
// 5. Allocate descriptor sets.
// 6. Create and set up write buffers.
// Personally, I think this pattern is neat even tho it's OOP-ey because Jai's 
// metaprogramming power really makes it easy for the end user.
Descriptor_Set_Builder :: struct {
    device: VkDevice;
    physical_device: VkPhysicalDevice;
    binding_map: Table(string, [..]VkDescriptorSetLayoutBinding);
    layout_map: Table(string, VkDescriptorSetLayout);
    set_map: Table(string, [..]VkDescriptorSet);
    sizes : [..]VkDescriptorPoolSize;
    pool: VkDescriptorPool;
    image_count: u32;
}

descriptor_set_builder_init :: (logical_device: VkDevice, phys_device: VkPhysicalDevice, frame_count: u32) -> Descriptor_Set_Builder {
    using builder: Descriptor_Set_Builder;
    image_count = frame_count;
    device = logical_device;
    physical_device = phys_device;
    binding_map.allocator = temp;
    layout_map.allocator = temp;
    set_map.allocator = temp;
    sizes.allocator = temp;
    table_ensure_space(*binding_map, 4);
    table_ensure_space(*layout_map, 4);
    table_ensure_space(*set_map, 4);
    array_reserve(*sizes, 8);
    return builder;
}

descriptor_set_builder_add_type :: (using builder: *Descriptor_Set_Builder, $T: Type) {
    ti := type_info(T);
    assert(ti.type == .STRUCT, "Can only create descriptor sets from structs.\n");
    tis := cast(*Type_Info_Struct)ti;
    assert(!table_contains(*binding_map, tis.name), "Trying to add duplicate type to descriptor set builder.\n");
    set_bindings : [..]VkDescriptorSetLayoutBinding;
    set_bindings.allocator = temp;
    array_reserve(*set_bindings, 8);
    for tis.members {
        descriptor_type: VkDescriptorType;
        stage_flags : VkShaderStageFlags;
        if !it.notes { 
            log(.ERROR, "Struct % passed into descriptor_set_builder_add_type. Member % missing type note.", tis.name, it.name);
            return;
        }
        for note:it.notes {
            if note == {
                // descriptor types:
                case "Uniform";
                    descriptor_type = .UNIFORM_BUFFER;
                    found := false;
                    for  * size:sizes {
                        if size.type == .UNIFORM_BUFFER {
                            found = true;
                            size.descriptorCount += image_count;
                        }
                    }
                    if !found {
                        array_add(*sizes, .{
                            // @NOTE: not sure if image_count * 5 is good
                            type = .UNIFORM_BUFFER, descriptorCount = image_count * 5 
                        });
                    }
                case "UniformDynamic";
                    descriptor_type = .UNIFORM_BUFFER_DYNAMIC;
                    found := false;
                    for * size:sizes {
                        if size.type == .UNIFORM_BUFFER_DYNAMIC {
                            found = true;
                            size.descriptorCount += image_count;
                        }
                    }
                    if !found {
                        array_add(*sizes, .{
                            // @NOTE: not sure if image_count * 5 is good
                            type = .UNIFORM_BUFFER_DYNAMIC, descriptorCount = image_count * 5 
                        });
                    }
                // shader visibility:
                case "Vertex";
                    stage_flags |= .VERTEX_BIT;
                case "Fragment";
                    stage_flags |= .FRAGMENT_BIT;
            }
        }
        binding := VkDescriptorSetLayoutBinding.{
            binding = cast(u32)it_index, 
            stageFlags = stage_flags,
            descriptorType = descriptor_type,
            descriptorCount = 1,
        };
        array_add(*set_bindings, binding);
    }
    table_add(*binding_map, tis.name, set_bindings);
}

descriptor_set_builder_create_pool :: (using builder: *Descriptor_Set_Builder) -> VkDescriptorPool, bool #must {
    sets : u32 = 0;
    for sizes {
        sets += it.descriptorCount;
    }
    pool_ci := VkDescriptorPoolCreateInfo.{
        maxSets = sets, poolSizeCount = cast(u32)sizes.count,
        pPoolSizes = sizes.data
    };
    res := vkCreateDescriptorPool(device, *pool_ci, null, *pool);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create descriptor pool. %", res);
        return pool, false;
    }
    return pool, true;
}

descriptor_set_builder_build_layout :: (using builder: *Descriptor_Set_Builder, $T: Type) -> VkDescriptorSetLayout, bool #must {
    ti := type_info(T);
    assert(ti.type == .STRUCT, "Can only create descriptor sets from structs.\n");
    tis := cast(*Type_Info_Struct)ti;
    assert(table_contains(*binding_map, tis.name), "Trying to build a layout from type % that was not previously added. Descriptor pool is probably missing something. Please call descriptor_set_builder_add_type before building.\n", tis.name);
    assert(!table_contains(*layout_map, tis.name), "Trying to create duplicate descriptor set layout for type %.\n", tis.name);
    layout : VkDescriptorSetLayout;
    bindings := table_find_pointer(*binding_map, tis.name);
    layout_ci := VkDescriptorSetLayoutCreateInfo.{
        bindingCount = cast(u32)bindings.count, pBindings = bindings.data
    };
    res := vkCreateDescriptorSetLayout(device, *layout_ci, null, *layout);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create descriptor set layout for type %. %", tis.name, res);
        return layout, false;
    }
    table_add(*layout_map, tis.name, layout);
    return layout, true;
}

descriptor_set_builder_build_set :: (using builder: *Descriptor_Set_Builder, $T: Type) -> [..]VkDescriptorSet, bool #must {
    ti := type_info(T);
    assert(ti.type == .STRUCT, "Can only create descriptor sets from structs.\n");
    tis := cast(*Type_Info_Struct)ti;
    assert(table_contains(*layout_map, tis.name), "Trying to build a layout from a type that was not previously added. Descriptor pool is probably missing something. Please call descriptor_set_builder_add_type before building.\n");
    if(table_contains(*set_map, tis.name)) {
        sets, res := table_find(*set_map, tis.name);
        return sets, res;
    }
    sets : [..]VkDescriptorSet;
    array_resize(*sets, image_count);
    for 0..image_count {
        set : VkDescriptorSet;
        alloc_info := VkDescriptorSetAllocateInfo.{
            descriptorPool = pool, descriptorSetCount = 1, pSetLayouts = table_find_pointer(*layout_map, tis.name)
        };
        res := vkAllocateDescriptorSets(device, *alloc_info, *set);
        if res != .SUCCESS {
            log(.FATAL, "Failed to create descriptor set for type %. %", tis.name, res);
            return sets, false;
        }
        array_add(*sets, set);
    }
    table_add(*set_map, tis.name, sets);
    return set, true;
}

descriptor_set_builder_create_buffer :: (using builder: *Descriptor_Set_Builder, $set: Type, $member: Type) -> [..]Buffer, bool #must 
// #modify { 
//     // For reference, the return type of this proc would be $R, bool #must
//     // This is actually crazy -- allows me to decide what to return based on notes. Kinda makes the function unreadable
//     // because there are too many #ifs, so decided not to do this. Was a good excercise tho.
//     ti_set := cast(*Type_Info)set;
//     ti_member := cast(*Type_Info)member;
//     if ti_set.type != .STRUCT || ti_member.type != .STRUCT {
//         print("Can only create descriptor set buffers from structs.\n");
//         return false;
//     }
//     tis_set := cast(*Type_Info_Struct)ti_set;
//     tis_member := cast(*Type_Info_Struct)ti_member;
//     for tis_set.members {
//         if it.type == ti_member {
//             if it.notes.count <= 0{ 
//                 print("% is not annotated inside %.\n", tis_member.name, tis_set.name);
//                 return false;
//             }
//             for note: it.notes {
//                 if note == {
//                     case "Uniform";
//                         R = [..]Buffer;
//                         return true;
//                     case "UniformDynamic";
//                         R = Buffer;
//                         return true;
//                 }
//             }
//         }
//     }
//     print("% does not contain annotated %.\n", tis_set.name, tis_member.name);
//     return false;
// }

{
    ti_set := type_info(set);
    ti_member := type_info(member);
    tis_set := cast(*Type_Info_Struct)ti_set;
    tis_member := cast(*Type_Info_Struct)ti_member;
    buffers : [..]Buffer;
    found := false;
    for tis_set.members {
        if it.type == ti_member {
            found = true;
            for note: it.notes {
                if note == {
                    case "Uniform";
                        assert(buffers.count == 0, "There should only be one type annotation per member.\n");
                        sets := table_find_pointer(*set_map, tis_set.name);
                        for frame: 0..image_count - 1 {
                            // @TODO: figure out padding stuff
                            buf, res := buffer_create(device, physical_device, ti_member.runtime_size, 1, .UNIFORM_BUFFER_BIT, .DEVICE_LOCAL_BIT);
                            if !res {
                                log(.FATAL, "Failed to create buffer for type % when creating descriptor set.", tis_member.name);
                                return buffers, false; 
                            }
                            buf_info := VkDescriptorBufferInfo.{
                                buffer = buf.handle, offset = 0, range = cast(u64)ti_member.runtime_size
                            };
                            set_write := VkWriteDescriptorSet.{
                                dstBinding = cast(u32)it_index, dstSet = set.*, descriptorCount = 1,
                                descriptorType = .UNIFORM_BUFFER, pBufferInfo = *buf_info
                            };
                            vkUpdateDescriptorSets(device, 1, *set_write, 0, null);
                            array_add(*buffers, buf);
                        }
                    case "UniformDynamic";
                        assert(buffers.count == 0, "There should only be one type annotation per member.\n");
                        buf, res := buffer_create(device, physical_device, ti_member.runtime_size * image_count, 1, .UNIFORM_BUFFER_BIT, .DEVICE_LOCAL_BIT);
                        if !res {
                            log(.FATAL, "Failed to create buffer for type % when creating descriptor set.", tis_member.name);
                            return buffers, false; 
                        }
                        array_add(*buffers, buf);
                        set := table_find_pointer(*set_map, tis_set.name);
                        buf_info := VkDescriptorBufferInfo.{
                            buffer = buf.handle, offset = 0, range = cast(u64)ti_member.runtime_size
                        };
                        set_write := VkWriteDescriptorSet.{
                            dstBinding = cast(u32)it_index, dstSet = set.*, descriptorCount = 1,
                            descriptorType = .UNIFORM_BUFFER, pBufferInfo = *buf_info
                        };
                        vkUpdateDescriptorSets(device, 1, *set_write, 0, null);
                        array_add(*buffers, buf);
                }
            }
        }
    }
    return buffers, true;
}
