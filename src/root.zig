const std = @import("std");
const impl = @import("vulkan_implementation.zig");
pub const vk = @import("vulkan");

pub const DeviceAllocator = @import("DeviceAllocator.zig");

pub const Allocator = extern struct {
    user_data: *anyopaque,
    alloc: *const fn (*anyopaque, len: usize, alignment: usize) callconv(.c) ?[*]u8,
    remap: *const fn (*anyopaque, ptr: [*]u8, len: usize, alignment: usize, new_len: usize) callconv(.c) ?[*]u8,
    free: *const fn (*anyopaque, ptr: [*]u8, len: usize, alignment: usize) callconv(.c) void,
};

pub const SizeAndAlign = extern struct {
    size: usize,
    @"align": usize,
};

pub const DeviceAdrr = u64;

pub const Memory = enum(u8) {
    default,
    gpu,
    readback,
};

pub const Format = enum(u32) {
    none,
    r8_unorm,
    r8_snorm,
    r8_uint,
    r8_sint,
    r16_unorm,
    r16_snorm,
    r16_uint,
    r16_sint,
    r16_float,
    rg8_unorm,
    rg8_snorm,
    rg8_uint,
    rg8_sint,
    r32_float,
    r32_uint,
    r32_sint,
    rg16_unorm,
    rg16_snorm,
    rg16_uint,
    rg16_sint,
    rg16_float,
    rgba8_unorm,
    rgba8_unorm_srgb,
    rgba8_snorm,
    rgba8_uint,
    rgba8_sint,
    bgra8_unorm,
    bgra8_unorm_srgb,
    rgb10a2_uint,
    rgb10a2_unorm,
    rg11b10_ufloat,
    rgb9e5_ufloat,
    rg32_float,
    rg32_uint,
    rg32_sint,
    rgba16_unorm,
    rgba16_snorm,
    rgba16_uint,
    rgba16_sint,
    rgba16_float,
    rgba32_float,
    rgba32_uint,
    rgba32_sint,
    stencil8,
    depth16_unorm,
    depth24_plus,
    depth24_plus_stencil8,
    depth32_float,
    depth32_float_stencil8,
    bc1rgba_unorm,
    bc1rgba_unorm_srgb,
    bc2rgba_unorm,
    bc2rgba_unorm_srgb,
    bc3rgba_unorm,
    bc3rgba_unorm_srgb,
    bc4r_unorm,
    bc4r_snorm,
    bc5rg_unorm,
    bc5rg_snorm,
    bc6hrgb_ufloat,
    bc6hrgb_float,
    bc7rgba_unorm,
    bc7rgba_unorm_srgb,
    etc2rgb8_unorm,
    etc2rgb8_unorm_srgb,
    etc2rgb8a1_unorm,
    etc2rgb8a1_unorm_srgb,
    etc2rgba8_unorm,
    etc2rgba8_unorm_srgb,
    eacr11_unorm,
    eacr11_snorm,
    eacrg11_unorm,
    eacrg11_snorm,
    astc4x4_unorm,
    astc4x4_unorm_srgb,
    astc5x4_unorm,
    astc5x4_unorm_srgb,
    astc5x5_unorm,
    astc5x5_unorm_srgb,
    astc6x5_unorm,
    astc6x5_unorm_srgb,
    astc6x6_unorm,
    astc6x6_unorm_srgb,
    astc8x5_unorm,
    astc8x5_unorm_srgb,
    astc8x6_unorm,
    astc8x6_unorm_srgb,
    astc8x8_unorm,
    astc8x8_unorm_srgb,
    astc10x5_unorm,
    astc10x5_unorm_srgb,
    astc10x6_unorm,
    astc10x6_unorm_srgb,
    astc10x8_unorm,
    astc10x8_unorm_srgb,
    astc10x10_unorm,
    astc10x10_unorm_srgb,
    astc12x10_unorm,
    astc12x10_unorm_srgb,
    astc12x12_unorm,
    astc12x12_unorm_srgb,
};

pub const PresentMode = enum(u8) {
    immediate,
    mailbox,
    fifo,
    fifo_relaxed,
};

pub const Op = enum(u3) {
    never = 0,
    less = 1,
    equal = 2,
    less_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_equal = 6,
    always = 7,
};

pub const Sampler = packed struct(u64) {
    min_filter: Filter = .linear,
    mag_filter: Filter = .linear,
    mip_filter: MipFilter = .linear,

    address: AddressUVW = .{},

    coord: Coord = .normalized,
    border_color: BorderColor = .transparent_black,
    reduction: Reduction = .weighted_average,
    max_anisotropy: Anisotropy = .x1,

    compare: Compare = .{},

    lod_min: Lod = .min,
    lod_max: Lod = .max,
    lod_bias: Bias = .none,

    _pad: u1 = 0,

    pub const Filter = enum(u1) {
        nearest = 0,
        linear = 1,
    };

    pub const MipFilter = enum(u2) {
        none = 0,
        nearest = 1,
        linear = 2,
    };

    pub const AddressUVW = packed struct(u9) {
        u: Address = .clamp_to_edge,
        v: Address = .clamp_to_edge,
        w: Address = .clamp_to_edge,

        pub fn all(a: Address) AddressUVW {
            return .{ .u = a, .v = a, .w = a };
        }
    };

    pub const Address = enum(u3) {
        repeat = 0,
        mirrored_repeat = 1,
        clamp_to_edge = 2,
        clamp_to_border = 3,
    };

    pub const Coord = enum(u1) {
        normalized = 0,
        pixel = 1,
    };

    pub const BorderColor = enum(u2) {
        transparent_black = 0,
        opaque_black = 1,
        opaque_white = 2,
    };

    pub const Reduction = enum(u2) {
        weighted_average = 0,
        minimum = 1,
        maximum = 2,
    };

    pub const Anisotropy = enum(u3) {
        x1 = 0,
        x2 = 1,
        x4 = 2,
        x8 = 3,
        x16 = 4,
    };

    pub const Compare = packed struct(u4) {
        enable: bool = false,
        op: Op = .never,
    };

    pub const Lod = enum(u12) {
        min = 0,
        max = 0xFFF,
        _,
        pub fn of(x: f32) Lod {
            return @enumFromInt(@as(u12, @intFromFloat(@min(x, 15.996) * 256.0)));
        }
        pub fn toF32(self: Lod) f32 {
            return @as(f32, @floatFromInt(@intFromEnum(self))) / 256.0;
        }
    };

    pub const Bias = enum(i14) {
        none = 0,
        _,
        pub fn of(x: f32) Bias {
            return @enumFromInt(@as(i14, @intFromFloat(x * 256)));
        }
        pub fn toF32(self: Bias) f32 {
            return @as(f32, @floatFromInt(@intFromEnum(self))) / 256;
        }
    };
};

pub const Instance = opaque {
    pub extern fn sfCreateInstance(
        gpa: ?*Allocator,
        proc: vk.PfnGetInstanceProcAddr,
        required_surface_extensions_count: usize,
        required_surface_extensions_ptr: [*]const [*:0]const u8,
    ) *Instance;

    pub extern fn sfDestroyInstance(
        instance: *Instance,
    ) void;

    pub extern fn sfEnumerateAdapters(
        instance: *Instance,
        adapters_buffer_size: usize,
        adapters_buffer: ?[*]*Adapter,
        adapters_count: *usize,
    ) void;

    pub const SurfaceDescWin32 = struct {
        hinstance: *anyopaque,
        hwnd: *anyopaque,
    };
};

pub const Surface = opaque {
    pub const Win32Desc = extern struct {
        hinstance: *anyopaque,
        hwnd: *anyopaque,
    };

    pub extern fn sfCreateSurfaceWin32(
        instance: *Instance,
        desc: Win32Desc,
    ) *Surface;

    pub extern fn sfDestroySurface(
        surface: *Surface,
        instance: *Instance,
    ) void;
};

pub const Adapter = opaque {};

pub const SurfaceCapabilities = struct {
    usage: Texture.Usage,
    formats: []const Format,
    present_modes: []const PresentMode,
};

pub const Device = opaque {
    pub extern fn sfCreateDevice(
        instance: *Instance,
        adapter: *Adapter,
    ) *Device;

    pub extern fn sfDestroyDevice(
        d: *Device,
    ) void;

    pub extern fn sfSurfaceCapabilities(
        d: *Device,
        gpa: std.mem.Allocator,
        surface: *Surface,
    ) SurfaceCapabilities;

    pub extern fn sfDeviceToHostPointer(
        d: *Device,
        ptr: u64,
    ) *anyopaque;

    pub extern fn sfMalloc(
        d: *Device,
        bytes: usize,
        alignment: usize,
        memory: Memory,
    ) DeviceAdrr;

    pub extern fn sfFree(
        d: *Device,
        ptr: u64,
    ) void;
};

pub const Queue = opaque {
    pub const Type = enum(u8) {
        graphics,
        compute,
        transfer,
    };

    pub extern fn sfCreateQueue(
        d: *Device,
        queue_type: Type,
    ) *Queue;

    pub extern fn sfStartCommandRecording(
        queue: *Queue,
        d: *Device,
    ) *CommandBuffer;

    pub extern fn sfSubmit(
        queue: *Queue,
        d: *Device,
        command_buffers: []const *CommandBuffer,
    ) void;

    pub extern fn sfSubmitAndSignal(
        queue: *Queue,
        d: *Device,
        command_buffer_count: usize,
        command_buffers: [*]const *CommandBuffer,
        signal_semaphore: *Semaphore,
        signal_value: u64,
    ) void;
};

pub const Semaphore = opaque {
    pub extern fn sfCreateSemaphore(
        d: *Device,
        init_value: u64,
    ) *Semaphore;

    pub extern fn sfDestroySemaphore(
        semaphore: *Semaphore,
        d: *Device,
    ) void;

    pub extern fn sfWaitSemaphore(
        semaphore: *Semaphore,
        d: *Device,
        value: u64,
    ) void;
};

pub const Swapchain = opaque {
    pub const Desc = extern struct {
        format: Format,
        present_mode: PresentMode,
        usage: Texture.Usage,
    };

    pub extern fn sfCreateSwpachain(
        d: *Device,
        queue: *Queue,
        surface: *Surface,
        options: Desc,
    ) *Swapchain;

    pub extern fn sfDestroySwapchain(
        swapchain: *Swapchain,
        d: *Device,
    ) void;

    pub extern fn sfSwapchainAcquireNextTexture(
        swapchain: *Swapchain,
        d: *Device,
        queue: *Queue,
        extent: [2]u32,
    ) *Texture;

    pub extern fn sfSwapchainPresent(
        swapchain: *Swapchain,
        d: *Device,
        queue: *Queue,
        semaphore: *Semaphore,
        semaphore_value: u64,
    ) void;
};

pub const Stage = packed struct(u64) {
    transfer: bool = false,
    compute: bool = false,
    raster_color_out: bool = false,
    raster_depth_out: bool = false,
    pixel_shader: bool = false,
    vertex_shader: bool = false,
    reserved: u58 = 0,

    pub const all: Stage = .{
        .transfer = true,
        .compute = true,
        .raster_color_out = true,
        .raster_depth_out = true,
        .pixel_shader = true,
        .vertex_shader = true,
    };
};

pub const Hazard = packed struct(u64) {
    draw_arguments: bool = false,
    descriptors: bool = false,
    depth_stencil: bool = false,
    reserved: u61 = 0,
};

pub const CommandBuffer = opaque {
    pub const RenderPassDesc = extern struct {
        depth_target: DepthTarget = .{},
        stencil_target: StencilTarget = .{},
        color_target_count: u32,
        color_targets: [*]const ColorTarget = &.{},
    };

    pub const DepthTarget = extern struct {
        texture: ?*const Texture = null,
        load_op: LoadOp = .load,
        store_op: StoreOp = .store,
        clear_value: f32 = 1,
    };

    pub const StencilTarget = extern struct {
        texture: ?*const Texture = null,
        load_op: LoadOp = .load,
        store_op: StoreOp = .store,
        clear_value: u32 = 0,
    };

    pub const ColorTarget = extern struct {
        texture: *const Texture,
        load_op: LoadOp = .load,
        store_op: StoreOp = .store,
        clear_color: [4]f32 = .{ 0, 0, 0, 0 },
    };

    pub const LoadOp = enum(u8) {
        load,
        clear,
        dont_care,
    };

    pub const StoreOp = enum(u8) {
        store,
        dont_care,
    };

    pub const IndexType = enum(u8) {
        u16,
        u32,
    };

    pub const DrawIndexedArgs = extern struct {
        index_count: u32,
        instance_count: u32 = 1,
        first_index: u32 = 0,
        vertex_offset: i32 = 0,
        first_instance: u32 = 0,
    };

    pub extern fn sfSetActiveTextureHeapPtr(
        command_buffer: *CommandBuffer,
        d: *Device,
        heap_ptr: DeviceAdrr,
    ) void;

    pub extern fn sfSetPipeline(
        command_buffer: *CommandBuffer,
        d: *Device,
        pipeline: *Pipeline,
    ) void;

    pub extern fn sfDispatch(
        command_buffer: *CommandBuffer,
        d: *Device,
        data: DeviceAdrr,
        x: u32,
        y: u32,
        z: u32,
    ) void;

    pub extern fn sfBarrier(
        command_buffer: *CommandBuffer,
        d: *Device,
        before: Stage,
        after: Stage,
        hazard: Hazard,
    ) void;

    /// 256 bytes is a typical optimal alignment for dest
    pub extern fn sfCopyTextureToBuffer(
        command_buffer: *CommandBuffer,
        d: *Device,
        dest: DeviceAdrr,
        src: DeviceAdrr,
        texture: *Texture,
    ) void;

    pub extern fn sfCopyBufferToTexture(
        command_buffer: *CommandBuffer,
        d: *Device,
        dest: DeviceAdrr,
        src: DeviceAdrr,
        texture: *Texture,
    ) void;

    pub extern fn sfBeginRenderPass(
        cb: *CommandBuffer,
        d: *Device,
        desc: RenderPassDesc,
    ) void;

    pub extern fn sfEndRenderPass(
        cb: *CommandBuffer,
        d: *Device,
    ) void;

    pub extern fn sfDraw(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: DeviceAdrr,
        pixel_data: DeviceAdrr,
        vertex_count: u32,
        instance_count: u32,
    ) void;

    pub extern fn sfDrawIndexed(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: DeviceAdrr,
        pixel_data: DeviceAdrr,
        index_type: CommandBuffer.IndexType,
        indices: DeviceAdrr,
        index_count: u32,
    ) void;

    pub extern fn sfDrawIndexedInstanced(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: DeviceAdrr,
        pixel_data: DeviceAdrr,
        index_type: CommandBuffer.IndexType,
        indices: DeviceAdrr,
        index_count: u32,
        instance_count: u32,
    ) void;

    pub extern fn sfDrawIndexedInstancedIndirect(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: DeviceAdrr,
        pixel_data: DeviceAdrr,
        index_type: CommandBuffer.IndexType,
        indices: DeviceAdrr,
        args: DeviceAdrr,
    ) void;
};

pub const Texture = opaque {
    pub const Type = enum(u8) {
        @"1d",
        @"2d",
        @"3d",
    };

    pub const Usage = packed struct(u16) {
        sampled: bool = false,
        storage: bool = false,
        color_attachment: bool = false,
        depth_stencil_attachment: bool = false,
        padding: u12 = 0,
    };

    pub const Desc = extern struct {
        type: Type = .@"2d",
        dimensions: [3]u32,
        mip_count: u32 = 1,
        layer_count: u32 = 1,
        // sample_count: u32 = 1, TODO
        format: Format = .none,
        usage: Usage = .{},
    };

    pub const ViewInfo = extern struct {
        pub const all_mips = std.math.maxInt(u8);
        pub const all_layers = std.math.maxInt(u16);

        format: Format = .none,
        base_mip: u8 = 0,
        mip_count: u8 = all_mips,
        base_layer: u16 = 0,
        layer_count: u16 = all_layers,
    };

    pub const Descriptor = extern struct {
        data: [64]u8,

        pub extern fn sfDescriptorSizeAndHeapAlign(
            d: *Device,
        ) SizeAndAlign;

        pub fn store(descriptor: Descriptor, d: *Device, heap_ptr: []u8, index: usize) void {
            const size_align = Descriptor.sfDescriptorSizeAndHeapAlign(d);
            @memcpy(
                @as([*]u8, @ptrCast(heap_ptr)) + size_align.size * index,
                descriptor.data[0..size_align.size],
            );
        }
    };

    pub extern fn sfTextureSizeAndAlign(
        d: *Device,
        info: Desc,
    ) SizeAndAlign;

    pub extern fn sfCreateTexture(
        d: *Device,
        info: Desc,
        texture_data: DeviceAdrr,
    ) *Texture;

    pub extern fn sfDestroyTexture(
        texture: *Texture,
        d: *Device,
    ) void;

    pub extern fn sfTextureStorageDescriptor(
        texture: *Texture,
        d: *Device,
        view_info: ViewInfo,
    ) Descriptor;

    pub extern fn sfTextureViewDescriptor(
        texture: *Texture,
        d: *Device,
        view_info: ViewInfo,
    ) Descriptor;
};

pub const Pipeline = opaque {
    pub const RasterDesc = extern struct {
        topology: Topology = .triangle_list,
        cull: Cull = .none,
        alpha_to_coverage: bool = false,
        support_dual_source_blending: bool = false,
        sample_count: u8 = 1,
        depth_format: Format = .none,
        stencil_format: Format = .none,
        color_target_count: u32,
        color_targets: [*]const ColorTarget = &.{},
        /// optional embedded blend state
        blend_state: ?*const BlendDesc = null,
    };

    pub const Topology = enum(u8) {
        triangle_list,
        triangle_strip,
        triangle_fan,
    };

    pub const Cull = enum(u8) {
        ccw,
        cw,
        all,
        none,
    };

    pub const ColorTarget = extern struct {
        format: Format = .none,
        write_mask: RgbaWriteMask = .all,
    };

    pub const BlendDesc = extern struct {
        color_op: Blend = .add,
        src_color_factor: Factor = .one,
        dst_color_factor: Factor = .zero,
        alpha_op: Blend = .add,
        src_alpha_factor: Factor = .one,
        dst_alpha_factor: Factor = .zero,
        color_write_mask: RgbaWriteMask = .all,
    };

    pub const RgbaWriteMask = packed struct(u8) {
        r: bool,
        g: bool,
        b: bool,
        a: bool,
        reserved: u4 = 0,

        pub const all: RgbaWriteMask = .{
            .r = true,
            .g = true,
            .b = true,
            .a = true,
        };

        pub fn toInt(self: RgbaWriteMask) u4 {
            return @bitCast(self);
        }
        pub fn fromInt(flags: u4) RgbaWriteMask {
            return @bitCast(flags);
        }
        pub fn merge(lhs: RgbaWriteMask, rhs: RgbaWriteMask) RgbaWriteMask {
            return fromInt(toInt(lhs) | toInt(rhs));
        }
    };

    pub const Blend = enum(u8) {
        add,
        subtract,
        reverse_subtract,
        min,
        max,
    };

    pub const Factor = enum(u8) {
        zero,
        one,
        src_color,
        dst_color,
        src_alpha,
    };

    pub extern fn sfCreateComputePipeline(
        d: *Device,
        ir_size: usize,
        ir: [*]const u8,
    ) *Pipeline;

    pub extern fn sfCreateGraphicsPipeline(
        d: *Device,
        vertex_ir_size: usize,
        vertex_ir: [*]const u8,
        pixel_ir_size: usize,
        pixel_ir: [*]const u8,
        desc: RasterDesc,
    ) *Pipeline;

    pub extern fn sfDestroyPipeline(
        pipeline: *Pipeline,
        d: *Device,
    ) void;
};
