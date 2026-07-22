const std = @import("std");
const gpu = @import("root.zig");
const vk = @import("vulkan");

pub const vk_to_gpu = struct {
    pub fn format(fmt: vk.Format) ?gpu.Format {
        return switch (fmt) {
            .undefined => .none,
            .r8_unorm => .r8_unorm,
            .r8_snorm => .r8_snorm,
            .r8_uint => .r8_uint,
            .r8_sint => .r8_sint,
            .r16_uint => .r16_uint,
            .r16_sint => .r16_sint,
            .r16_sfloat => .r16_float,
            .r8g8_unorm => .rg8_unorm,
            .r8g8_snorm => .rg8_snorm,
            .r8g8_uint => .rg8_uint,
            .r8g8_sint => .rg8_sint,
            .r32_sfloat => .r32_float,
            .r32_uint => .r32_uint,
            .r32_sint => .r32_sint,
            .r16g16_uint => .rg16_uint,
            .r16g16_sint => .rg16_sint,
            .r16g16_sfloat => .rg16_float,
            .r8g8b8a8_unorm => .rgba8_unorm,
            .r8g8b8a8_srgb => .rgba8_unorm_srgb,
            .r8g8b8a8_snorm => .rgba8_snorm,
            .r8g8b8a8_uint => .rgba8_uint,
            .r8g8b8a8_sint => .rgba8_sint,
            .b8g8r8a8_unorm => .bgra8_unorm,
            .b8g8r8a8_srgb => .bgra8_unorm_srgb,
            .a2b10g10r10_uint_pack32 => .rgb10a2_uint,
            .a2b10g10r10_unorm_pack32 => .rgb10a2_unorm,
            .b10g11r11_ufloat_pack32 => .rg11b10_ufloat,
            .e5b9g9r9_ufloat_pack32 => .rgb9e5_ufloat,
            .r32g32_sfloat => .rg32_float,
            .r32g32_uint => .rg32_uint,
            .r32g32_sint => .rg32_sint,
            .r16g16b16a16_uint => .rgba16_uint,
            .r16g16b16a16_sint => .rgba16_sint,
            .r16g16b16a16_sfloat => .rgba16_float,
            .r32g32b32a32_sfloat => .rgba32_float,
            .r32g32b32a32_uint => .rgba32_uint,
            .r32g32b32a32_sint => .rgba32_sint,
            .s8_uint => .stencil8,
            .d16_unorm => .depth16_unorm,
            .x8_d24_unorm_pack32 => .depth24_plus,
            .d24_unorm_s8_uint => .depth24_plus_stencil8,
            .d32_sfloat => .depth32_float,
            .d32_sfloat_s8_uint => .depth32_float_stencil8,
            .bc1_rgba_unorm_block => .bc1rgba_unorm,
            .bc1_rgba_srgb_block => .bc1rgba_unorm_srgb,
            .bc2_unorm_block => .bc2rgba_unorm,
            .bc2_srgb_block => .bc2rgba_unorm_srgb,
            .bc3_unorm_block => .bc3rgba_unorm,
            .bc3_srgb_block => .bc3rgba_unorm_srgb,
            .bc4_unorm_block => .bc4r_unorm,
            .bc4_snorm_block => .bc4r_snorm,
            .bc5_unorm_block => .bc5rg_unorm,
            .bc5_snorm_block => .bc5rg_snorm,
            .bc6h_ufloat_block => .bc6hrgb_ufloat,
            .bc6h_sfloat_block => .bc6hrgb_float,
            .bc7_unorm_block => .bc7rgba_unorm,
            .bc7_srgb_block => .bc7rgba_unorm_srgb,
            .etc2_r8g8b8_unorm_block => .etc2rgb8_unorm,
            .etc2_r8g8b8_srgb_block => .etc2rgb8_unorm_srgb,
            .etc2_r8g8b8a1_unorm_block => .etc2rgb8a1_unorm,
            .etc2_r8g8b8a1_srgb_block => .etc2rgb8a1_unorm_srgb,
            .etc2_r8g8b8a8_unorm_block => .etc2rgba8_unorm,
            .etc2_r8g8b8a8_srgb_block => .etc2rgba8_unorm_srgb,
            .eac_r11_unorm_block => .eacr11_unorm,
            .eac_r11_snorm_block => .eacr11_snorm,
            .eac_r11g11_unorm_block => .eacrg11_unorm,
            .eac_r11g11_snorm_block => .eacrg11_snorm,
            .astc_4x_4_unorm_block => .astc4x4_unorm,
            .astc_4x_4_srgb_block => .astc4x4_unorm_srgb,
            .astc_5x_4_unorm_block => .astc5x4_unorm,
            .astc_5x_4_srgb_block => .astc5x4_unorm_srgb,
            .astc_5x_5_unorm_block => .astc5x5_unorm,
            .astc_5x_5_srgb_block => .astc5x5_unorm_srgb,
            .astc_6x_5_unorm_block => .astc6x5_unorm,
            .astc_6x_5_srgb_block => .astc6x5_unorm_srgb,
            .astc_6x_6_unorm_block => .astc6x6_unorm,
            .astc_6x_6_srgb_block => .astc6x6_unorm_srgb,
            .astc_8x_5_unorm_block => .astc8x5_unorm,
            .astc_8x_5_srgb_block => .astc8x5_unorm_srgb,
            .astc_8x_6_unorm_block => .astc8x6_unorm,
            .astc_8x_6_srgb_block => .astc8x6_unorm_srgb,
            .astc_8x_8_unorm_block => .astc8x8_unorm,
            .astc_8x_8_srgb_block => .astc8x8_unorm_srgb,
            .astc_1_0x_5_unorm_block => .astc10x5_unorm,
            .astc_1_0x_5_srgb_block => .astc10x5_unorm_srgb,
            .astc_1_0x_6_unorm_block => .astc10x6_unorm,
            .astc_1_0x_6_srgb_block => .astc10x6_unorm_srgb,
            .astc_1_0x_8_unorm_block => .astc10x8_unorm,
            .astc_1_0x_8_srgb_block => .astc10x8_unorm_srgb,
            .astc_1_0x_10_unorm_block => .astc10x10_unorm,
            .astc_1_0x_10_srgb_block => .astc10x10_unorm_srgb,
            .astc_1_2x_10_unorm_block => .astc12x10_unorm,
            .astc_1_2x_10_srgb_block => .astc12x10_unorm_srgb,
            .astc_1_2x_12_unorm_block => .astc12x12_unorm,
            .astc_1_2x_12_srgb_block => .astc12x12_unorm_srgb,
            else => null,
        };
    }

    pub fn usageFlags(flags: vk.ImageUsageFlags) gpu.Texture.Usage {
        return .{
            .sampled = flags.sampled_bit,
            .storage = flags.storage_bit,
            .color_attachment = flags.color_attachment_bit,
            .depth_stencil_attachment = flags.depth_stencil_attachment_bit,
        };
    }

    pub fn presentMode(mode: vk.PresentModeKHR) ?gpu.PresentMode {
        return switch (mode) {
            .immediate_khr => .immediate,
            .mailbox_khr => .mailbox,
            .fifo_khr => .fifo,
            .fifo_relaxed_khr => .fifo_relaxed,
            else => null,
        };
    }
};

pub const gpu_to_vk = struct {
    pub fn format(fmt: gpu.Format) vk.Format {
        return switch (fmt) {
            .none => .undefined,
            .r8_unorm => .r8_unorm,
            .r8_snorm => .r8_snorm,
            .r8_uint => .r8_uint,
            .r8_sint => .r8_sint,
            .r16_uint => .r16_uint,
            .r16_sint => .r16_sint,
            .r16_float => .r16_sfloat,
            .rg8_unorm => .r8g8_unorm,
            .rg8_snorm => .r8g8_snorm,
            .rg8_uint => .r8g8_uint,
            .rg8_sint => .r8g8_sint,
            .r32_float => .r32_sfloat,
            .r32_uint => .r32_uint,
            .r32_sint => .r32_sint,
            .rg16_uint => .r16g16_uint,
            .rg16_sint => .r16g16_sint,
            .rg16_float => .r16g16_sfloat,
            .rgba8_unorm => .r8g8b8a8_unorm,
            .rgba8_unorm_srgb => .r8g8b8a8_srgb,
            .rgba8_snorm => .r8g8b8a8_snorm,
            .rgba8_uint => .r8g8b8a8_uint,
            .rgba8_sint => .r8g8b8a8_sint,
            .bgra8_unorm => .b8g8r8a8_unorm,
            .bgra8_unorm_srgb => .b8g8r8a8_srgb,
            .rgb10a2_uint => .a2b10g10r10_uint_pack32,
            .rgb10a2_unorm => .a2b10g10r10_unorm_pack32,
            .rg11b10_ufloat => .b10g11r11_ufloat_pack32,
            .rgb9e5_ufloat => .e5b9g9r9_ufloat_pack32,
            .rg32_float => .r32g32_sfloat,
            .rg32_uint => .r32g32_uint,
            .rg32_sint => .r32g32_sint,
            .rgba16_uint => .r16g16b16a16_uint,
            .rgba16_sint => .r16g16b16a16_sint,
            .rgba16_float => .r16g16b16a16_sfloat,
            .rgba32_float => .r32g32b32a32_sfloat,
            .rgba32_uint => .r32g32b32a32_uint,
            .rgba32_sint => .r32g32b32a32_sint,
            .stencil8 => .s8_uint,
            .depth16_unorm => .d16_unorm,
            .depth24_plus => .x8_d24_unorm_pack32,
            .depth24_plus_stencil8 => .d24_unorm_s8_uint,
            .depth32_float => .d32_sfloat,
            .depth32_float_stencil8 => .d32_sfloat_s8_uint,
            .bc1rgba_unorm => .bc1_rgba_unorm_block,
            .bc1rgba_unorm_srgb => .bc1_rgba_srgb_block,
            .bc2rgba_unorm => .bc2_unorm_block,
            .bc2rgba_unorm_srgb => .bc2_srgb_block,
            .bc3rgba_unorm => .bc3_unorm_block,
            .bc3rgba_unorm_srgb => .bc3_srgb_block,
            .bc4r_unorm => .bc4_unorm_block,
            .bc4r_snorm => .bc4_snorm_block,
            .bc5rg_unorm => .bc5_unorm_block,
            .bc5rg_snorm => .bc5_snorm_block,
            .bc6hrgb_ufloat => .bc6h_ufloat_block,
            .bc6hrgb_float => .bc6h_sfloat_block,
            .bc7rgba_unorm => .bc7_unorm_block,
            .bc7rgba_unorm_srgb => .bc7_srgb_block,
            .etc2rgb8_unorm => .etc2_r8g8b8_unorm_block,
            .etc2rgb8_unorm_srgb => .etc2_r8g8b8_srgb_block,
            .etc2rgb8a1_unorm => .etc2_r8g8b8a1_unorm_block,
            .etc2rgb8a1_unorm_srgb => .etc2_r8g8b8a1_srgb_block,
            .etc2rgba8_unorm => .etc2_r8g8b8a8_unorm_block,
            .etc2rgba8_unorm_srgb => .etc2_r8g8b8a8_srgb_block,
            .eacr11_unorm => .eac_r11_unorm_block,
            .eacr11_snorm => .eac_r11_snorm_block,
            .eacrg11_unorm => .eac_r11g11_unorm_block,
            .eacrg11_snorm => .eac_r11g11_snorm_block,
            .astc4x4_unorm => .astc_4x_4_unorm_block,
            .astc4x4_unorm_srgb => .astc_4x_4_srgb_block,
            .astc5x4_unorm => .astc_5x_4_unorm_block,
            .astc5x4_unorm_srgb => .astc_5x_4_srgb_block,
            .astc5x5_unorm => .astc_5x_5_unorm_block,
            .astc5x5_unorm_srgb => .astc_5x_5_srgb_block,
            .astc6x5_unorm => .astc_6x_5_unorm_block,
            .astc6x5_unorm_srgb => .astc_6x_5_srgb_block,
            .astc6x6_unorm => .astc_6x_6_unorm_block,
            .astc6x6_unorm_srgb => .astc_6x_6_srgb_block,
            .astc8x5_unorm => .astc_8x_5_unorm_block,
            .astc8x5_unorm_srgb => .astc_8x_5_srgb_block,
            .astc8x6_unorm => .astc_8x_6_unorm_block,
            .astc8x6_unorm_srgb => .astc_8x_6_srgb_block,
            .astc8x8_unorm => .astc_8x_8_unorm_block,
            .astc8x8_unorm_srgb => .astc_8x_8_srgb_block,
            .astc10x5_unorm => .astc_1_0x_5_unorm_block,
            .astc10x5_unorm_srgb => .astc_1_0x_5_srgb_block,
            .astc10x6_unorm => .astc_1_0x_6_unorm_block,
            .astc10x6_unorm_srgb => .astc_1_0x_6_srgb_block,
            .astc10x8_unorm => .astc_1_0x_8_unorm_block,
            .astc10x8_unorm_srgb => .astc_1_0x_8_srgb_block,
            .astc10x10_unorm => .astc_1_0x_10_unorm_block,
            .astc10x10_unorm_srgb => .astc_1_0x_10_srgb_block,
            .astc12x10_unorm => .astc_1_2x_10_unorm_block,
            .astc12x10_unorm_srgb => .astc_1_2x_10_srgb_block,
            .astc12x12_unorm => .astc_1_2x_12_unorm_block,
            .astc12x12_unorm_srgb => .astc_1_2x_12_srgb_block,
            else => @panic("TODO"), // TODO: why some missing?
        };
    }

    pub fn aspectsForFormat(fmt: gpu.Format) vk.ImageAspectFlags {
        return switch (fmt) {
            .stencil8 => .{ .stencil_bit = true },
            .depth16_unorm, .depth24_plus => .{ .depth_bit = true },
            .depth24_plus_stencil8 => .{ .depth_bit = true, .stencil_bit = true },
            .depth32_float => .{ .depth_bit = true },
            .depth32_float_stencil8 => .{ .depth_bit = true, .stencil_bit = true },
            else => .{ .color_bit = true },
        };
    }

    pub fn topology(topo: gpu.Topology) vk.PrimitiveTopology {
        return switch (topo) {
            .triangle_list => .triangle_list,
            .triangle_strip => .triangle_strip,
        };
    }

    pub fn presentMode(mode: gpu.PresentMode) vk.PresentModeKHR {
        return switch (mode) {
            .immediate => .immediate_khr,
            .mailbox => .mailbox_khr,
            .fifo => .fifo_khr,
            .fifo_relaxed => .fifo_relaxed_khr,
        };
    }

    pub fn pipelineStage(stage: gpu.Stage) vk.PipelineStageFlags2 {
        var out: vk.PipelineStageFlags2 = .{};
        if (stage.all) out.all_commands_bit = true;
        if (stage.transfer) out.all_transfer_bit = true;
        if (stage.compute) out.compute_shader_bit = true;
        if (stage.raster_color_out) out.color_attachment_output_bit = true;
        if (stage.raster_depth_out) {
            out.early_fragment_tests_bit = true;
            out.late_fragment_tests_bit = true;
        }
        if (stage.pixel_shader) out.fragment_shader_bit = true;
        if (stage.vertex_shader) {
            out.vertex_shader_bit = true;
            out.index_input_bit = true;
        }
        // TODO:
        // if (stage.mesh_shader) {
        //     out.task_shader_bit_ext = true;
        //     out.mesh_shader_bit_ext = true;
        // }
        return out;
    }
    pub fn textureType(tex: gpu.Texture.Type) vk.ImageType {
        return switch (tex) {
            .@"1d" => .@"1d",
            .@"2d" => .@"2d",
            .@"3d" => .@"3d",
        };
    }

    pub fn usageFlags(flags: gpu.Texture.Usage) vk.ImageUsageFlags {
        return .{
            .transfer_src_bit = true,
            .transfer_dst_bit = true,
            .sampled_bit = flags.sampled,
            .storage_bit = flags.storage,
            .color_attachment_bit = flags.color_attachment,
            .depth_stencil_attachment_bit = flags.depth_stencil_attachment,
        };
    }

    pub fn viewType(tex: gpu.Texture.Type) vk.ImageViewType {
        return switch (tex) {
            .@"1d" => .@"1d",
            .@"2d" => .@"2d",
            .@"3d" => .@"3d",
        };
    }

    pub fn blendFactor(factor: gpu.Factor) vk.BlendFactor {
        return switch (factor) {
            .zero => .zero,
            .one => .one,
            .src_color => .src_color,
            .dst_color => .dst_color,
            .src_alpha => .src_alpha,
            .one_minus_src_alpha => .one_minus_src_alpha,
        };
    }

    pub fn blendOp(op: gpu.Blend) vk.BlendOp {
        return switch (op) {
            .add => .add,
            .subtract => .subtract,
            .rev_subtract => .reverse_subtract,
            .min => .min,
            .max => .max,
        };
    }

    pub fn attachmentLoadOp(op: gpu.LoadOp) vk.AttachmentLoadOp {
        return switch (op) {
            .undefined => .dont_care, // TODO: dont care? hu?
            .load => .load,
            .clear => .clear,
        };
    }

    pub fn attachmentStoreOp(op: gpu.StoreOp) vk.AttachmentStoreOp {
        return switch (op) {
            .undefined => .dont_care,
            .store => .store,
            .discard => .dont_care,
        };
    }

    pub fn compareOp(op: gpu.Op) vk.CompareOp {
        return switch (op) {
            .never => .never,
            .less => .less,
            .equal => .equal,
            .less_equal => .less_or_equal,
            .greater => .greater,
            .not_equal => .not_equal,
            .greater_equal => .greater_or_equal,
            .always => .always,
        };
    }

    pub fn stencilOp(op: gpu.StencilOp) vk.StencilOp {
        return switch (op) {
            .keep => .keep,
            .zero => .zero,
            .replace => .replace,
            .increment_clamp => .increment_and_clamp,
            .decrement_clamp => .decrement_and_clamp,
            .invert => .invert,
            .increment_wrap => .increment_and_wrap,
            .decrement_wrap => .decrement_and_wrap,
        };
    }

    pub fn indexType(t: gpu.IndexType) vk.IndexType {
        switch (t) {
            .u_int16 => .uint_16,
            .u_int32 => .uint_32,
        }
    }

    pub fn blendDesc(state: *const gpu.BlendDesc) vk.PipelineColorBlendAttachmentState {
        const blend_disabled: bool =
            state.color_op == .add and state.src_color_factor == .one and
            state.dst_color_factor == .zero and state.alpha_op == .add and
            state.src_alpha_factor == .one and state.dst_color_factor == .zero;

        comptime std.debug.assert(@TypeOf(state.color_write_mask) == u8); //TODO: fix code bellow
        return vk.PipelineColorBlendAttachmentState{
            .blend_enable = if (!blend_disabled) .true else .false,
            .src_color_blend_factor = blendFactor(state.src_color_factor),
            .dst_color_blend_factor = blendFactor(state.dst_color_factor),
            .color_blend_op = blendOp(state.color_op),
            .src_alpha_blend_factor = blendFactor(state.src_alpha_factor),
            .dst_alpha_blend_factor = blendFactor(state.dst_alpha_factor),
            .alpha_blend_op = blendOp(state.alpha_op),
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        };
    }
};
