#import "Hash_Table";

descriptor_set_create :: ($T: Type, image_count: u32, logical_device: VkDevice, physical_device: VkPhysicalDevice, pool: *VkDescriptorPool) -> Descriptor_Set, bool #must {
    set : Descriptor_Set;
    res : bool;
    ti := type_info(T);
    assert(ti.type == .STRUCT, "Can only create descriptor sets from structs.\n");
    tis := cast(*Type_Info_Struct)ti;
    entries : [..]VkDescriptorSetLayoutBinding;
    entries.allocator = temp;
    should_create_pool := pool == null;
    sizes : [..]VkDescriptorPoolSize;
    sizes.allocator = temp;
    array_reserve(*entries, tis.members.count);
    for tis.members {
        descriptor_type: VkDescriptorType;
        stage_flags : VkShaderStageFlags;
        if !it.notes { 
            log(.ERROR, "Struct % passed into descriptor_set_create. Member % missing type note.", tis.name, it.name);
            return set, false;
        }
        for note:it.notes {
            if note == {
                // descriptor types:
                case "Uniform";
                    descriptor_type = .UNIFORM_BUFFER;
                    if should_create_pool {
                        array_add(*sizes, .{
                            // @NOTE: not sure if image_count * 5 is good
                            type = .UNIFORM_BUFFER, descriptorCount = image_count * 5 
                        });
                    }
                case "UniformDynamic";
                    descriptor_type = .UNIFORM_BUFFER_DYNAMIC;
                    if should_create_pool {
                        array_add(*sizes, .{
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
        array_add(*entries, binding);
    }
    if should_create_pool {
        sets : u32 = 0;
        for sizes {
            sets += it.descriptorCount;
        }
        pool_ci := VkDescriptorPoolCreateInfo.{
            maxSets = sets, poolSizeCount = cast(u32)sizes.count,
            pPoolSizes = sizes.data
        };
        vkCreateDescriptorPool(logical_device, *pool_ci, null, *set.pool);
    } else set.pool = pool.*;
    set_ci := VkDescriptorSetLayoutCreateInfo.{
        bindingCount = cast(u32)entries.count, pBindings = entries.data
    };
    vkCreateDescriptorSetLayout(logical_device, *set_ci, null, *set.layout);
    array_reserve(*set.buffers, image_count);
    array_reserve(*set.handles, image_count);
    // @TODO: make this meta'd. We're hardcoding uniform buffer for now.
    for member:tis.members {
        for note:member.notes {
            if note == {
                case "Uniform";
                    for image:0..image_count - 1 {
                        buf: Buffer;
                        buf, res = buffer_create(logical_device, physical_device, member.type.runtime_size, 1, .UNIFORM_BUFFER_BIT, .DEVICE_LOCAL_BIT);
                        if !res {
                            log(.FATAL, "Failed to create buffer for type % when creating descriptor set.", T);
                            return set, false; 
                        }
                        alloc_info := VkDescriptorSetAllocateInfo.{
                            descriptorPool = set.pool, descriptorSetCount = 1, pSetLayouts = *set.layout
                        };
                        handle : VkDescriptorSet;
                        vkAllocateDescriptorSets(logical_device, *alloc_info, *handle);
                        buf_info := VkDescriptorBufferInfo.{
                            buffer = buf.handle, offset = 0, range = cast(u64)member.type.runtime_size
                        };
                        set_write := VkWriteDescriptorSet.{
                            dstBinding = 0, dstSet = handle, descriptorCount = 1,
                            descriptorType = .UNIFORM_BUFFER, pBufferInfo = *buf_info
                        };
                        vkUpdateDescriptorSets(logical_device, 1, *set_write, 0, null);
                        array_add(*set.handles, handle);
                        array_add(*set.buffers, buf);
                    }
            }
        }
    }
    return set, true;
}

descriptor_set_destroy :: (device: VkDevice, set: *Descriptor_Set, should_destroy_pool : bool) {
    for set.buffers {
        buffer_destroy(device, it);
    }
    array_free(set.buffers);
    vkDestroyDescriptorSetLayout(device, set.layout, null);
    if should_destroy_pool vkDestroyDescriptorPool(device, set.pool, null);
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
    sizes : [..]VkDescriptorPoolSize;
    pool: VkDescriptorPool;
}

descriptor_set_builder_init :: (logical_device: VkDevice, phys_device: VkPhysicalDevice) -> Descriptor_Set_Builder {
    using builder: Descriptor_Set_Builder;
    device = logical_device;
    physical_device = phys_device;
    binding_map.allocator = temp;
    layout_map.allocator = temp;
    sizes.allocator = temp;
    table_ensure_space(*binding_map, 4);
    table_ensure_space(*layout_map, 4);
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
            return set, false;
        }
        for note:it.notes {
            if note == {
                // descriptor types:
                case "Uniform";
                    descriptor_type = .UNIFORM_BUFFER;
                    found := false;
                    for size:*sizes {
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
                    for size:*sizes {
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
    if !res {
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

descriptor_set_builder_build_set :: (using builder: *Descriptor_Set_Builder, $T: Type) -> VkDescriptorSet, bool #must {
    ti := type_info(T);
    assert(ti.type == .STRUCT, "Can only create descriptor sets from structs.\n");
    tis := cast(*Type_Info_Struct)ti;
    assert(table_contains(*layout_map, tis.name), "Trying to build a layout from a type that was not previously added. Descriptor pool is probably missing something. Please call descriptor_set_builder_add_type before building.\n");
    set : VkDescriptorSet;
    alloc_info := VkDescriptorSetAllocateInfo.{
        descriptorPool = pool, descriptorSetCount = 1, pSetLayouts = table_find_pointer(layout_map, tis.name)
    };
    res := vkAllocateDescriptorSets(device, *alloc_info, *set);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create descriptor set for type %. %", tis.name, res);
        return set, false;
    }
    return set, true;
}

descriptor_set_builder_create_buffer :: (using builder: *Descriptor_Set_Builder, frames_count: u32, $set: Type, $member: Type) -> [..]Buffer, bool #must {
    ti_set := type_info(set);
    ti_member := type_info(member);
    assert(ti_set.type == .STRUCT && ti_member.type == .STRUCT, "Can only create descriptor set buffers from structs.\n");
    tis_set := cast(*Type_Info_Struct)ti_set;
    tis_member := cast(*Type_Info_Struct)ti_member;
    buffers : [..]Buffer;
    found := false;
    for tis_set.members {
        assert(it.notes, "All members of struct % must be annotated with notes.\n", tis_set.name);
        if it.name == tis_member.name {
            found = true;
            for note: it.notes {
                if note == {
                    case "Uniform";
                        assert(buffers.count == 0, "There should only be one type annotation per member.\n");
                        for frame: 0..frames_count - 1 {
                            // @TODO: figure out padding stuff
                            buf, res := buffer_create(logical_device, physical_device, tis_member.type.runtime_size, 1, .UNIFORM_BUFFER_BIT, .DEVICE_LOCAL_BIT);
                            if !res {
                                log(.FATAL, "Failed to create buffer for type % when creating descriptor set.", T);
                                return buffers, false; 
                            }
                            array_add(*buffers, buf);
                        }
                    case "UniformDynamic";
                        assert(buffers.count == 0, "There should only be one type annotation per member.\n");
                        buf, res := buffer_create(logical_device, physical_device, tis_member.type.runtime_size * frames_count, 1, .UNIFORM_BUFFER_BIT, .DEVICE_LOCAL_BIT);
                        if !res {
                            log(.FATAL, "Failed to create buffer for type % when creating descriptor set.", T);
                            return buffers, false; 
                        }
                        array_add(*buffers, buf);
                }
            }
        }
    }
    assert(found, "$set (%) must contain $member (%)", tis_set.name, tis_member.name);
    return buffers, true;
}
