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
    // print_available_vulkan_extensions();
    vulkan_context : Vulkan_Context;
    if !vulkan_init(*vulkan_context){
        log(.FATAL, "Failed to create vulkan instance.");
        return;
    }
    defer vulkan_deinit(vulkan_context.instance, vulkan_context);
    vulkan_context.window = create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "Code Crimson");
    res := vulkan_surface_create(*vulkan_context);
    if !res return;
    log(.INFO, "Vulkan surface successfully created.");
    res = vulkan_device_create(*vulkan_context);
    if !res return;
    defer vkDestroyDevice(vulkan_context.device, null);
    log(.INFO, "Vulkan device successfully created.");
    res = swapchain_create(*vulkan_context);
    if !res return;
    defer swapchain_cleanup(*vulkan_context);
    vulkan_context.command_pool, res = command_pool_create(vulkan_context.device, cast(u32)vulkan_context.queue_indices[Queue_Family.GRAPHICS]);
    if !res return;
    defer vkDestroyCommandPool(vulkan_context.device, vulkan_context.command_pool, null);
    create_command_buffers_default(*vulkan_context);
    vulkan_context.main_render_pass, res = render_pass_create(*vulkan_context, vulkan_context.device, 
                                            .{0, 0, 0, 1}, .{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT},
                                            1.0, 0);
    if !res return;
    defer render_pass_destroy(vulkan_context.device, *vulkan_context.main_render_pass);
    create_command_buffers_default(*vulkan_context);
    vulkan_context.pipeline, res = graphics_pipeline_create(vulkan_context.device, vulkan_context.main_render_pass, 
                                VkViewport.{x = 0, y = 0, width = WINDOW_WIDTH, height = WINDOW_HEIGHT, 
                                            minDepth = 0, maxDepth = 1}, VkRect2D.{},
                                        "bin/assets/shaders/shader_builtin.vert.spv",
                                        "bin/assets/shaders/shader_builtin.frag.spv");
    if !res return;
    defer vkDestroyPipelineLayout(vulkan_context.device, vulkan_context.pipeline.layout, null);
    defer vkDestroyPipeline(vulkan_context.device, vulkan_context.pipeline.handle, null);
    res = create_sync_objects(*vulkan_context);
    if !res return;
    defer {
        for 0..MAX_FRAMES_IN_FLIGHT - 1 {
            vkDestroySemaphore(vulkan_context.device, vulkan_context.image_available[it], null);
            vkDestroySemaphore(vulkan_context.device, vulkan_context.render_finished[it], null);
            vkDestroyFence(vulkan_context.device, vulkan_context.in_flight[it], null);
        }
    }
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
