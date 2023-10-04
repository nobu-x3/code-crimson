#import "VulkanSF";
#import "Window_Creation";
#import "Input";
#if OS ==.WINDOWS {
    #import "Windows";
} else #if OS == .LINUX {
    #import "X11";
} 
#load "vulkan_types.jai";
#load "vulkan_device.jai";
#load "vulkan_swapchain.jai";
#load "vulkan_image.jai";
#load "vulkan_commands.jai";
#load "vulkan_render_pass.jai";
#load "vulkan_framebuffer.jai";
#load "vulkan_graphics_pipeline.jai";
#load "vulkan_shader_module.jai";

vulkan_init :: (using vulkan_context: *Vulkan_Context) -> bool {
    result : VkResult = .ERROR_INITIALIZATION_FAILED;
    // Application Info
    app_info: VkApplicationInfo;
    app_info.sType              = .APPLICATION_INFO;
    app_info.pApplicationName   = "Vulkan example";
    app_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    app_info.pEngineName        = "No Engine";
    app_info.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
    app_info.apiVersion         = VK_API_VERSION_1_2;
    // Create Vulkan Instance
    create_info : VkInstanceCreateInfo;
    create_info.sType                   = .INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo        = *app_info;
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
    create_info.enabledExtensionCount   = extensions.count;
    create_info.ppEnabledExtensionNames = extensions.data;
    #if DEBUG {
        debug_create_info := create_info;
        debug_create_info.enabledLayerCount = 1;
        debug_create_info.ppEnabledLayerNames = (*u8).["VK_LAYER_LUNARG_standard_validation"].data;
        result = vkCreateInstance(*debug_create_info, null, *instance);
        if result == .SUCCESS {
            vkCreateDebugReportCallbackEXT  : PFN_vkCreateDebugReportCallbackEXT = xx vkGetInstanceProcAddr(instance, "vkCreateDebugReportCallbackEXT");
            vkDestroyDebugReportCallbackEXT = xx vkGetInstanceProcAddr(instance, "vkDestroyDebugReportCallbackEXT");
            vkDebugReportMessageEXT         : PFN_vkDebugReportMessageEXT = xx vkGetInstanceProcAddr(instance, "vkDebugReportMessageEXT");
            if vkCreateDebugReportCallbackEXT {
                debug_callback_create_info: VkDebugReportCallbackCreateInfoEXT;
                debug_callback_create_info.flags |= .ERROR_BIT_EXT;
                debug_callback_create_info.flags |= .WARNING_BIT_EXT;
                debug_callback_create_info.pfnCallback = debug_callback;
                vkCreateDebugReportCallbackEXT(instance, *debug_callback_create_info, null, *debug_callback_handle);
            }
        }
    }
    if result != .SUCCESS {
        result = vkCreateInstance(*create_info, null, *instance);
    }
    return result == .SUCCESS;
}

vulkan_deinit :: (instance: VkInstance) {
    vkDestroyInstance(instance, null);
}

vulkan_surface_create :: (vulkan_context: *Vulkan_Context) -> bool {
    #if OS == .LINUX {
        surface_ci : VkXlibSurfaceCreateInfoKHR;
        surface_ci.window = vulkan_context.window;
        surface_ci.dpy = x_global_display;
        surface_result := vkCreateXlibSurfaceKHR(vulkan_context.instance, *surface_ci, null, *vulkan_context.surface);
        log(.INFO, "Surface result: %", surface_result);
        if surface_result != .SUCCESS {
            log(.FATAL, "Failed to create xlib surface. Error: %", surface_result);
            return false;
        }
    } else {
        my_hwnd := vulkan_context.window;
        surface_ci: VkWin32SurfaceCreateInfoKHR; 
        surface_ci.sType     = .WIN32_SURFACE_CREATE_INFO_KHR;
        surface_ci.hinstance = GetModuleHandleW(null);
        surface_ci.hwnd      = my_hwnd;
        result := vkCreateWin32SurfaceKHR(vulkan_context.instance, *surface_ci, null, *vulkan_context.surface);
        if result != .SUCCESS {
            log(.FATAL, "Failed to create xlib surface. Error: %", result);
            return false;
        }
    }
    return true;
}
