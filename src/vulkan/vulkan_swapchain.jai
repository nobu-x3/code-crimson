// Sometimes swapchain.support is already queried.
swapchain_create :: (using vulkan_context: *Vulkan_Context, query_swapchain_support: bool = false, width: u32 = 0, height: u32 = 0) -> bool {
    if query_swapchain_support {
        swapchain.support = device_query_swapchain_details(vulkan_context, physical_device);
    }
    swapchain.format = choose_surface_format(swapchain.support);
    if swapchain.format.format == VkFormat.UNDEFINED return false;
    swapchain.depth_format = choose_depth_format(vulkan_context);
    swapchain.present_mode = choose_present_mode(swapchain.support);
    if width == 0 || height == 0 {
        swapchain.extent = choose_swap_extent(vulkan_context, swapchain.support);
    }
    swapchain.image_count = swapchain.support.capabilities.minImageCount + 1;
    if swapchain.support.capabilities.maxImageCount > 0 &&
        swapchain.image_count > swapchain.support.capabilities.maxImageCount {
            swapchain.image_count = swapchain.support.capabilities.maxImageCount;
    }
    swapchain.image_count = ifx swapchain.image_count > MAX_FRAMES_IN_FLIGHT 
                            then MAX_FRAMES_IN_FLIGHT
                            else swapchain.image_count;
    swapchain.max_frames_in_flight = swapchain.image_count - 1;
    return true;
}

choose_surface_format :: (using desc: Swapchain_Description) -> VkSurfaceFormatKHR {
    for formats {
        if it.format == .B8G8R8A8_SRGB && it.colorSpace == .COLORSPACE_SRGB_NONLINEAR_KHR return it;
    }
    return formats[0];
}

choose_depth_format :: (using vulkan_context: *Vulkan_Context) -> VkFormat {
    priorities := VkFormat.[.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT];
    flags := VkFormatFeatureFlags.DEPTH_STENCIL_ATTACHMENT_BIT;
    for 0..2 {
        props: VkFormatProperties2KHR;
        vkGetPhysicalDeviceFormatProperties2(physical_device, priorities[it], *props);
        if props.formatProperties.linearTilingFeatures & flags || props.formatProperties.optimalTilingFeatures & flags {
            return priorities[it];
        }
    }
    log(.FATAL, "Failed to identify depth format.");
    return VkFormat.UNDEFINED;
}

choose_present_mode :: (using desc: Swapchain_Description) -> VkPresentModeKHR {
    for present_modes {
        if it == .MAILBOX_KHR return it;
    }
    return .FIFO_KHR;
}

choose_swap_extent :: (vulkan_context: *Vulkan_Context, desc: Swapchain_Description) -> VkExtent2D {
    if desc.capabilities.currentExtent.width != 4_294_967_295 {
        return desc.capabilities.currentExtent;
    }
    x, y, width, height, success := get_dimensions(vulkan_context.window, false);
    extent : VkExtent2D = .{ width = clamp(cast(u32)width, 
                                            desc.capabilities.minImageExtent.width, 
                                            desc.capabilities.maxImageExtent.width), 
                            height = clamp(cast(u32)height,
                                            desc.capabilities.minImageExtent.height,
                                            desc.capabilities.maxImageExtent.height)};
    return extent;
}

MAX_FRAMES_IN_FLIGHT :: 2;

