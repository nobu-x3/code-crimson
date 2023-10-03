Swapchain_Description :: struct {
	capabilities:  VkSurfaceCapabilitiesKHR;
	formats:       [..]VkSurfaceFormatKHR;
	present_modes: [..]VkPresentModeKHR;
	depth_format:  VkFormat;
}

Swapchain :: struct {
    handle: VkSwapchainKHR;
    images: [..]VkImage;
    views: [..]VkImageView;
    depth_attachment: Image;
    format: VkSurfaceFormatKHR;
    depth_format: VkFormat;
    extent: VkExtent2D;
    present_mode: VkPresentModeKHR;
    image_count: u32;
    support: Swapchain_Description;
    framebuffers: [..]Framebuffer;
    max_frames_in_flight: u32;
}

Framebuffer :: struct {
    handle: VkFramebuffer;
    attachments: [..]VkImageView;
    render_pass: VkRenderPass;
}

Color :: struct {
    r, g, b, a: float32;
}

Image :: struct {
    handle: VkImage;
    memory: VkDeviceMemory;
    view: VkImageView;
    width, height: u32;
}

Vulkan_Context :: struct {
    instance : VkInstance;
    window : Window_Type;
    surface : VkSurfaceKHR;
    physical_device: VkPhysicalDevice;
    device : VkDevice;
    queue_indices : [QUEUE_COUNT]int;
    queues : [QUEUE_COUNT]VkQueue;
    swapchain: Swapchain;
    #if DEBUG {
        vkDestroyDebugReportCallbackEXT : PFN_vkDestroyDebugReportCallbackEXT ;
        debug_callback : PFN_vkDebugReportCallbackEXT; 
        debug_callback_handle : VkDebugReportCallbackEXT;
    }
}
