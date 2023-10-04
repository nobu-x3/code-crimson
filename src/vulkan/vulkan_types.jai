MAX_FRAMES_IN_FLIGHT :: 2;
WINDOW_WIDTH :: 640;
WINDOW_HEIGHT :: 480;
QUEUE_COUNT :: #run enum_highest_value(Queue_Family) + 1;

Vertex :: struct {
    pos: [2]float32;
    color: [3]float32;
}

Color :: struct {
    r, g, b, a: float32;
}

Extent2D :: struct {
    x, y, w, h: float32;
}

Render_Pass_Begin_Info :: struct {
    single_use, render_pass_continue, simultaneous_use: bool;
}

Render_Pass :: struct {
    handle: VkRenderPass;
    depth: float32;
    color: Color;
    extent: Extent2D;
    stencil: u32;
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

Pipeline :: struct {
    handle : VkPipeline;
    layout : VkPipelineLayout;
}

Framebuffer :: struct {
    handle: VkFramebuffer;
    attachments: [..]VkImageView;
    render_pass: VkRenderPass;
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
    main_render_pass : Render_Pass;
    image_available: [MAX_FRAMES_IN_FLIGHT]VkSemaphore;
    render_finished: [MAX_FRAMES_IN_FLIGHT]VkSemaphore;
    in_flight: [MAX_FRAMES_IN_FLIGHT]VkFence;
    pipeline: Pipeline;
    curr_frame : u32;
    #if DEBUG {
        debug_callback_handle : VkDebugReportCallbackEXT;
    }
}
