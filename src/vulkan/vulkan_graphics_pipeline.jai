#import "File";
#import "String";

// @TODO: make this extendable with a config struct
graphics_pipeline_create :: (device: VkDevice, render_pass: Render_Pass, viewport: VkViewport, scissor: VkRect2D, vs_name: string, fs_name: string) -> Pipeline, bool #must {
    string_context := context;
    string_context.allocator = temp;
    vs_module, fs_module : VkShaderModule;
    pipeline : Pipeline;
    defer {
        shader_module_destroy(device, vs_module);
        shader_module_destroy(device, fs_module);
    }
    push_context string_context {
        vs_code, res := read_entire_file(vs_name);
        // @TODO: this is ugly
        vs_slice : []u8;
        vs_slice.data = vs_code.data;
        vs_slice.count = vs_code.count;
        if !res {
            log(.FATAL, "Failed to read vertex shader source file.");
            return pipeline, false;
        }
        fs_code : string;
        fs_code, res = read_entire_file(fs_name);
        fs_slice : []u8;
        fs_slice.data = fs_code.data;
        fs_slice.count = fs_code.count;
        if !res {
            log(.FATAL, "Failed to read fragment shader source file.");
            return pipeline, false;
        }
        vs_module, res = shader_module_create(device, vs_slice);
        if !res {
            log(.FATAL, "Failed to read vertex shader  module.");
            return pipeline, false;
        }
        fs_module, res = shader_module_create(device, fs_slice);
        if !res {
            log(.FATAL, "Failed to read fragment shader module.");
            return pipeline, false;
        }
    }
    input_assembly_ci := VkPipelineInputAssemblyStateCreateInfo.{
        topology = .TRIANGLE_LIST, primitiveRestartEnable = 0
    };
    vert_binding_desc := VkVertexInputBindingDescription.{
        binding = 0, stride = size_of(Vertex), inputRate = .VERTEX
    };
    vert_attribs_desc := VkVertexInputAttributeDescription.[
        .{
            binding = 0,
            location = 0,
            format = .R32G32_SFLOAT,
            offset = 0
        },
        .{
            binding = 0,
            location = 1,
            format = .R32G32B32_SFLOAT,
            offset = size_of([2]float32)
        }
    ];
    vertex_input_ci := VkPipelineVertexInputStateCreateInfo.{
        vertexBindingDescriptionCount = 1, pVertexBindingDescriptions = *vert_binding_desc,
        vertexAttributeDescriptionCount = vert_attribs_desc.count,
        pVertexAttributeDescriptions = vert_attribs_desc.data
    };
    rasterizer_ci := VkPipelineRasterizationStateCreateInfo.{
        depthClampEnable = 0, rasterizerDiscardEnable = 0, polygonMode = .FILL,
        lineWidth = 1.0, cullMode = .BACK_BIT, frontFace = .CLOCKWISE, depthBiasEnable = 0,
        depthBiasConstantFactor = 0.0, depthBiasClamp = 0.0, depthBiasSlopeFactor = 0.0
    };
    multisampling_ci := VkPipelineMultisampleStateCreateInfo.{
        sampleShadingEnable = 0, rasterizationSamples = ._1_BIT, minSampleShading = 1.0,
        pSampleMask = null, alphaToCoverageEnable = 0, alphaToOneEnable = 0
    };
    depth_stencil_ci := VkPipelineDepthStencilStateCreateInfo.{
        depthTestEnable = 1, depthWriteEnable = 1, depthCompareOp = .LESS,
        depthBoundsTestEnable = 0, stencilTestEnable = 0
    };
    color_blend_attach_state := VkPipelineColorBlendAttachmentState.{
        colorWriteMask = VkColorComponentFlagBits.R_BIT | .G_BIT | .B_BIT | .A_BIT, blendEnable = 1,
        srcColorBlendFactor = .SRC_ALPHA, dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
        colorBlendOp = .ADD, srcAlphaBlendFactor = .SRC_ALPHA,
        dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA, alphaBlendOp = .ADD
    };
    color_blending_ci := VkPipelineColorBlendStateCreateInfo.{
        logicOpEnable = 0, logicOp = .COPY, attachmentCount = 1,
        pAttachments = *color_blend_attach_state,
        blendConstants = .[0.0, 0.0, 0.0, 0.0]
    };
    dynamic_states := VkDynamicState.[ .VIEWPORT, .SCISSOR, .LINE_WIDTH];
    dynamic_state_ci := VkPipelineDynamicStateCreateInfo.{
        dynamicStateCount = dynamic_states.count,
        pDynamicStates = dynamic_states.data
    };
    viewports := VkViewport.[viewport];
    scissors := VkRect2D.[scissor];
    viewport_state_ci := VkPipelineViewportStateCreateInfo.{
        viewportCount = viewports.count, pViewports = viewports.data,
        scissorCount = scissors.count, pScissors = scissors.data
    };
    // @TODO: implement descriptor sets and push constants here
    pipeline_layout_ci := VkPipelineLayoutCreateInfo.{
        setLayoutCount = 0, pSetLayouts = null, pushConstantRangeCount = 0,
        pPushConstantRanges = null
    };
    vs_ci := VkPipelineShaderStageCreateInfo.{
        stage = .VERTEX_BIT, module = vs_module, pName = "main"
    };
    fs_ci := VkPipelineShaderStageCreateInfo.{
        stage = .FRAGMENT_BIT, module = fs_module, pName = "main"
    };
    shader_stages := VkPipelineShaderStageCreateInfo.[vs_ci, fs_ci];
    res := vkCreatePipelineLayout(device, *pipeline_layout_ci, null, *pipeline.layout);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create pipeline layout. %", res);
        return pipeline, false;
    }
    log(.INFO, "Pipeline LAYOUT created successfully.");
    pipeline_ci := VkGraphicsPipelineCreateInfo.{
        stageCount = 2, pStages = shader_stages.data, pVertexInputState = *vertex_input_ci,
        pInputAssemblyState = *input_assembly_ci, pViewportState = *viewport_state_ci,
        pRasterizationState = *rasterizer_ci, pMultisampleState = *multisampling_ci,
        pDepthStencilState = *depth_stencil_ci, pColorBlendState = *color_blending_ci,
        pDynamicState = *dynamic_state_ci, layout = pipeline.layout,
        renderPass = render_pass.handle, subpass = 0, basePipelineHandle = null, 
        basePipelineIndex = -1
    };
    res = vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, *pipeline_ci, null, *pipeline.handle);
    if res != .SUCCESS {
        log(.FATAL, "Failed to create graphics pipeline. %", res);
        return pipeline, false;
    }
    log(.INFO, "Pipeline created successfully.");
    return pipeline, true;
}
