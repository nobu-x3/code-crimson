#import "File";
#import "String";

pipeline_builder_default:: (using builder: *Pipeline_Builder, logical_device: VkDevice, render_pass: Render_Pass, global_descriptor_layout: VkDescriptorSetLayout) {
    device = logical_device;
    render_pass_handle = render_pass.handle;
    viewport := VkViewport.{x = 0, y = 0, width = WINDOW_WIDTH, height = WINDOW_HEIGHT, 
                                            minDepth = 0, maxDepth = 1}; 
    scissor := VkRect2D.{};
    string_context := context;
    string_context.allocator = temp;
    vs_module, fs_module : VkShaderModule;
    shader_modules.allocator = temp;
    array_reserve(*shader_modules, 2);
    pipeline : Pipeline;
    push_context string_context {
        vs_code, res := read_entire_file("bin/assets/shaders/shader_builtin.vert.spv");
        // @TODO: this is ugly
        vs_slice : []u8;
        vs_slice.data = vs_code.data;
        vs_slice.count = vs_code.count;
        if !res {
            log(.FATAL, "Failed to read vertex shader source file.");
            return;
        }
        fs_code : string;
        fs_code, res = read_entire_file("bin/assets/shaders/shader_builtin.frag.spv");
        fs_slice : []u8;
        fs_slice.data = fs_code.data;
        fs_slice.count = fs_code.count;
        if !res {
            log(.FATAL, "Failed to read fragment shader source file.");
            return;
        }
        vs_module, res = shader_module_create(device, vs_slice);
        if !res {
            log(.FATAL, "Failed to read vertex shader  module.");
            return;
        }
        array_add(*shader_modules, vs_module);
        fs_module, res = shader_module_create(device, fs_slice);
        if !res {
            log(.FATAL, "Failed to read fragment shader module.");
            return;
        }
        array_add(*shader_modules, fs_module);
    }
    input_assembly_ci = VkPipelineInputAssemblyStateCreateInfo.{
        topology = .TRIANGLE_LIST, primitiveRestartEnable = 0
    };
    vertex_binding_desc = VkVertexInputBindingDescription.{
        binding = 0, stride = size_of(Vertex), inputRate = .VERTEX
    };
    vertex_attribute_descs.allocator = temp;
    array_reserve(*vertex_attribute_descs, 2);
    array_add(*vertex_attribute_descs, 
        .{
            binding = 0,
            location = 0,
            format = .R32G32B32_SFLOAT,
            offset = 0
        }
    );
    array_add(*vertex_attribute_descs, 
        .{
            binding = 0,
            location = 1,
            format = .R32G32B32_SFLOAT,
            offset = size_of([3]float32)
        }
    );
    vertex_input_ci = VkPipelineVertexInputStateCreateInfo.{
        vertexBindingDescriptionCount = 1, pVertexBindingDescriptions = *vertex_binding_desc,
        vertexAttributeDescriptionCount = cast(u32)vertex_attribute_descs.count,
        pVertexAttributeDescriptions = vertex_attribute_descs.data
    };
    rasterizer_ci = VkPipelineRasterizationStateCreateInfo.{
        depthClampEnable = 1, rasterizerDiscardEnable = 0, polygonMode = .FILL,
        lineWidth = 1.0, cullMode = .BACK_BIT, frontFace = .COUNTER_CLOCKWISE, depthBiasEnable = 0,
        depthBiasConstantFactor = 0.0, depthBiasClamp = 0.0, depthBiasSlopeFactor = 0.0
    };
    multisampling_ci = VkPipelineMultisampleStateCreateInfo.{
        sampleShadingEnable = 0, rasterizationSamples = ._1_BIT, minSampleShading = 1.0,
        pSampleMask = null, alphaToCoverageEnable = 0, alphaToOneEnable = 0
    };
    depth_stencil_ci = VkPipelineDepthStencilStateCreateInfo.{
        depthTestEnable = 1, depthWriteEnable = 1, depthCompareOp = .LESS_OR_EQUAL,
        depthBoundsTestEnable = 0, stencilTestEnable = 0
    };
    color_blend_attach_state = VkPipelineColorBlendAttachmentState.{
        colorWriteMask = VkColorComponentFlagBits.R_BIT | .G_BIT | .B_BIT | .A_BIT, blendEnable = 1,
        srcColorBlendFactor = .SRC_ALPHA, dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
        colorBlendOp = .ADD, srcAlphaBlendFactor = .SRC_ALPHA,
        dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA, alphaBlendOp = .ADD
    };
    color_blending_ci = VkPipelineColorBlendStateCreateInfo.{
        logicOpEnable = 0, logicOp = .COPY, attachmentCount = 1,
        pAttachments = *color_blend_attach_state,
        blendConstants = .[0.0, 0.0, 0.0, 0.0]
    };
    dynamic_states.allocator = temp;
    array_reserve(*dynamic_states, 3);
    array_add(*dynamic_states, .VIEWPORT);
    array_add(*dynamic_states, .SCISSOR);
    array_add(*dynamic_states, .LINE_WIDTH);
    dynamic_state_ci = VkPipelineDynamicStateCreateInfo.{
        dynamicStateCount = cast(u32)dynamic_states.count,
        pDynamicStates = dynamic_states.data
    };
    viewports.allocator = temp;
    array_add(*viewports, viewport);
    scissors.allocator = temp;
    array_add(*scissors, scissor);
    viewport_state_ci = VkPipelineViewportStateCreateInfo.{
        viewportCount = cast(u32)viewports.count, pViewports = viewports.data,
        scissorCount = cast(u32)scissors.count, pScissors = scissors.data
    };
    push_constant_range = VkPushConstantRange.{
        size = size_of(Mesh_Push_Constants), offset = 0, stageFlags = .VERTEX_BIT
    };
    cam_buffer_binding := VkDescriptorSetLayoutBinding.{
        binding = 0, descriptorCount = 1,
        descriptorType = .UNIFORM_BUFFER,
        stageFlags = .VERTEX_BIT
    };
    set_ci := VkDescriptorSetLayoutCreateInfo.{
        bindingCount = 1, pBindings = *cam_buffer_binding
    };
    array_add(*descriptor_set_layouts, global_descriptor_layout);
    pipeline_layout_ci = VkPipelineLayoutCreateInfo.{
        setLayoutCount = cast(u32)descriptor_set_layouts.count, 
        pSetLayouts = descriptor_set_layouts.data, pushConstantRangeCount = 1,
        pPushConstantRanges = *push_constant_range
    };
    vs_ci := VkPipelineShaderStageCreateInfo.{
        stage = .VERTEX_BIT, module = vs_module, pName = "main"
    };
    fs_ci := VkPipelineShaderStageCreateInfo.{
        stage = .FRAGMENT_BIT, module = fs_module, pName = "main"
    };
    shader_stages.allocator = temp;
    array_reserve(*shader_stages, 2);
    array_add(*shader_stages, vs_ci);
    array_add(*shader_stages, fs_ci);
}

pipeline_builder_add_descriptor_layout :: (using builder: *Pipeline_Builder, layout: VkDescriptorSetLayout) {
    descriptor_set_layouts.allocator = temp;
    array_add(*descriptor_set_layouts, layout);
    pipeline_layout_ci = VkPipelineLayoutCreateInfo.{
        setLayoutCount = cast(u32)descriptor_set_layouts.count, 
        pSetLayouts = descriptor_set_layouts.data, pushConstantRangeCount = 1,
        pPushConstantRanges = *push_constant_range
    };
}

pipeline_build :: (using builder: *Pipeline_Builder) -> Pipeline, bool #must {
    pipeline: Pipeline;
    res := vkCreatePipelineLayout(device, *pipeline_layout_ci, null, *pipeline.layout);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create pipeline layout. %", res);
        return pipeline, false;
    }
    log(.INFO, "Pipeline LAYOUT created successfully.");
    pipeline_ci = VkGraphicsPipelineCreateInfo.{
        stageCount = 2, pStages = shader_stages.data, pVertexInputState = *vertex_input_ci,
        pInputAssemblyState = *input_assembly_ci, pViewportState = *viewport_state_ci,
        pRasterizationState = *rasterizer_ci, pMultisampleState = *multisampling_ci,
        pDepthStencilState = *depth_stencil_ci, pColorBlendState = *color_blending_ci,
        pDynamicState = *dynamic_state_ci, layout = pipeline.layout,
        renderPass = render_pass_handle, subpass = 0, basePipelineHandle = null, 
        basePipelineIndex = -1
    };
    defer {
        for shader_modules {
            shader_module_destroy(device, it);
        }
    }
    res = vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, *pipeline_ci, null, *pipeline.handle);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create graphics pipeline. %", res);
        return pipeline, false;
    }
    log(.INFO, "Pipeline created successfully.");
    return pipeline, true;
}
