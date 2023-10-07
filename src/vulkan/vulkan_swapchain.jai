// Sometimes swapchain.support is already queried.
swapchain_create :: (using vulkan_context: *Vulkan_Context, out_swapchain: *Swapchain, query_swapchain_support: bool = false, width: u32 = 0, height: u32 = 0) -> bool {
    if query_swapchain_support {
        out_swapchain.support = device_query_swapchain_details(vulkan_context, physical_device);
    }
    out_swapchain.format = choose_surface_format(out_swapchain.support);
    if out_swapchain.format.format == VkFormat.UNDEFINED return false;
    out_swapchain.depth_format = choose_depth_format(vulkan_context);
    out_swapchain.present_mode = choose_present_mode(out_swapchain.support);
    if width == 0 || height == 0 {
        out_swapchain.extent = choose_swap_extent(vulkan_context, out_swapchain.support);
    }
    out_swapchain.image_count = out_swapchain.support.capabilities.minImageCount + 1;
    if out_swapchain.support.capabilities.maxImageCount > 0 &&
        out_swapchain.image_count > out_swapchain.support.capabilities.maxImageCount {
            out_swapchain.image_count = out_swapchain.support.capabilities.maxImageCount;
    }
    out_swapchain.image_count = ifx out_swapchain.image_count > MAX_FRAMES_IN_FLIGHT 
                            then MAX_FRAMES_IN_FLIGHT
                            else out_swapchain.image_count;
    out_swapchain.max_frames_in_flight = out_swapchain.image_count - 1;
    swapchain_ci := VkSwapchainCreateInfoKHR.{
                                                surface = surface, minImageCount = out_swapchain.image_count, 
                                                imageFormat = out_swapchain.format.format, 
                                                imageColorSpace = out_swapchain.format.colorSpace, 
                                                imageExtent = out_swapchain.extent, imageArrayLayers = 1, 
                                                imageUsage = .COLOR_ATTACHMENT_BIT, 
                                                preTransform = out_swapchain.support.capabilities.currentTransform, 
                                                compositeAlpha = .OPAQUE_BIT_KHR, presentMode = out_swapchain.present_mode,
                                                clipped = 1
                                            };
    q_fam_indices := u32.[cast(u32)queue_indices[Queue_Family.GRAPHICS], cast(u32)queue_indices[Queue_Family.PRESENT]];
    if queue_indices[Queue_Family.GRAPHICS] != queue_indices[Queue_Family.PRESENT] {
        swapchain_ci.imageSharingMode = .CONCURRENT;
        swapchain_ci.queueFamilyIndexCount = 2;
        swapchain_ci.pQueueFamilyIndices = q_fam_indices.data;
    } else {
        swapchain_ci.imageSharingMode = .EXCLUSIVE;
        swapchain_ci.queueFamilyIndexCount = 0;
        swapchain_ci.pQueueFamilyIndices = null;
    }
    res := vkCreateSwapchainKHR(device, *swapchain_ci, null, *out_swapchain.handle);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create swapchain. %", res);
        return false;
    }
    log(.INFO, "Vulkan swapchain successfully created.");
    curr_frame = 0;
    swapchain.image_count = 0;
    vkGetSwapchainImagesKHR(device, swapchain.handle, *out_swapchain.image_count, null);
    array_reserve(*out_swapchain.images, out_swapchain.image_count);
    vkGetSwapchainImagesKHR(device, out_swapchain.handle, *out_swapchain.image_count, out_swapchain.images.data);
    out_swapchain.images.count = out_swapchain.image_count;
    log(.INFO, "Swapchain images received: %", out_swapchain.image_count);
    array_reserve(*out_swapchain.views, out_swapchain.image_count);
    for 0..out_swapchain.image_count - 1 {
        view_ci := VkImageViewCreateInfo.{
                                            viewType = ._2D, image = swapchain.images[it],
                                            format = swapchain.format.format, 
                                            subresourceRange = VkImageSubresourceRange.{
                                                baseMipLevel = 0, levelCount = 1, 
                                                baseArrayLayer = 0, layerCount = 1,
                                                aspectMask = .COLOR_BIT
                                            }
                                        };
        res = vkCreateImageView(device, *view_ci, null, *out_swapchain.views.data[it]);
        out_swapchain.views.count += 1;
        if res != .SUCCESS {
            log(.FATAL, "Failed to create image view number %. %", it, res);
            return false;
        }
    }
    log(.INFO, "Swapchain image views created.");
    out_swapchain.support.depth_format = choose_depth_format(vulkan_context);
    out_swapchain.depth_format = out_swapchain.support.depth_format;
    image_info := Image_Info.
                            {
                                width = out_swapchain.extent.width, height = out_swapchain.extent.height, 
                                format = out_swapchain.depth_format, tiling = .OPTIMAL,
                                usage_flags = .DEPTH_STENCIL_ATTACHMENT_BIT,
                                memory_flags = .DEVICE_LOCAL_BIT, create_view = true,
                                view_aspect_flags = .DEPTH_BIT
                            };
    depth_res : bool;
    out_swapchain.depth_attachment, depth_res = image_create(vulkan_context, *image_info);
    log(.INFO, "Depth attachment created.");
    if !depth_res {
        return false;
    }
    return true;
}

swapchain_cleanup :: (using vulkan_context: *Vulkan_Context) {
    for swapchain.framebuffers {
        vkDestroyFramebuffer(device, it.handle, null);
    }
    for swapchain.views {
        vkDestroyImageView(device, it, null);
    }
    vkDestroySwapchainKHR(device, swapchain.handle, null);
}

swapchain_recreate :: (using vulkan_context: *Vulkan_Context) -> bool {
    x, y, width, height, success := get_dimensions(vulkan_context.window, false);
    if !success {
        log(.FATAL, "Failed to acquire window dimensions.");
        return false;
    }
    if width == 0 && height == 0 {
        update_window_events();
        x, y, width, height, success := get_dimensions(vulkan_context.window, false);
    }
    vkDeviceWaitIdle(device);
    swapchain_cleanup(vulkan_context);
    swapchain_create(vulkan_context, *swapchain);
    res := create_image_views_default(vulkan_context);
    if !res {
        return false;
    }
    recreate_framebuffers(device, *swapchain, main_render_pass);
    return true;
}

swapchain_acquire_next_image_index :: (vulkan_context: *Vulkan_Context, semaphore: VkSemaphore, fence: VkFence, timeout_ns: u64) -> u32, bool #must {
    res := vkAcquireNextImageKHR(vulkan_context.device, vulkan_context.swapchain.handle, timeout_ns, semaphore, fence, *vulkan_context.image_index);
    if res == .ERROR_OUT_OF_DATE_KHR || res == .SUBOPTIMAL_KHR {
        swapchain_recreate(vulkan_context);
    } else if (res != .SUCCESS) {
        log(.FATAL, "Failed to acquire the next image index. %", res);
        return vulkan_context.image_index, false;
    }
    return vulkan_context.image_index, true;
}

swapchain_present :: (vulkan_context: *Vulkan_Context, queue: VkQueue, render_complete_semaphore: *VkSemaphore, present_image_index: *u32) {
    present_info := VkPresentInfoKHR.
        {
            swapchainCount = 1, pSwapchains = *vulkan_context.swapchain.handle,
            waitSemaphoreCount = 1, pWaitSemaphores = render_complete_semaphore,
            pImageIndices = present_image_index
        };
    res := vkQueuePresentKHR(queue, *present_info);
    if res == .ERROR_OUT_OF_DATE_KHR || res == .SUBOPTIMAL_KHR {
        swapchain_recreate(vulkan_context);
    } else if res != .SUCCESS {
        log(.ERROR, "Failed to present swapchain image.");
    }
    vulkan_context.curr_frame = (vulkan_context.curr_frame + 1) % MAX_FRAMES_IN_FLIGHT;
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
