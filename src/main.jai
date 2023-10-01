#import "Basic";
#import "Vulkan";
#import "Thread";
#import "System";
#import "Window_Creation";
#import "Input";
#load "core/logger.jai";

DEBUG :: true;  // :DebugDisabled


Vulkan_Context :: struct {
    instance : VkInstance;
    surface : VkSurfaceKHR;
    #if DEBUG {
        vkDestroyDebugReportCallbackEXT : PFN_vkDestroyDebugReportCallbackEXT ;
        debug_callback : PFN_vkDebugReportCallbackEXT; 
        debug_callback_handle : VkDebugReportCallbackEXT;
    }
}

vulkan_init :: (using vulkan_context: *Vulkan_Context) -> bool {
    result : VkResult = .ERROR_INITIALIZATION_FAILED;
    // Application Info
    app_info: VkApplicationInfo;
    app_info.sType              = .APPLICATION_INFO;
    app_info.pApplicationName   = "Vulkan example";
    app_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    app_info.pEngineName        = "No Engine";
    app_info.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
    app_info.apiVersion         = VK_API_VERSION_1_0;
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
            extensions: [1] *u8;
            extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
        }
    } else {
        #if OS == .WINDOWS {
            extensions: [3] *u8;
            extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
            extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
            extensions[2] = VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data;
        } else {
            extensions: [2] *u8;
            extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
            extensions[1] = VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data;
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

WINDOW_WIDTH :: 640;
WINDOW_HEIGHT :: 480;

print_available_vulkan_extensions :: () {
    extension_count: u32;
    vkEnumerateInstanceExtensionProperties(null, *extension_count, null);
    extension_array := NewArray(extension_count, VkExtensionProperties);
    defer free(extension_array.data);
    vkEnumerateInstanceExtensionProperties(null, *extension_count, extension_array.data);
    print("Available extensions:\n");
    for extension_array print("    % (%)\n", to_string(it.extensionName.data), it.specVersion);
}

main :: () {
    logger := logger_init(0);
    defer logger_deinit(logger);
    vulkan_context : Vulkan_Context;
    if !vulkan_init(*vulkan_context){
        log(logger, .FATAL, "Failed to create vulkan instance.");
        return;
    }
    defer vulkan_deinit(vulkan_context.instance);
    window := create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "Code Crimson");
    surface_ci : VkXlibSurfaceCreateInfoKHR;
    surface_ci.window = window;
    surface_result := vkCreateXlibSurfaceKHR(vulkan_context.instance, *surface_ci, null, *vulkan_context.surface);
    if !surface_result {
        log(logger, .FATAL, "Failed to create xlib surface.");
        return;
    }
    print_available_vulkan_extensions();
    exit := false;
    while !exit {
        update_window_events();
        for events_this_frame {
            if it.type == .QUIT then exit = true;
            if it.type == .KEYBOARD {
                if it.key_pressed == 0 continue;
                if it.key_code == .ESCAPE {
                    exit = true;
                }
            }
        }
        reset_temporary_storage();
    }
}
