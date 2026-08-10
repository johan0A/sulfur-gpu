// Generated file, do not edit.
// version: 0.1.0

const std = @import("std");
const target = @import("builtin").target;

pub const @"callconv": std.builtin.CallingConvention = switch (target.os.tag) {
    .windows => if (target.cpu.arch == .x86) .{ .x86_stdcall = .{} } else .c,
    else => .c,
};

pub const descriptor_max_size: usize = 64;
pub const all_mips: u32 = 0xFFFFFFFF;
pub const all_layers: u32 = 0xFFFFFFFF;

pub const DeviceAddress = u64;

pub const Instance = opaque {};
pub const Surface = opaque {};
pub const Adapter = opaque {};
pub const Device = opaque {};
pub const Queue = opaque {};
pub const Semaphore = opaque {};
pub const Swapchain = opaque {};
pub const CommandBuffer = opaque {};
pub const Texture = opaque {};
pub const Pipeline = opaque {};

pub const Memory = enum(u32) {
    default = 0,
    gpu = 1,
    readback = 2,
};

pub const PresentMode = enum(u32) {
    immediate = 0,
    mailbox = 1,
    fifo = 2,
    fifo_relaxed = 3,
};

pub const CompareOp = enum(u32) {
    never = 0,
    less = 1,
    equal = 2,
    less_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_equal = 6,
    always = 7,
};

pub const QueueType = enum(u32) {
    graphics = 0,
    compute = 1,
    transfer = 2,
};

pub const LoadOp = enum(u32) {
    load = 0,
    clear = 1,
    dont_care = 2,
};

pub const StoreOp = enum(u32) {
    store = 0,
    dont_care = 1,
};

pub const IndexType = enum(u32) {
    uint16 = 0,
    uint32 = 1,
};

pub const TextureType = enum(u32) {
    @"1d" = 0,
    @"2d" = 1,
    @"3d" = 2,
};

pub const Topology = enum(u32) {
    triangle_list = 0,
    triangle_strip = 1,
    triangle_fan = 2,
};

pub const Cull = enum(u32) {
    ccw = 0,
    cw = 1,
    all = 2,
    none = 3,
};

pub const BlendOp = enum(u32) {
    add = 0,
    subtract = 1,
    reverse_subtract = 2,
    min = 3,
    max = 4,
};

pub const BlendFactor = enum(u32) {
    zero = 0,
    one = 1,
    src_color = 2,
    dst_color = 3,
    src_alpha = 4,
};

pub const Format = enum(u32) {
    none = 0,
    r8_unorm = 1,
    r8_snorm = 2,
    r8_uint = 3,
    r8_sint = 4,
    r16_unorm = 5,
    r16_snorm = 6,
    r16_uint = 7,
    r16_sint = 8,
    r16_float = 9,
    rg8_unorm = 10,
    rg8_snorm = 11,
    rg8_uint = 12,
    rg8_sint = 13,
    r32_float = 14,
    r32_uint = 15,
    r32_sint = 16,
    rg16_unorm = 17,
    rg16_snorm = 18,
    rg16_uint = 19,
    rg16_sint = 20,
    rg16_float = 21,
    rgba8_unorm = 22,
    rgba8_unorm_srgb = 23,
    rgba8_snorm = 24,
    rgba8_uint = 25,
    rgba8_sint = 26,
    bgra8_unorm = 27,
    bgra8_unorm_srgb = 28,
    rgb10a2_uint = 29,
    rgb10a2_unorm = 30,
    rg11b10_ufloat = 31,
    rgb9e5_ufloat = 32,
    rg32_float = 33,
    rg32_uint = 34,
    rg32_sint = 35,
    rgba16_unorm = 36,
    rgba16_snorm = 37,
    rgba16_uint = 38,
    rgba16_sint = 39,
    rgba16_float = 40,
    rgba32_float = 41,
    rgba32_uint = 42,
    rgba32_sint = 43,
    stencil8 = 44,
    depth16_unorm = 45,
    depth24_plus = 46,
    depth24_plus_stencil8 = 47,
    depth32_float = 48,
    depth32_float_stencil8 = 49,
    bc1rgba_unorm = 50,
    bc1rgba_unorm_srgb = 51,
    bc2rgba_unorm = 52,
    bc2rgba_unorm_srgb = 53,
    bc3rgba_unorm = 54,
    bc3rgba_unorm_srgb = 55,
    bc4r_unorm = 56,
    bc4r_snorm = 57,
    bc5rg_unorm = 58,
    bc5rg_snorm = 59,
    bc6hrgb_ufloat = 60,
    bc6hrgb_float = 61,
    bc7rgba_unorm = 62,
    bc7rgba_unorm_srgb = 63,
    etc2rgb8_unorm = 64,
    etc2rgb8_unorm_srgb = 65,
    etc2rgb8a1_unorm = 66,
    etc2rgb8a1_unorm_srgb = 67,
    etc2rgba8_unorm = 68,
    etc2rgba8_unorm_srgb = 69,
    eacr11_unorm = 70,
    eacr11_snorm = 71,
    eacrg11_unorm = 72,
    eacrg11_snorm = 73,
    astc4x4_unorm = 74,
    astc4x4_unorm_srgb = 75,
    astc5x4_unorm = 76,
    astc5x4_unorm_srgb = 77,
    astc5x5_unorm = 78,
    astc5x5_unorm_srgb = 79,
    astc6x5_unorm = 80,
    astc6x5_unorm_srgb = 81,
    astc6x6_unorm = 82,
    astc6x6_unorm_srgb = 83,
    astc8x5_unorm = 84,
    astc8x5_unorm_srgb = 85,
    astc8x6_unorm = 86,
    astc8x6_unorm_srgb = 87,
    astc8x8_unorm = 88,
    astc8x8_unorm_srgb = 89,
    astc10x5_unorm = 90,
    astc10x5_unorm_srgb = 91,
    astc10x6_unorm = 92,
    astc10x6_unorm_srgb = 93,
    astc10x8_unorm = 94,
    astc10x8_unorm_srgb = 95,
    astc10x10_unorm = 96,
    astc10x10_unorm_srgb = 97,
    astc12x10_unorm = 98,
    astc12x10_unorm_srgb = 99,
    astc12x12_unorm = 100,
    astc12x12_unorm_srgb = 101,
};

pub const Stage = packed struct(u32) {
    transfer: bool = false,
    compute: bool = false,
    raster_color_out: bool = false,
    raster_depth_out: bool = false,
    pixel_shader: bool = false,
    vertex_shader: bool = false,
    padding: u26 = 0,

    pub const all: Stage = .{
        .transfer = true,
        .compute = true,
        .raster_color_out = true,
        .raster_depth_out = true,
        .pixel_shader = true,
        .vertex_shader = true,
    };
};

pub const Hazard = packed struct(u32) {
    draw_arguments: bool = false,
    descriptors: bool = false,
    depth_stencil: bool = false,
    padding: u29 = 0,
};

pub const TextureUsage = packed struct(u32) {
    sampled: bool = false,
    storage: bool = false,
    color_attachment: bool = false,
    depth_stencil_attachment: bool = false,
    padding: u28 = 0,
};

pub const ColorWriteMask = packed struct(u32) {
    r: bool = false,
    g: bool = false,
    b: bool = false,
    a: bool = false,
    padding: u28 = 0,

    pub const all: ColorWriteMask = .{
        .r = true,
        .g = true,
        .b = true,
        .a = true,
    };
};

pub const AllocFn = *const fn (user_data: *anyopaque, length: usize, alignment: usize) callconv(@"callconv") ?[*]u8;
pub const RemapFn = *const fn (user_data: *anyopaque, pointer: [*]u8, length: usize, alignment: usize, new_length: usize) callconv(@"callconv") ?[*]u8;
pub const FreeFn = *const fn (user_data: *anyopaque, pointer: [*]u8, length: usize, alignment: usize) callconv(@"callconv") void;

pub const Allocator = extern struct {
    user_data: *anyopaque,
    alloc: AllocFn,
    remap: RemapFn,
    free: FreeFn,
};

pub const SizeAndAlign = extern struct {
    size: usize,
    alignment: usize,
};

pub const SurfaceWin32Desc = extern struct {
    hinstance: *anyopaque,
    hwnd: *anyopaque,
};

pub const SurfaceXlibDesc = extern struct {
    display: *anyopaque,
    window: u64,
};

pub const SwapchainDesc = extern struct {
    format: Format,
    present_mode: PresentMode,
    usage: TextureUsage,
};

pub const DepthAttachment = extern struct {
    texture: ?*const Texture = null,
    load_op: LoadOp = .load,
    store_op: StoreOp = .store,
    clear_value: f32 = 1.0,
};

pub const StencilAttachment = extern struct {
    texture: ?*const Texture = null,
    load_op: LoadOp = .load,
    store_op: StoreOp = .store,
    clear_value: u32 = 0,
};

pub const ColorAttachment = extern struct {
    texture: *const Texture,
    load_op: LoadOp = .load,
    store_op: StoreOp = .store,
    clear_color: [4]f32 = .{
        0.0,
        0.0,
        0.0,
        0.0,
    },
};

pub const RenderPassDesc = extern struct {
    depth_attachment: DepthAttachment,
    stencil_attachment: StencilAttachment,
    color_attachment_count: u32,
    color_attachments: ?[*]const ColorAttachment = null,
};

pub const DrawIndexedArguments = extern struct {
    index_count: u32,
    instance_count: u32 = 1,
    first_index: u32 = 0,
    vertex_offset: i32 = 0,
    first_instance: u32 = 0,
};

pub const TextureDesc = extern struct {
    type: TextureType = .@"2d",
    dimensions: [3]u32,
    mip_count: u32 = 1,
    layer_count: u32 = 1,
    format: Format = .none,
    usage: TextureUsage = .{},
};

pub const TextureViewDesc = extern struct {
    format: Format = .none,
    base_mip: u32 = 0,
    mip_count: u32 = all_mips,
    base_layer: u32 = 0,
    layer_count: u32 = all_layers,
};

pub const Descriptor = extern struct {
    data: [descriptor_max_size]u8,
};

pub const BlendDesc = extern struct {
    color_op: BlendOp = .add,
    src_color_factor: BlendFactor = .one,
    dst_color_factor: BlendFactor = .zero,
    alpha_op: BlendOp = .add,
    src_alpha_factor: BlendFactor = .one,
    dst_alpha_factor: BlendFactor = .zero,
    color_write_mask: ColorWriteMask = .all,
};

pub const ColorTarget = extern struct {
    format: Format = .none,
    write_mask: ColorWriteMask = .all,
};

pub const GraphicsPipelineDesc = extern struct {
    topology: Topology = .triangle_list,
    cull: Cull = .none,
    alpha_to_coverage: bool = false,
    support_dual_source_blending: bool = false,
    sample_count: u32 = 1,
    depth_format: Format = .none,
    stencil_format: Format = .none,
    color_target_count: u32,
    color_targets: ?[*]const ColorTarget = null,
    blend_state: ?*const BlendDesc = null,
};

extern fn sfCreateInstance(allocator: ?*Allocator) callconv(@"callconv") *Instance;
pub const createInstance = sfCreateInstance;

extern fn sfDestroyInstance(instance: *Instance) callconv(@"callconv") void;
pub const destroyInstance = sfDestroyInstance;

extern fn sfEnumerateAdapters(instance: *Instance, adapters_capacity: usize, adapters: ?[*]*Adapter, adapter_count: *usize) callconv(@"callconv") void;
pub const enumerateAdapters = sfEnumerateAdapters;

extern fn sfCreateSurfaceWin32(device: *Device, desc: SurfaceWin32Desc) callconv(@"callconv") *Surface;
pub const createSurfaceWin32 = sfCreateSurfaceWin32;

extern fn sfCreateSurfaceXlib(device: *Device, desc: SurfaceXlibDesc) callconv(@"callconv") *Surface;
pub const createSurfaceXlib = sfCreateSurfaceXlib;

extern fn sfDestroySurface(surface: *Surface) callconv(@"callconv") void;
pub const destroySurface = sfDestroySurface;

extern fn sfSurfaceSupportedUsage(device: *Device, surface: *Surface) callconv(@"callconv") TextureUsage;
pub const surfaceSupportedUsage = sfSurfaceSupportedUsage;

extern fn sfSurfaceFormats(device: *Device, surface: *Surface, formats_capacity: usize, formats: ?[*]Format, format_count: *usize) callconv(@"callconv") void;
pub const surfaceFormats = sfSurfaceFormats;

extern fn sfSurfacePresentModes(device: *Device, surface: *Surface, present_modes_capacity: usize, present_modes: ?[*]PresentMode, present_mode_count: *usize) callconv(@"callconv") void;
pub const surfacePresentModes = sfSurfacePresentModes;

extern fn sfCreateDevice(instance: *Instance, adapter: *Adapter) callconv(@"callconv") *Device;
pub const createDevice = sfCreateDevice;

extern fn sfDestroyDevice(device: *Device) callconv(@"callconv") void;
pub const destroyDevice = sfDestroyDevice;

extern fn sfDeviceToHostPointer(device: *Device, address: DeviceAddress) callconv(@"callconv") *anyopaque;
pub const deviceToHostPointer = sfDeviceToHostPointer;

extern fn sfMalloc(device: *Device, size: usize, alignment: usize, memory: Memory) callconv(@"callconv") DeviceAddress;
pub const malloc = sfMalloc;

extern fn sfFree(device: *Device, address: DeviceAddress) callconv(@"callconv") void;
pub const free = sfFree;

extern fn sfDescriptorSizeAndHeapAlign(device: *Device) callconv(@"callconv") SizeAndAlign;
pub const descriptorSizeAndHeapAlign = sfDescriptorSizeAndHeapAlign;

extern fn sfStoreDescriptor(descriptor: *const Descriptor, device: *Device, heap: [*]u8, index: usize) callconv(@"callconv") void;
pub const storeDescriptor = sfStoreDescriptor;

extern fn sfCreateQueue(device: *Device, queue_type: QueueType) callconv(@"callconv") *Queue;
pub const createQueue = sfCreateQueue;

extern fn sfStartCommandRecording(queue: *Queue) callconv(@"callconv") *CommandBuffer;
pub const startCommandRecording = sfStartCommandRecording;

extern fn sfSubmit(queue: *Queue, command_buffer_count: usize, command_buffers: [*]const *CommandBuffer) callconv(@"callconv") void;
pub const submit = sfSubmit;

extern fn sfSubmitAndSignal(queue: *Queue, command_buffer_count: usize, command_buffers: [*]const *CommandBuffer, signal_semaphore: *Semaphore, signal_value: u64) callconv(@"callconv") void;
pub const submitAndSignal = sfSubmitAndSignal;

extern fn sfCreateSemaphore(device: *Device, initial_value: u64) callconv(@"callconv") *Semaphore;
pub const createSemaphore = sfCreateSemaphore;

extern fn sfDestroySemaphore(semaphore: *Semaphore) callconv(@"callconv") void;
pub const destroySemaphore = sfDestroySemaphore;

extern fn sfWaitSemaphore(semaphore: *Semaphore, value: u64) callconv(@"callconv") void;
pub const waitSemaphore = sfWaitSemaphore;

extern fn sfCreateSwapchain(queue: *Queue, surface: *Surface, desc: SwapchainDesc) callconv(@"callconv") *Swapchain;
pub const createSwapchain = sfCreateSwapchain;

extern fn sfDestroySwapchain(swapchain: *Swapchain) callconv(@"callconv") void;
pub const destroySwapchain = sfDestroySwapchain;

extern fn sfSwapchainAcquireNextTexture(swapchain: *Swapchain, queue: *Queue, width: u32, height: u32) callconv(@"callconv") *Texture;
pub const swapchainAcquireNextTexture = sfSwapchainAcquireNextTexture;

extern fn sfSwapchainPresent(swapchain: *Swapchain, queue: *Queue, semaphore: *Semaphore, semaphore_value: u64) callconv(@"callconv") void;
pub const swapchainPresent = sfSwapchainPresent;

extern fn sfSetActiveTextureHeap(command_buffer: *CommandBuffer, heap_address: DeviceAddress) callconv(@"callconv") void;
pub const setActiveTextureHeap = sfSetActiveTextureHeap;

extern fn sfSetPipeline(command_buffer: *CommandBuffer, pipeline: *Pipeline) callconv(@"callconv") void;
pub const setPipeline = sfSetPipeline;

extern fn sfDispatch(command_buffer: *CommandBuffer, data: DeviceAddress, x: u32, y: u32, z: u32) callconv(@"callconv") void;
pub const dispatch = sfDispatch;

extern fn sfBarrier(command_buffer: *CommandBuffer, before: Stage, after: Stage, hazard: Hazard) callconv(@"callconv") void;
pub const barrier = sfBarrier;

/// 256 bytes is a typical optimal alignment for destination
extern fn sfCopyTextureToBuffer(command_buffer: *CommandBuffer, source: DeviceAddress, destination: DeviceAddress, texture: *Texture) callconv(@"callconv") void;
pub const copyTextureToBuffer = sfCopyTextureToBuffer;

extern fn sfCopyBufferToTexture(command_buffer: *CommandBuffer, source: DeviceAddress, destination: DeviceAddress, texture: *Texture) callconv(@"callconv") void;
pub const copyBufferToTexture = sfCopyBufferToTexture;

extern fn sfBeginRenderPass(command_buffer: *CommandBuffer, desc: RenderPassDesc) callconv(@"callconv") void;
pub const beginRenderPass = sfBeginRenderPass;

extern fn sfEndRenderPass(command_buffer: *CommandBuffer) callconv(@"callconv") void;
pub const endRenderPass = sfEndRenderPass;

extern fn sfDraw(command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, vertex_count: u32, instance_count: u32) callconv(@"callconv") void;
pub const draw = sfDraw;

extern fn sfDrawIndexed(command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, index_count: u32) callconv(@"callconv") void;
pub const drawIndexed = sfDrawIndexed;

extern fn sfDrawIndexedInstanced(command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, index_count: u32, instance_count: u32) callconv(@"callconv") void;
pub const drawIndexedInstanced = sfDrawIndexedInstanced;

extern fn sfDrawIndexedInstancedIndirect(command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, arguments: DeviceAddress) callconv(@"callconv") void;
pub const drawIndexedInstancedIndirect = sfDrawIndexedInstancedIndirect;

extern fn sfTextureSizeAndAlign(device: *Device, desc: TextureDesc) callconv(@"callconv") SizeAndAlign;
pub const textureSizeAndAlign = sfTextureSizeAndAlign;

extern fn sfCreateTexture(device: *Device, desc: TextureDesc, data: DeviceAddress) callconv(@"callconv") *Texture;
pub const createTexture = sfCreateTexture;

extern fn sfDestroyTexture(texture: *Texture) callconv(@"callconv") void;
pub const destroyTexture = sfDestroyTexture;

extern fn sfTextureStorageDescriptor(texture: *Texture, desc: TextureViewDesc) callconv(@"callconv") Descriptor;
pub const textureStorageDescriptor = sfTextureStorageDescriptor;

extern fn sfTextureViewDescriptor(texture: *Texture, desc: TextureViewDesc) callconv(@"callconv") Descriptor;
pub const textureViewDescriptor = sfTextureViewDescriptor;

extern fn sfCreateComputePipeline(device: *Device, ir_size: usize, ir: [*]const u8) callconv(@"callconv") *Pipeline;
pub const createComputePipeline = sfCreateComputePipeline;

extern fn sfCreateGraphicsPipeline(device: *Device, vertex_ir_size: usize, vertex_ir: [*]const u8, pixel_ir_size: usize, pixel_ir: [*]const u8, desc: GraphicsPipelineDesc) callconv(@"callconv") *Pipeline;
pub const createGraphicsPipeline = sfCreateGraphicsPipeline;

extern fn sfDestroyPipeline(pipeline: *Pipeline) callconv(@"callconv") void;
pub const destroyPipeline = sfDestroyPipeline;
