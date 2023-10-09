
descriptor_set_create :: ($T: Type, image_count: u32, logical_device: VkDevice, physical_device: VkPhysicalDevice, pool: *VkDescriptorPool, stageFlags: VkShaderStageFlags) -> Descriptor_Set, bool #must {
    set : Descriptor_Set;
    res : bool;
    ti := type_info(T);
    assert(ti.type == .STRUCT);
    tis := cast(*Type_Info_Struct)ti;
    entries : [..]VkDescriptorSetLayoutBinding;
    entries.allocator = temp;
    should_create_pool := pool == null;
    sizes : [..]VkDescriptorPoolSize;
    sizes.allocator = temp;
    array_reserve(*entries, tis.members.count);
    for tis.members {
        descriptor_type: VkDescriptorType;
        if !it.notes { 
            log(.ERROR, "Struct % passed into descriptor_set_create. Member % missing type note.", tis.name, it.name);
            return set, false;
        }
        for note:it.notes {
            if note == {
                case "Uniform";
                    descriptor_type = .UNIFORM_BUFFER;
                    if should_create_pool {
                        array_add(*sizes, .{
                            type = .UNIFORM_BUFFER, descriptorCount = image_count * 5
                        });
                    }
                    break;
            }
        }
        binding := VkDescriptorSetLayoutBinding.{
            binding = cast(u32)it_index, 
            stageFlags = stageFlags,
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
    for 0..image_count - 1 {
        buf: Buffer;
        buf, res = buffer_create(logical_device, physical_device, size_of(T), 1, .UNIFORM_BUFFER_BIT, .DEVICE_LOCAL_BIT);
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
            buffer = buf.handle, offset = 0, range = size_of(T)
        };
        set_write := VkWriteDescriptorSet.{
            dstBinding = 0, dstSet = handle, descriptorCount = 1,
            descriptorType = .UNIFORM_BUFFER, pBufferInfo = *buf_info
        };
        vkUpdateDescriptorSets(logical_device, 1, *set_write, 0, null);
        array_add(*set.handles, handle);
        array_add(*set.buffers, buf);
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
