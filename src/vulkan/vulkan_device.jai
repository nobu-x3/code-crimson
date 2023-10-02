#import "Hash_Table";

vulkan_device_create :: (vulkan_context: *Vulkan_Context) -> bool #must {
    res := get_suitable_physical_device(vulkan_context);
    if !res {
        log(.FATAL, "Failed to get a suitable physical device.");
    }
    find_queue_families(vulkan_context);
    log(.DEBUG, "Queue indices:");
    for vulkan_context.queue_indices {
        log(.DEBUG, "% - %", it_index, it);
    }
    unique_indices : Table(int, bool);
    unique_indices.allocator = temp;
    for vulkan_context.queue_indices table_set(*unique_indices, it, true);
    q_prio := 1.0;
    q_cis : [..]VkDeviceQueueCreateInfo;
    q_cis.allocator = temp;
    for unique_indices {
        q_ci : VkDeviceQueueCreateInfo;
        q_ci.queueFamilyIndex = cast(u32)vulkan_context.queue_indices[Queue_Family.GRAPHICS];
        q_ci.queueCount = 1;
        q_ci.pQueuePriorities = *q_prio;
        array_add(*q_cis, q_ci);
    }
    device_features : VkPhysicalDeviceFeatures;
    device_ci : VkDeviceCreateInfo;
    device_ci.enabledExtensionCount = 1;
    // @TODO: fix this, should not be so ugly
    ext_names := "VK_KHR_swapchain".data;
    device_ci.ppEnabledExtensionNames = *ext_names;
    device_ci.pQueueCreateInfos = q_cis.data;
    device_ci.queueCreateInfoCount = cast(u32)q_cis.count;
    device_ci.pEnabledFeatures = *device_features;
    device_ci.enabledLayerCount = 0;
    if vkCreateDevice(vulkan_context.physical_device, *device_ci, null, *vulkan_context.device) != .SUCCESS {
        log(.FATAL, "Failed to create logical device.");
        return false;
    }
    for * vulkan_context.queues {
        vkGetDeviceQueue(vulkan_context.device, cast(u32)vulkan_context.queue_indices[it_index], 0, it);
    }
    return true;
}

print_available_vulkan_extensions :: () {
    extension_count: u32;
    vkEnumerateInstanceExtensionProperties(null, *extension_count, null);
    extension_array := NewArray(extension_count, VkExtensionProperties);
    defer free(extension_array.data);
    vkEnumerateInstanceExtensionProperties(null, *extension_count, extension_array.data);
    log(.INFO, "Available extensions:\n");
    for extension_array log(.INFO, "    % (%)\n", to_string(it.extensionName.data), it.specVersion);
}

get_suitable_physical_device :: (vulkan_context: *Vulkan_Context) -> bool {
    device_count : u32;
    vkEnumeratePhysicalDevices(vulkan_context.instance, *device_count, null);
    devices : [..]VkPhysicalDevice;
    devices.allocator = temp;
    array_resize(*devices, device_count);
    vkEnumeratePhysicalDevices(vulkan_context.instance, *device_count, devices.data);
    suitability :: (vulkan_context: *Vulkan_Context, dev: VkPhysicalDevice) -> int {
        props : VkPhysicalDeviceProperties;
        features: VkPhysicalDeviceFeatures;
        vkGetPhysicalDeviceProperties(dev, *props);
        vkGetPhysicalDeviceFeatures(dev, *features);
        score := 0;
        if props.deviceType == .DISCRETE_GPU score += 1000;
        score += cast(int)props.limits.maxImageDimension2D;
        if !device_check_extension_support(dev) return 0;
        res : bool;
        vulkan_context.swapchain.support, res = device_query_swapchain_details(vulkan_context, dev);
        if !res || vulkan_context.swapchain.support.formats.count == 0 || vulkan_context.swapchain.support.present_modes.count == 0 return 0;
        return score;
    }
    hiscore := 0;
    for devices {
        score := suitability(vulkan_context, it);
        if score > hiscore {
            vulkan_context.physical_device = it;
            hiscore = score;
        }
    }
     if(hiscore == 0){
        log(.FATAL, "Failed to find suitable GPU.");
        return false;
    }
    return true;
}

device_check_extension_support :: (physical_device : VkPhysicalDevice) -> bool {
    ext_count : u32;
    vkEnumerateDeviceExtensionProperties(physical_device, null, *ext_count, null);
    available_extensions: [..]VkExtensionProperties;
    available_extensions.allocator = temp;
    vkEnumerateDeviceExtensionProperties(physical_device, null, *ext_count, available_extensions.data);
    #if !DEBUG {
        #if OS == .WINDOWS {
            extensions: [2] *u8;
            extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
            extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
        } else {
            extensions: [2] *u8;
            extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
            extensions[1] = VK_KHR_XLIB_SURFACE_EXTENSION_NAME.data;
        }
    } else {
        #if OS == .WINDOWS {
            extensions: [3] *u8;
            extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
            extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
            extensions[2] = VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data;
        } else {
            extensions: [3] *u8;
            extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
            extensions[1] = VK_KHR_XLIB_SURFACE_EXTENSION_NAME.data;
            extensions[2] = VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data;
        }
    }
    for all_ext:extensions {
        found : bool;
        for dev_ext:available_extensions {
            if dev_ext.extensionName[0] == all_ext.* {
                found = true;
                break;
            }
            if !found return false;
        }
    }
    log(.INFO, "Chose physical device.");
    return true;
}


device_query_swapchain_details :: (vulkan_context : *Vulkan_Context, dev: VkPhysicalDevice) -> Swapchain_Description, bool {
    desc : Swapchain_Description;
    res := vkGetPhysicalDeviceSurfaceCapabilitiesKHR(dev, vulkan_context.surface, *desc.capabilities);
    if res != .SUCCESS {
        log(.FATAL, "Failed to query physical device's surface capabilities.");
        return desc, false;
    }
    format_count : u32;
    res = vkGetPhysicalDeviceSurfaceFormatsKHR(dev, vulkan_context.surface, *format_count, null);
    if res != .SUCCESS {
        log(.FATAL, "Failed to query physical device's surface formats.");
        return desc, false;
    }
    if format_count > 0 {
        array_reserve(*desc.formats, format_count);
        res = vkGetPhysicalDeviceSurfaceFormatsKHR(dev, vulkan_context.surface, *format_count, desc.formats.data);
        if res != .SUCCESS {
            log(.FATAL, "Failed to populate physical device's surface formats.");
            return desc, false;
        }
        desc.formats.count = format_count;
    }
    present_mode_count : u32;
    res = vkGetPhysicalDeviceSurfacePresentModesKHR(dev, vulkan_context.surface, *present_mode_count, null);
    if res != .SUCCESS {
        log(.FATAL, "Failed to query physical device's surface formats.");
        return desc, false;
    }
    if present_mode_count > 0 {
        array_reserve(*desc.present_modes, present_mode_count);
        res = vkGetPhysicalDeviceSurfacePresentModesKHR(dev, vulkan_context.surface, *present_mode_count, desc.present_modes.data);
        if res != .SUCCESS {
            log(.FATAL, "Failed to populate physical device's surface formats.");
            return desc, false;
        }
        desc.present_modes.count = present_mode_count;
    }
    return desc, true;
}

Queue_Family :: enum u8 {
    GRAPHICS :: 0;
    PRESENT :: 1;
}

find_queue_families :: (vulkan_context: *Vulkan_Context) {
    queue_count : u32;
    vkGetPhysicalDeviceQueueFamilyProperties(vulkan_context.physical_device, *queue_count, null);
    available_qs : [..]VkQueueFamilyProperties;
    available_qs.allocator = temp;
    array_reserve(*available_qs, queue_count);
    for *vulkan_context.queue_indices{
        it.* = -1;
    }
    vkGetPhysicalDeviceQueueFamilyProperties(vulkan_context.physical_device, *queue_count, available_qs.data);
    available_qs.count = queue_count;
    for available_qs {
        if it.queueFlags & .GRAPHICS_BIT && vulkan_context.queue_indices[Queue_Family.GRAPHICS] == -1 {
            vulkan_context.queue_indices[Queue_Family.GRAPHICS] = it_index;
        }
        present_support : u32;
        vkGetPhysicalDeviceSurfaceSupportKHR(vulkan_context.physical_device, cast(u32)it_index, vulkan_context.surface, *present_support);
        if present_support && vulkan_context.queue_indices[Queue_Family.PRESENT] == -1 {
            vulkan_context.queue_indices[Queue_Family.PRESENT] = it_index;
        }
    }
}
