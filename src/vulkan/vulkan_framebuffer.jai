
framebuffer_create :: (device: VkDevice, render_pass: Render_Pass, width: u32, height: u32, attachments: []VkImageView) -> Framebuffer, bool #must {
    framebuffer := Framebuffer.{render_pass = render_pass.handle};
    array_copy(*framebuffer.attachments, attachments);
    framebuffer_ci := VkFramebufferCreateInfo.{renderPass = render_pass.handle, attachmentCount = cast(u32)attachments.count,
                                                pAttachments = framebuffer.attachments.data, width = width, height = height,
                                                layers = 1};
    res := vkCreateFramebuffer(device, *framebuffer_ci, null, *framebuffer.handle);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create framebuffer. %", res);
        return framebuffer, false;
    }
    return framebuffer, true;
}

framebuffer_destroy :: (device: VkDevice, framebuffer: *Framebuffer) {
    vkDestroyFramebuffer(device, framebuffer.handle, null);
    framebuffer.handle = null;
    array_free(framebuffer.attachments);
}

recreate_framebuffers :: (device: VkDevice, swapchain: Swapchain, render_pass: Render_Pass) {

    for 0..swapchain.image_count-1 {
        if swapchain.framebuffers.count > 0 framebuffer_destroy(device, *swapchain.framebuffers[it]);
    }
    array_reserve(*swapchain.framebuffers, swapchain.image_count);
    for 0..swapchain.image_count-1 {
        attachments := VkImageView.[swapchain.views[it], swapchain.depth_attachment.view];
        fb, res := framebuffer_create(device, render_pass, swapchain.extent.width, swapchain.extent.height, attachments);
        if !res return;
        array_add(*swapchain.framebuffers, fb);
    }
}
