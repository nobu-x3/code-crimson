#import "Basic";
#import "SDL";
#import "Vulkan";
#import "Thread";
#import "System";
#load "core/logger.jai";

DEBUG :: false;  // :DebugDisabled

vulkan_init :: (instance: *VkInstance) -> bool {
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
        // @ToDo: Non-Windows version
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
            // @ToDo: Non-Windows version
            #assert(false);
        }
    }
    create_info.enabledExtensionCount   = extensions.count;
    create_info.ppEnabledExtensionNames = extensions.data;
    #if DEBUG {
        debug_create_info := create_info;
        debug_create_info.enabledLayerCount = 1;
        debug_create_info.ppEnabledLayerNames = (*u8).["VK_LAYER_LUNARG_standard_validation"].data;
        result = vkCreateInstance(*debug_create_info, null, instance);
        if result == .SUCCESS {
            vkCreateDebugReportCallbackEXT  : PFN_vkCreateDebugReportCallbackEXT = xx vkGetInstanceProcAddr(instance.*, "vkCreateDebugReportCallbackEXT");
            vkDestroyDebugReportCallbackEXT = xx vkGetInstanceProcAddr(instance.*, "vkDestroyDebugReportCallbackEXT");
            vkDebugReportMessageEXT         : PFN_vkDebugReportMessageEXT = xx vkGetInstanceProcAddr(instance.*, "vkDebugReportMessageEXT");
            if vkCreateDebugReportCallbackEXT {
                debug_callback_create_info: VkDebugReportCallbackCreateInfoEXT;
                debug_callback_create_info.flags |= .ERROR_BIT_EXT;
                debug_callback_create_info.flags |= .WARNING_BIT_EXT;
                debug_callback_create_info.pfnCallback = debug_callback;
                vkCreateDebugReportCallbackEXT(instance.*, *debug_callback_create_info, null, *debug_callback_handle);
            }
        }
    }
    if result != .SUCCESS {
        result = vkCreateInstance(*create_info, null, instance);
    }
    return result == .SUCCESS;
}

vulkan_deinit :: (instance: VkInstance) {
    vkDestroyInstance(instance, null);
}

create_window :: () -> *SDL_Window, bool {
    SDL_Init(SDL_INIT_VIDEO);

    // Create an application window with the following settings:
    window := SDL_CreateWindow("Code Crimson",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 640, 480,
        SDL_WINDOW_SHOWN);

    // Check that the window was successfully created
    if window == null {
        // In the case that the window could not be made...
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return null, false;
    }
    return window, true;
}

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
    instance : VkInstance;
    if !vulkan_init(*instance){
        log(logger, .FATAL, "Failed to create vulkan instance.");
        return;
    }
    defer vulkan_deinit(instance);
    window, window_ok := create_window();
    if !window_ok return;
    print_available_vulkan_extensions();
    exit := false;
    while !exit {
        event : SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case SDL_QUIT;
                    exit = true;
                case SDL_KEYUP;
                    if event.key.keysym.sym == SDLK_ESCAPE {
                        exit = true;
                    }
            }
        }
        SDL_Delay(1);
        reset_temporary_storage();
    }

    // Close and destroy the window
    SDL_DestroyWindow(window);

    // Clean up
    SDL_Quit();
}
