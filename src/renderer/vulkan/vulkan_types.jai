MAX_FRAMES_IN_FLIGHT :: 3;
WINDOW_WIDTH :: 800;
WINDOW_HEIGHT :: 600;
QUEUE_COUNT :: #run enum_highest_value(Queue_Family) + 1;

Buffer :: struct {
    handle: VkBuffer;
    memory: VkDeviceMemory;
    length: int;
    size: VkDeviceSize;
    stride: int;
}

Render_Pass_Begin_Info :: struct {
    single_use, render_pass_continue, simultaneous_use: bool;
}

Descriptor_Set :: struct {
    handles: [..]VkDescriptorSet;
    layout: VkDescriptorSetLayout;
    buffers: [..]Buffer;
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

// Pipeline builder's resizable arrays are allocated using temp allocator,
// so use them fast.
Pipeline_Builder :: struct {
    device: VkDevice;
    render_pass_handle: VkRenderPass;
    input_assembly_ci : VkPipelineInputAssemblyStateCreateInfo;
    vertex_binding_desc: VkVertexInputBindingDescription;
    vertex_attribute_descs: [..]VkVertexInputAttributeDescription;
    vertex_input_ci: VkPipelineVertexInputStateCreateInfo;
    rasterizer_ci: VkPipelineRasterizationStateCreateInfo;
    multisampling_ci: VkPipelineMultisampleStateCreateInfo;
    depth_stencil_ci: VkPipelineDepthStencilStateCreateInfo;
    color_blend_attach_state: VkPipelineColorBlendAttachmentState;
    color_blending_ci: VkPipelineColorBlendStateCreateInfo;
    dynamic_states: [..]VkDynamicState;
    dynamic_state_ci: VkPipelineDynamicStateCreateInfo;
    backdrop_buffer: Buffer;
    viewports: [..]VkViewport;
    scissors: [..]VkRect2D;
    viewport_state_ci: VkPipelineViewportStateCreateInfo;
    push_constant_range: VkPushConstantRange;
    pipeline_layout_ci: VkPipelineLayoutCreateInfo;
    shader_stages: [..]VkPipelineShaderStageCreateInfo;
    pipeline_ci: VkGraphicsPipelineCreateInfo;
    shader_modules: [..]VkShaderModule;
    descriptor_set_layouts: [..]VkDescriptorSetLayout;
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
    vertex_buffer: Buffer;
    index_buffer: Buffer;
    pipeline: Pipeline;
    descriptor_pool : VkDescriptorPool;
    global_descriptor_set: Descriptor_Set;
    object_storage_set: Descriptor_Set;
    ambient_buffer: Buffer;
    curr_frame : u32;
    image_index : u32;
    camera: Camera;
    material_mesh_map: Table(Material, [..]Mesh, given_hash_function=material_hash_function, given_compare_function=material_compare);
    #if DEBUG {
        debug_callback_handle : VkDebugReportCallbackEXT;
    }
}

material_hash_function :: (material: Material) -> u32 {
    return cast(u32)material.pipeline.handle;
}

material_compare :: (a: Material, b: Material) -> bool {
    return a.pipeline.handle == b.pipeline.handle;
}
