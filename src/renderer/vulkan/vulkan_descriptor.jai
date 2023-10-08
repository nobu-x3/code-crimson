
descriptor_set_create :: ($T: Type, image_count: u32, logical_device: VkDevice, physical_device: VkPhysicalDevice, stageFlags: VkShaderStageFlags) -> Descriptor_Set, bool #must {
    set : Descriptor_Set;
    res : bool;
    ti := type_info(T);
    assert(ti.type == .STRUCT);
    tis := cast(*Type_Info_Struct)ti;
    entries : [..]VkDescriptorSetLayoutBinding;
    entries.allocator = temp;
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
    set_ci := VkDescriptorSetLayoutCreateInfo.{
        bindingCount = cast(u32)entries.count, pBindings = entries.data
    };
    vkCreateDescriptorSetLayout(logical_device, *set_ci, null, *set.layout);
    array_reserve(*set.buffers, image_count);
    for 0..image_count - 1 {
        buf: Buffer;
        buf, res = buffer_create(logical_device, physical_device, size_of(T), 1, .UNIFORM_BUFFER_BIT, .DEVICE_LOCAL_BIT);
        if !res {
            log(.FATAL, "Failed to create buffer for type % when creating descriptor set.", T);
            return set, false; 
        }
        array_add(*set.buffers, buf);
    }
    return set, true;
}
