#import "Basic";
#import "Thread";
#import "System";
#import "VulkanSF";
#import "Window_Creation";
#import "Input";
#import "Math";
#load "core/logger.jai";
#load "renderer/vulkan/vulkan_basics.jai";
#load "renderer/renderer_types.jai";
#load "renderer/camera.jai";


radians :: inline (degrees : float) -> float {
    return degrees * PI/180;
}

degrees :: inline (radians: float) -> float {
    return radians * 180/PI;
}

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
    res : bool;
    vulkan_context.surface, res = vulkan_surface_create(vulkan_context.window, vulkan_context.instance);
    if !res return;
    log(.INFO, "Vulkan surface successfully created.");
    res = vulkan_device_create(*vulkan_context);
    if !res return;
    defer vkDestroyDevice(vulkan_context.device, null);
    log(.INFO, "Vulkan device successfully created.");
    vulkan_context.swapchain, res = swapchain_create(vulkan_context.window, vulkan_context.surface, vulkan_context.device, vulkan_context.physical_device, vulkan_context.queue_indices);
    if !res return;
    defer swapchain_cleanup(*vulkan_context);
    vulkan_context.command_pool, res = command_pool_create(vulkan_context.device, cast(u32)vulkan_context.queue_indices[Queue_Family.GRAPHICS]);
    if !res return;
    defer vkDestroyCommandPool(vulkan_context.device, vulkan_context.command_pool, null);
    create_command_buffers_default(*vulkan_context);
    vulkan_context.main_render_pass, res = render_pass_create(vulkan_context.swapchain, vulkan_context.device, 
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
    recreate_framebuffers(vulkan_context.device, *vulkan_context.swapchain, vulkan_context.main_render_pass);
    res = create_sync_objects(*vulkan_context);
    if !res return;
    defer {
        for 0..MAX_FRAMES_IN_FLIGHT - 1 {
            vkDestroySemaphore(vulkan_context.device, vulkan_context.image_available[it], null);
            vkDestroySemaphore(vulkan_context.device, vulkan_context.render_finished[it], null);
            vkDestroyFence(vulkan_context.device, vulkan_context.in_flight[it], null);
        }
    }
    vertices := Vertex.[
		.{pos = .[-0.5, -0.5], color = .[0.0, 0.0, 1.0]},
		.{pos = .[0.5, -0.5], color = .[1.0, 0.0, 0.0]},
		.{pos = .[0.5, 0.5], color = .[0.0, 1.0, 0.0]},
		.{pos = .[-0.5, 0.5], color = .[1.0, 0.0, 0.0]},
    ];
    indices := u16.[0, 1, 2, 2, 3, 0];
    vulkan_context.vertex_buffer, res = buffer_create_and_copy(vulkan_context.device, vulkan_context.physical_device, .VERTEX_BUFFER_BIT,
                            vulkan_context.command_pool, vulkan_context.queues[Queue_Family.GRAPHICS], vertices);
    if !res return;
    defer buffer_destroy(vulkan_context.device, vulkan_context.vertex_buffer);
    vulkan_context.index_buffer, res = buffer_create_and_copy(vulkan_context.device, vulkan_context.physical_device, .INDEX_BUFFER_BIT,
                            vulkan_context.command_pool, vulkan_context.queues[Queue_Family.GRAPHICS], indices);
    if !res return;
    defer buffer_destroy(vulkan_context.device, vulkan_context.index_buffer);
    vulkan_context.camera = camera_create(radians(70.0), cast(float)WINDOW_WIDTH/WINDOW_HEIGHT, 0.1, 1000);
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
        begin_frame(*vulkan_context, 0);
        draw_frame(vulkan_context);
        end_frame(*vulkan_context);
        reset_temporary_storage();
        frame_nr += 1;
    }
    log(.INFO, "Exited.");
}

begin_frame :: (using vulkan_context: *Vulkan_Context, delta_time: float64) {
    u64_low, u64_high := get_integer_range(u64);
    res : bool;
    ind : u32;
    vkWaitForFences(device, 1, *in_flight[curr_frame], 1, u64_high);
    ind, res = swapchain_acquire_next_image_index(vulkan_context, image_available[curr_frame], null, u64_high);
    // if !res return;
    reset_res := vkResetFences(device, 1, *in_flight[curr_frame]);
    if reset_res != .SUCCESS {
        log(.FATAL, "Failed to reset fence. %", reset_res);
        return;
    }
    vkResetCommandBuffer(command_buffers[curr_frame], 0);
    res = command_buffer_begin(command_buffers[curr_frame], .{});
    if !res return;
    viewport := VkViewport.{
        x = 0, y = 0, width = cast(float32)swapchain.extent.width, height = cast(float32)swapchain.extent.height,
        minDepth = 0, maxDepth = 1
    };
    scissor := VkRect2D.{
        offset = .{x = 0, y = 0}, extent = .{width = swapchain.extent.width, height = swapchain.extent.height}
    };
    vkCmdSetViewport(command_buffers[curr_frame], 0, 1, *viewport);
    vkCmdSetScissor(command_buffers[curr_frame], 0, 1, *scissor);
    render_pass_begin(main_render_pass, command_buffers[curr_frame], swapchain.framebuffers[image_index].handle);
}

end_frame :: (using vulkan_context: *Vulkan_Context) {
    render_pass_end(command_buffers[curr_frame]);
    res := command_buffer_end(command_buffers[curr_frame]);
    if !res return;
    wait_stages := VkPipelineStageFlags.[.COLOR_ATTACHMENT_OUTPUT_BIT];
    submit_info := VkSubmitInfo.{
        commandBufferCount = 1, pCommandBuffers = *command_buffers[curr_frame], 
        signalSemaphoreCount = 1, pSignalSemaphores = *render_finished[curr_frame],
        waitSemaphoreCount = 1, pWaitSemaphores = *image_available[curr_frame],
        pWaitDstStageMask = wait_stages.data
    };
    q_res := vkQueueSubmit(queues[Queue_Family.GRAPHICS], 1, *submit_info, in_flight[curr_frame]);
    if q_res != .SUCCESS {
        log(.FATAL, "Failed to submit draw command buffer. %", q_res);
        return;
    }
    swapchain_present(vulkan_context, queues[Queue_Family.GRAPHICS], *render_finished[curr_frame], *image_index);
}

frame_nr := 0;

draw_frame :: (using vulkan_context : Vulkan_Context) {
    cam_pos := Vector3.{0, 0, -10};
    view := make_translation_matrix4(cam_pos);
    view_proj := camera.projection * view;
    rot_q : Quaternion = ---; 
    set_from_axis_and_angle(*rot_q, .{0, 1, 0}, radians(frame_nr * 0.04));
    model := rotation_matrix(Matrix4, rot_q);
    push_constants := Mesh_Push_Constants.{render_matrix = view_proj * model};
    vkCmdBindPipeline(command_buffers[curr_frame], .GRAPHICS, pipeline.handle);
    vertex_buffers := VkBuffer.[vertex_buffer.handle];
    offsets := VkDeviceSize.[0];
    vkCmdBindVertexBuffers(command_buffers[curr_frame], 0, 1, vertex_buffers.data, offsets.data);
    vkCmdBindIndexBuffer(command_buffers[curr_frame], index_buffer.handle, 0, .UINT16);
    vkCmdPushConstants(command_buffers[curr_frame], pipeline.layout, .VERTEX_BIT, 0, size_of(Mesh_Push_Constants), *push_constants);
    vkCmdDrawIndexed(command_buffers[curr_frame], cast(u32)index_buffer.length, 1, 0, 0, 0);
}
