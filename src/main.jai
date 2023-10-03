#import "Basic";
#import "Thread";
#import "System";
#import "VulkanSF";
#import "Window_Creation";
#import "Input";
#load "core/logger.jai";
#load "vulkan/vulkan_basics.jai";

main :: () {
    logger_init(0);
    defer logger_deinit();
    print_available_vulkan_extensions();
    vulkan_context : Vulkan_Context;
    if !vulkan_init(*vulkan_context){
        log(.FATAL, "Failed to create vulkan instance.");
        return;
    }
    defer vulkan_deinit(vulkan_context.instance);
    vulkan_context.window = create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "Code Crimson");
    surface_res := vulkan_surface_create(*vulkan_context);
    if !surface_res return;
    log(.INFO, "Vulkan surface successfully created.");
    dev_res := vulkan_device_create(*vulkan_context);
    if !dev_res return;
    log(.INFO, "Vulkan device successfully created.");
    swapchain_res := swapchain_create(*vulkan_context);
    if !swapchain_res return;
    defer swapchain_cleanup(*vulkan_context);
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
    log(.INFO, "Exited.");
}
