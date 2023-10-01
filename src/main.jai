#import "Basic";
#import "Thread";
#import "System";
#import "VulkanSF";
#import "Window_Creation";
#import "Input";
#load "core/logger.jai";
#load "vulkan/vulkan_basics.jai";

main :: () {
    logger := logger_init(0);
    defer logger_deinit(logger);
    print_available_vulkan_extensions();
    vulkan_context : Vulkan_Context;
    if !vulkan_init(*vulkan_context){
        log(logger, .FATAL, "Failed to create vulkan instance.");
        return;
    }
    defer vulkan_deinit(vulkan_context.instance);
    window := create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "Code Crimson");
    #if OS == .LINUX {
        surface_ci : VkXlibSurfaceCreateInfoKHR;
        surface_ci.window = window;
        surface_result := vkCreateXlibSurfaceKHR(vulkan_context.instance, *surface_ci, null, *vulkan_context.surface);
        if !surface_result {
            log(logger, .FATAL, "Failed to create xlib surface.");
            return;
        }
    } else {
        // @TODO: windows surface 
        #assert(false);
    }
    log(logger, .INFO, "Vulkan surface successfully created.");
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
    log(logger, .INFO, "Exited.");
}
