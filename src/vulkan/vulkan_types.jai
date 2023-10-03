MAX_FRAMES_IN_FLIGHT :: 2;
DEBUG :: true;  
WINDOW_WIDTH :: 640;
WINDOW_HEIGHT :: 480;
QUEUE_COUNT :: #run enum_highest_value(Queue_Family) + 1;

Render_Pass_Begin_Info :: struct {
    single_use, render_pass_continue, simultaneous_use: bool;
}

Swapchain_Description :: struct {
	capabilities:  VkSurfaceCapabilitiesKHR;
	formats:       [..]VkSurfaceFormatKHR;
	present_modes: [..]VkPresentModeKHR;
	depth_format:  VkFormat;
}

Queue_Family :: enum u8 {
    GRAPHICS :: 0;
    PRESENT :: 1;
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
Image_Info :: struct {
    image_type: VkImageType;
    width, height: u32;
    format : VkFormat;
    tiling: VkImageTiling;
    usage_flags: VkImageUsageFlags;
    memory_flags: VkMemoryPropertyFlags;
    view_aspect_flags: VkImageAspectFlags;
    create_view: bool;
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
    command_pool: VkCommandPool;
    command_buffers: [MAX_FRAMES_IN_FLIGHT]VkCommandBuffer;
    curr_frame : u32;
    #if DEBUG {
        vkDestroyDebugReportCallbackEXT : PFN_vkDestroyDebugReportCallbackEXT ;
        debug_callback : PFN_vkDebugReportCallbackEXT; 
        debug_callback_handle : VkDebugReportCallbackEXT;
    }
}
