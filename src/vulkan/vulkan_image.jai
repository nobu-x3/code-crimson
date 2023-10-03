image_create :: (vulkan_context: *Vulkan_Context, using image_info: *Image_Info) -> Image, bool #must {
    image := Image.{width = width, height = height};
    image_ci := VkImageCreateInfo.{ 
        imageType = ._2D, extent = VkExtent3D.{width = width, height = height, depth = 1},
        mipLevels = 4, arrayLayers = 1, format = format, tiling = tiling, initialLayout = .UNDEFINED,
        usage = usage_flags, samples = ._1_BIT, sharingMode = .EXCLUSIVE
    };
    res := vkCreateImage(vulkan_context.device, *image_ci, null, *image.handle);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create image.");
        return image, false;
    }
    mem_reqs : VkMemoryRequirements;
    vkGetImageMemoryRequirements(vulkan_context.device, image.handle, *mem_reqs);
    mem_type := device_find_mem_index(vulkan_context, mem_reqs.memoryTypeBits, memory_flags);
    if mem_type == -1 {
        log(.FATAL, "Failed to find required memory type to create an image.");
        return image, false;
    }
    mem_alloc_info := VkMemoryAllocateInfo.{allocationSize = mem_reqs.size, memoryTypeIndex = cast(u32)mem_type};
    res = vkAllocateMemory(vulkan_context.device, *mem_alloc_info, null, *image.memory);
    if res != .SUCCESS {
        log(.FATAL, "Failed to allocate memory for image.");
        return image, false;
    }
    res = vkBindImageMemory(vulkan_context.device, image.handle, image.memory, 0);
    if res != .SUCCESS {
        log(.FATAL, "Failed to bind image memory after creation.");
        return image, false;
    }
    if create_view {
        view_success : bool;
        image.view, view_success = image_view_create(vulkan_context, format, view_aspect_flags, *image);
        if !view_success {
            return image, false;
        }
    }
    return image, true;
}

image_destroy :: (vulkan_context: *Vulkan_Context, using image: *Image) {
    if view != null {
        vkDestroyImageView(vulkan_context.device, view, null);
        view = null;
    }
    if memory != null {
        vkFreeMemory(vulkan_context.device, memory, null);
        memory = null;
    }
    if handle != null {
        vkDestroyImage(vulkan_context.device, handle, null);
        handle = null;
    }
}

image_view_create :: (vulkan_context: *Vulkan_Context, format: VkFormat, aspect_flags: VkImageAspectFlags, image: *Image) -> VkImageView, bool #must {
    image_view : VkImageView;
    view_ci := VkImageViewCreateInfo.
                                    {
                                        viewType = ._2D, image = image.handle,
                                        format = format, 
                                        subresourceRange = VkImageSubresourceRange.
                                        {
                                            baseMipLevel = 0, levelCount = 1, 
                                            baseArrayLayer = 0, layerCount = 1,
                                            aspectMask = aspect_flags
                                        }
                                    };
    res := vkCreateImageView(vulkan_context.device, *view_ci, null, *image_view);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create image view.");
        return image_view, false;
    }
    return image_view, true;
}

create_image_views_default :: (using vulkan_context: *Vulkan_Context) -> bool {
    using vulkan_context.swapchain;
    array_reserve(*views, images.count);
    for images {
        view_ci := VkImageViewCreateInfo.
                                    {
                                        viewType = ._2D, image = it,
                                        format = format.format, 
                                        subresourceRange = VkImageSubresourceRange.
                                        {
                                            baseMipLevel = 0, levelCount = 1, 
                                            baseArrayLayer = 0, layerCount = 1,
                                            aspectMask = .COLOR_BIT
                                        },
                                        components = VkComponentMapping.
                                        {
                                            r = .IDENTITY,
                                            g = .IDENTITY,
                                            b = .IDENTITY,
                                            a = .IDENTITY
                                        }
                                    };
        res := vkCreateImageView(device, *view_ci, null, *views.data[it_index]);
        if res != .SUCCESS {
            log(.FATAL, "Failed to create default image views.");
            return false;
        }
    }
    return true;
}