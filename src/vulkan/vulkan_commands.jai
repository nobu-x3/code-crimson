command_pool_create :: (device: VkDevice, queue_index: u32) -> VkCommandPool, bool #must {
    command_pool : VkCommandPool;
    pool_ci := VkCommandPoolCreateInfo.{
        flags = .RESET_COMMAND_BUFFER_BIT, queueFamilyIndex = queue_index
    };
    res := vkCreateCommandPool(device, *pool_ci, null, *command_pool);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create command pool. %", res);
        return command_pool, false;
    }
    return command_pool, true;
}

command_buffer_create :: (device: VkDevice, command_pool: VkCommandPool) -> VkCommandBuffer, bool #must {
    buffer : VkCommandBuffer;
    alloc_info := VkCommandBufferAllocateInfo.{commandPool = command_pool, level = .PRIMARY, commandBufferCount = 1}; 
    res := vkAllocateCommandBuffers(device, *alloc_info, *buffer);
    if res != .SUCCESS {
        log(.FATAL, "Failed to allocate command buffer. %", res);
        return buffer, false;
    }
    return buffer, true;
}

command_buffer_destroy :: (device: VkDevice, command_pool: VkCommandPool, buffer: *VkCommandBuffer) {
    vkFreeCommandBuffers(device, command_pool, 1, buffer);
}

command_buffer_begin :: (command_buffer: VkCommandBuffer, using begin_info: Render_Pass_Begin_Info) -> bool #must {
    ci : VkCommandBufferBeginInfo;
    if single_use ci.flags |= .ONE_TIME_SUBMIT_BIT;
    if simultaneous_use ci.flags |= .SIMULTANEOUS_USE_BIT;
    if render_pass_continue ci.flags |= .RENDER_PASS_CONTINUE_BIT;
    res := vkBeginCommandBuffer(command_buffer, *ci);
    if res != .SUCCESS {
        log(.FATAL, "Failed to begin command buffer. %", res);
        return false;
    }
    return true;
}

command_buffer_end :: (command_buffer: VkCommandBuffer) -> bool #must {
    res := vkEndCommandBuffer(command_buffer);
    if res != .SUCCESS {
        log(.FATAL, "Failed to end command buffer. %", res);
        return false;
    }
    return true;
}

create_command_buffers_default :: (using vulkan_context: *Vulkan_Context) {
    for 0..MAX_FRAMES_IN_FLIGHT - 1 {
        if command_buffers[it] != null {
            command_buffer_destroy(device, command_pool, *command_buffers.data[it]);
        }
        res : bool;
        command_buffers[it], res = command_buffer_create(device, command_pool);
        if !res return;
    }
    log(.INFO, "Command buffers created.");
}
