
buffer_create :: (logical_device: VkDevice, physical_device: VkPhysicalDevice, member_size: int, 
                    count: int, usage: VkBufferUsageFlags, mem_props: VkMemoryPropertyFlags) -> Buffer, bool #must {
    buffer := Buffer.{size = cast(VkDeviceSize)(member_size * count), length = count, stride = member_size};
    buffer_ci := VkBufferCreateInfo.{
        size = cast(VkDeviceSize)(member_size * count),
        usage = usage,
        sharingMode = .EXCLUSIVE
    };
    res := vkCreateBuffer(logical_device, *buffer_ci, null, *buffer.handle);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create buffer. %", res);
        return buffer, false;
    }
    mem_reqs : VkMemoryRequirements;
    vkGetBufferMemoryRequirements(logical_device, buffer.handle, *mem_reqs);
    mem_type, query_res := device_find_mem_type(physical_device, mem_reqs.memoryTypeBits, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT);
    if !query_res {
        return buffer, false;
    }
    alloc_info := VkMemoryAllocateInfo.{
        allocationSize = mem_reqs.size,
        memoryTypeIndex = mem_type
    };
    res = vkAllocateMemory(logical_device, *alloc_info, null, *buffer.memory);
    if res != .SUCCESS {
        log(.FATAL, "Failed to allocate buffer memory. %", res);
        return buffer, false;
    }
    vkBindBufferMemory(logical_device, buffer.handle, buffer.memory, 0);
    return buffer, true;
}

buffer_destroy :: (device: VkDevice, buffer: Buffer) {
    vkFreeMemory(device, buffer.memory, null);
    vkDestroyBuffer(device, buffer.handle, null);
}

buffer_copy :: (device: VkDevice, command_pool: VkCommandPool, queue: VkQueue, src: Buffer, dst: Buffer, size: VkDeviceSize) {
    alloc_info := VkCommandBufferAllocateInfo.{
        level = .PRIMARY, commandPool = command_pool, commandBufferCount = 1
    };
    cmd_buffer: VkCommandBuffer;
    vkAllocateCommandBuffers(device, *alloc_info, *cmd_buffer);
    begin_info := VkCommandBufferBeginInfo.{
        flags = .ONE_TIME_SUBMIT_BIT
    };
    vkBeginCommandBuffer(cmd_buffer, *begin_info);
    copy_region := VkBufferCopy.{
        srcOffset = 0, dstOffset = 0, size = size
    };
    vkCmdCopyBuffer(cmd_buffer, src.handle, dst.handle, 1, *copy_region);
    vkEndCommandBuffer(cmd_buffer);
    submit_info := VkSubmitInfo.{
        commandBufferCount = 1, pCommandBuffers = *cmd_buffer
    };
    vkQueueSubmit(queue, 1, *submit_info, null);
    vkQueueWaitIdle(queue);
    vkFreeCommandBuffers(device, command_pool, 1, *cmd_buffer);
}

buffer_create_and_copy :: (logical_device: VkDevice, physical_device: VkPhysicalDevice, usage: VkBufferUsageFlags,
                        command_pool: VkCommandPool, queue: VkQueue, data: []$T) -> Buffer, bool #must {
    out_buffer := Buffer.{
        length = data.count, size = cast(VkDeviceSize)(data.count * size_of(T))
    };
    staging, res := buffer_create(logical_device, physical_device, size_of(T), data.count, .TRANSFER_SRC_BIT, .HOST_VISIBLE_BIT | .HOST_COHERENT_BIT);
    if !res {
        log(.FATAL, "Failed to create buffer because staging buffer creation failed.");
        return out_buffer, false;
    }
    mapped_data : *void;
    vkMapMemory(logical_device, staging.memory, 0, out_buffer.size, 0, *mapped_data);
    memcpy(mapped_data, data.data, cast(int)out_buffer.size);
    vkUnmapMemory(logical_device, staging.memory);
    out_buffer, res = buffer_create(logical_device, physical_device, size_of(T), data.count, .TRANSFER_DST_BIT | usage, .DEVICE_LOCAL_BIT);
    if !res {
        log(.FATAL, "Failed to create buffer after creating a staging buffer.");
        return out_buffer, false;
    }
    buffer_copy(logical_device, command_pool, queue, staging, out_buffer, out_buffer.size);
    vkFreeMemory(logical_device, staging.memory, null);
    vkDestroyBuffer(logical_device, staging.handle, null);
    return out_buffer, true;
}

buffer_write :: (device: VkDevice, buffer: *Buffer, data: []$T) {
    mapped_data : *void;
    vkMapMemory(device, buffer.memory, 0, buffer.size, 0, *mapped_data);
    memcpy(mapped_data, data.data, cast(int)buffer.size);
    vkUnmapMemory(device, buffer.memory);
}
