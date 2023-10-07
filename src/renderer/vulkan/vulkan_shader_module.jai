
shader_module_create :: (device: VkDevice, code: []u8) -> VkShaderModule, bool #must {
    ci := VkShaderModuleCreateInfo.{codeSize = cast(u64)code.count, pCode = cast(*u32)code.data};
    shader : VkShaderModule;
    res := vkCreateShaderModule(device, *ci, null, *shader);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create shader module.");
        return shader, false;
    }
    log(.INFO, "Shader module created.");
    return shader, true;
}

shader_module_destroy :: (device: VkDevice, shader: VkShaderModule) {
    vkDestroyShaderModule(device, shader, null);
}
