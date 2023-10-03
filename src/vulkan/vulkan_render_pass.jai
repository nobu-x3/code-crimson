
// @TODO: all the stuff we're passing here should eventually go to a config struct.
render_pass_create :: (vulkan_context: *Vulkan_Context, device: VkDevice, color: Color, extent: Extent2D, depth: float32, stencil: u32) -> Render_Pass, bool #must {
    render_pass := Render_Pass.{color = color, extent = extent, depth = depth, stencil = stencil};
    color_attach_desc := VkAttachmentDescription.{format = vulkan_context.swapchain.format.format, samples = ._1_BIT, loadOp = .CLEAR, storeOp = .STORE,
                                                stencilLoadOp = .DONT_CARE, stencilStoreOp = .DONT_CARE, initialLayout = .UNDEFINED, 
                                                finalLayout = .PRESENT_SRC_KHR};
    color_attach_ref := VkAttachmentReference.{attachment = 0, layout = .COLOR_ATTACHMENT_OPTIMAL};
    depth_attach_desc := VkAttachmentDescription.{format = vulkan_context.swapchain.format.format, samples = ._1_BIT, loadOp = .CLEAR, storeOp = .DONT_CARE,
                                                stencilLoadOp = .DONT_CARE, stencilStoreOp = .DONT_CARE, initialLayout = .UNDEFINED, 
                                                finalLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL};
    depth_attach_ref := VkAttachmentReference.{attachment = 1, layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL};
    // @TODO: add auto parsing and configuration for other attachments
    //////////////////////////////////////////////////////////////////
    subpass_desc := VkSubpassDescription.{pipelineBindPoint = .GRAPHICS, colorAttachmentCount = 1, 
                                        pColorAttachments = *color_attach_ref, pDepthStencilAttachment = *depth_attach_ref};
    dependency := VkSubpassDependency.{srcSubpass = VK_SUBPASS_EXTERNAL, dstSubpass = 0, srcStageMask = .COLOR_ATTACHMENT_OUTPUT_BIT, 
                                        dstStageMask = .COLOR_ATTACHMENT_OUTPUT_BIT,
                                        dstAccessMask = VkAccessFlags.COLOR_ATTACHMENT_READ_BIT | .COLOR_ATTACHMENT_WRITE_BIT};
                                        attachments := VkAttachmentDescription.[color_attach_desc, depth_attach_desc];
    render_pass_ci := VkRenderPassCreateInfo.{attachmentCount = 2, pAttachments = attachments.data, subpassCount = 1,
    pSubpasses = *subpass_desc, dependencyCount = 1, pDependencies = *dependency};
    res := vkCreateRenderPass(device, *render_pass_ci, null, *render_pass.handle);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create render pass. %", res);
        return render_pass, false;
    }
    return render_pass, true;
}

render_pass_destroy :: (device: VkDevice, render_pass: *Render_Pass) {
    if render_pass != null {
        vkDestroyRenderPass(device, render_pass.handle, null);
        render_pass.handle = null;
    }
}

render_pass_begin :: (render_pass: Render_Pass, command_buffer: VkCommandBuffer, target_fb: VkFramebuffer) {
    render_pass_begin_info := VkRenderPassBeginInfo.{renderPass = render_pass.handle, framebuffer = target_fb, 
                renderArea = .{ offset = .{x = cast(s32)render_pass.extent.x, y = cast(s32)render_pass.extent.y}, 
                extent = .{ width = cast(u32)render_pass.extent.w, height = cast(u32)render_pass.extent.h }},
                clearValueCount = 2};
    clear_vals := VkClearValue.[
        .{color = VkClearColorValue.{.[render_pass.color.r, render_pass.color.g, render_pass.color.b, render_pass.color.a]}},
        .{depthStencil = .{depth = render_pass.depth, stencil = render_pass.stencil}}
    ];
    render_pass_begin_info.pClearValues = clear_vals.data;
    vkCmdBeginRenderPass(command_buffer, *render_pass_begin_info, .INLINE);
}

render_pass_end :: (command_buffer: VkCommandBuffer) {
    vkCmdEndRenderPass(command_buffer);
}
