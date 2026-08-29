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
pub const Symbol = *const fn (name: [*:0]const u8) callconv(@"callconv") ?*const anyopaque;

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
    clear_color: [4]f32 = @splat(0.0),
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

const internal = struct {
    inline fn table(handle: *const anyopaque) [*]const *const anyopaque {
        return @as(*const [*]const *const anyopaque, @ptrCast(@alignCast(handle))).*;
    }

    var create_instance: ?*const fn (allocator: ?*Allocator) callconv(@"callconv") *Instance = null;
    var destroy_instance: ?*const fn (instance: *Instance) callconv(@"callconv") void = null;
    var get_slot: ?*const fn (instance: *Instance, name: [*:0]const u8) callconv(@"callconv") usize = null;
    var enumerate_adapters: ?*const fn (instance: *Instance, adapters_capacity: usize, adapters: ?[*]*Adapter, adapter_count: *usize) callconv(@"callconv") void = null;
    var create_device: ?*const fn (instance: *Instance, adapter: *Adapter) callconv(@"callconv") *Device = null;
    var destroy_device: ?*const fn (device: *Device) callconv(@"callconv") void = null;

    var slots: struct {
        create_surface_win32: usize = 0,
        create_surface_xlib: usize = 0,
        destroy_surface: usize = 0,
        surface_supported_usage: usize = 0,
        surface_formats: usize = 0,
        surface_present_modes: usize = 0,
        device_to_host_pointer: usize = 0,
        malloc: usize = 0,
        free: usize = 0,
        descriptor_size_and_heap_align: usize = 0,
        store_descriptor: usize = 0,
        create_queue: usize = 0,
        start_command_recording: usize = 0,
        submit: usize = 0,
        submit_and_signal: usize = 0,
        create_semaphore: usize = 0,
        destroy_semaphore: usize = 0,
        wait_semaphore: usize = 0,
        create_swapchain: usize = 0,
        destroy_swapchain: usize = 0,
        swapchain_acquire_next_texture: usize = 0,
        swapchain_present: usize = 0,
        set_active_texture_heap: usize = 0,
        set_pipeline: usize = 0,
        dispatch: usize = 0,
        barrier: usize = 0,
        copy_texture_to_buffer: usize = 0,
        copy_buffer_to_texture: usize = 0,
        begin_render_pass: usize = 0,
        end_render_pass: usize = 0,
        draw: usize = 0,
        draw_indexed: usize = 0,
        draw_indexed_instanced: usize = 0,
        draw_indexed_instanced_indirect: usize = 0,
        texture_size_and_align: usize = 0,
        create_texture: usize = 0,
        destroy_texture: usize = 0,
        texture_storage_descriptor: usize = 0,
        texture_view_descriptor: usize = 0,
        create_compute_pipeline: usize = 0,
        create_graphics_pipeline: usize = 0,
        destroy_pipeline: usize = 0,
    } = .{};

    fn loadGlobals(getSymbol: Symbol) void {
        create_instance = @ptrCast(getSymbol("sfCreateInstance"));
        destroy_instance = @ptrCast(getSymbol("sfDestroyInstance"));
        get_slot = @ptrCast(getSymbol("sfGetSlot"));
        enumerate_adapters = @ptrCast(getSymbol("sfEnumerateAdapters"));
        create_device = @ptrCast(getSymbol("sfCreateDevice"));
        destroy_device = @ptrCast(getSymbol("sfDestroyDevice"));
    }

    fn loadSlots(instance: *Instance) void {
        slots.create_surface_win32 = get_slot.?(instance, "sfCreateSurfaceWin32");
        slots.create_surface_xlib = get_slot.?(instance, "sfCreateSurfaceXlib");
        slots.destroy_surface = get_slot.?(instance, "sfDestroySurface");
        slots.surface_supported_usage = get_slot.?(instance, "sfSurfaceSupportedUsage");
        slots.surface_formats = get_slot.?(instance, "sfSurfaceFormats");
        slots.surface_present_modes = get_slot.?(instance, "sfSurfacePresentModes");
        slots.device_to_host_pointer = get_slot.?(instance, "sfDeviceToHostPointer");
        slots.malloc = get_slot.?(instance, "sfMalloc");
        slots.free = get_slot.?(instance, "sfFree");
        slots.descriptor_size_and_heap_align = get_slot.?(instance, "sfDescriptorSizeAndHeapAlign");
        slots.store_descriptor = get_slot.?(instance, "sfStoreDescriptor");
        slots.create_queue = get_slot.?(instance, "sfCreateQueue");
        slots.start_command_recording = get_slot.?(instance, "sfStartCommandRecording");
        slots.submit = get_slot.?(instance, "sfSubmit");
        slots.submit_and_signal = get_slot.?(instance, "sfSubmitAndSignal");
        slots.create_semaphore = get_slot.?(instance, "sfCreateSemaphore");
        slots.destroy_semaphore = get_slot.?(instance, "sfDestroySemaphore");
        slots.wait_semaphore = get_slot.?(instance, "sfWaitSemaphore");
        slots.create_swapchain = get_slot.?(instance, "sfCreateSwapchain");
        slots.destroy_swapchain = get_slot.?(instance, "sfDestroySwapchain");
        slots.swapchain_acquire_next_texture = get_slot.?(instance, "sfSwapchainAcquireNextTexture");
        slots.swapchain_present = get_slot.?(instance, "sfSwapchainPresent");
        slots.set_active_texture_heap = get_slot.?(instance, "sfSetActiveTextureHeap");
        slots.set_pipeline = get_slot.?(instance, "sfSetPipeline");
        slots.dispatch = get_slot.?(instance, "sfDispatch");
        slots.barrier = get_slot.?(instance, "sfBarrier");
        slots.copy_texture_to_buffer = get_slot.?(instance, "sfCopyTextureToBuffer");
        slots.copy_buffer_to_texture = get_slot.?(instance, "sfCopyBufferToTexture");
        slots.begin_render_pass = get_slot.?(instance, "sfBeginRenderPass");
        slots.end_render_pass = get_slot.?(instance, "sfEndRenderPass");
        slots.draw = get_slot.?(instance, "sfDraw");
        slots.draw_indexed = get_slot.?(instance, "sfDrawIndexed");
        slots.draw_indexed_instanced = get_slot.?(instance, "sfDrawIndexedInstanced");
        slots.draw_indexed_instanced_indirect = get_slot.?(instance, "sfDrawIndexedInstancedIndirect");
        slots.texture_size_and_align = get_slot.?(instance, "sfTextureSizeAndAlign");
        slots.create_texture = get_slot.?(instance, "sfCreateTexture");
        slots.destroy_texture = get_slot.?(instance, "sfDestroyTexture");
        slots.texture_storage_descriptor = get_slot.?(instance, "sfTextureStorageDescriptor");
        slots.texture_view_descriptor = get_slot.?(instance, "sfTextureViewDescriptor");
        slots.create_compute_pipeline = get_slot.?(instance, "sfCreateComputePipeline");
        slots.create_graphics_pipeline = get_slot.?(instance, "sfCreateGraphicsPipeline");
        slots.destroy_pipeline = get_slot.?(instance, "sfDestroyPipeline");
    }
};

pub fn createInstance(allocator: ?*Allocator, getSymbol: Symbol) *Instance {
    internal.loadGlobals(getSymbol);
    const f = internal.create_instance.?;
    const instance = f(allocator);
    internal.loadSlots(instance);
    return instance;
}

pub fn destroyInstance(instance: *Instance) void {
    const f = internal.destroy_instance.?;
    return f(instance);
}

pub fn enumerateAdapters(instance: *Instance, adapters_capacity: usize, adapters: ?[*]*Adapter, adapter_count: *usize) void {
    const f = internal.enumerate_adapters.?;
    return f(instance, adapters_capacity, adapters, adapter_count);
}

pub fn createDevice(instance: *Instance, adapter: *Adapter) *Device {
    const f = internal.create_device.?;
    return f(instance, adapter);
}

pub fn destroyDevice(device: *Device) void {
    const f = internal.destroy_device.?;
    return f(device);
}

pub fn createSurfaceWin32(device: *Device, desc: SurfaceWin32Desc) *Surface {
    const f: *const fn (device: *Device, desc: SurfaceWin32Desc) callconv(@"callconv") *Surface = @ptrCast(internal.table(device)[internal.slots.create_surface_win32]);
    return f(device, desc);
}

pub fn createSurfaceXlib(device: *Device, desc: SurfaceXlibDesc) *Surface {
    const f: *const fn (device: *Device, desc: SurfaceXlibDesc) callconv(@"callconv") *Surface = @ptrCast(internal.table(device)[internal.slots.create_surface_xlib]);
    return f(device, desc);
}

pub fn destroySurface(surface: *Surface) void {
    const f: *const fn (surface: *Surface) callconv(@"callconv") void = @ptrCast(internal.table(surface)[internal.slots.destroy_surface]);
    return f(surface);
}

pub fn surfaceSupportedUsage(device: *Device, surface: *Surface) TextureUsage {
    const f: *const fn (device: *Device, surface: *Surface) callconv(@"callconv") TextureUsage = @ptrCast(internal.table(device)[internal.slots.surface_supported_usage]);
    return f(device, surface);
}

pub fn surfaceFormats(device: *Device, surface: *Surface, formats_capacity: usize, formats: ?[*]Format, format_count: *usize) void {
    const f: *const fn (device: *Device, surface: *Surface, formats_capacity: usize, formats: ?[*]Format, format_count: *usize) callconv(@"callconv") void = @ptrCast(internal.table(device)[internal.slots.surface_formats]);
    return f(device, surface, formats_capacity, formats, format_count);
}

pub fn surfacePresentModes(device: *Device, surface: *Surface, present_modes_capacity: usize, present_modes: ?[*]PresentMode, present_mode_count: *usize) void {
    const f: *const fn (device: *Device, surface: *Surface, present_modes_capacity: usize, present_modes: ?[*]PresentMode, present_mode_count: *usize) callconv(@"callconv") void = @ptrCast(internal.table(device)[internal.slots.surface_present_modes]);
    return f(device, surface, present_modes_capacity, present_modes, present_mode_count);
}

pub fn deviceToHostPointer(device: *Device, address: DeviceAddress) *anyopaque {
    const f: *const fn (device: *Device, address: DeviceAddress) callconv(@"callconv") *anyopaque = @ptrCast(internal.table(device)[internal.slots.device_to_host_pointer]);
    return f(device, address);
}

pub fn malloc(device: *Device, size: usize, alignment: usize, memory: Memory) DeviceAddress {
    const f: *const fn (device: *Device, size: usize, alignment: usize, memory: Memory) callconv(@"callconv") DeviceAddress = @ptrCast(internal.table(device)[internal.slots.malloc]);
    return f(device, size, alignment, memory);
}

pub fn free(device: *Device, address: DeviceAddress) void {
    const f: *const fn (device: *Device, address: DeviceAddress) callconv(@"callconv") void = @ptrCast(internal.table(device)[internal.slots.free]);
    return f(device, address);
}

pub fn descriptorSizeAndHeapAlign(device: *Device) SizeAndAlign {
    const f: *const fn (device: *Device) callconv(@"callconv") SizeAndAlign = @ptrCast(internal.table(device)[internal.slots.descriptor_size_and_heap_align]);
    return f(device);
}

pub fn storeDescriptor(device: *Device, descriptor: *const Descriptor, heap: [*]u8, index: usize) void {
    const f: *const fn (device: *Device, descriptor: *const Descriptor, heap: [*]u8, index: usize) callconv(@"callconv") void = @ptrCast(internal.table(device)[internal.slots.store_descriptor]);
    return f(device, descriptor, heap, index);
}

pub fn createQueue(device: *Device, queue_type: QueueType) *Queue {
    const f: *const fn (device: *Device, queue_type: QueueType) callconv(@"callconv") *Queue = @ptrCast(internal.table(device)[internal.slots.create_queue]);
    return f(device, queue_type);
}

pub fn startCommandRecording(queue: *Queue) *CommandBuffer {
    const f: *const fn (queue: *Queue) callconv(@"callconv") *CommandBuffer = @ptrCast(internal.table(queue)[internal.slots.start_command_recording]);
    return f(queue);
}

pub fn submit(queue: *Queue, command_buffer_count: usize, command_buffers: [*]const *CommandBuffer) void {
    const f: *const fn (queue: *Queue, command_buffer_count: usize, command_buffers: [*]const *CommandBuffer) callconv(@"callconv") void = @ptrCast(internal.table(queue)[internal.slots.submit]);
    return f(queue, command_buffer_count, command_buffers);
}

pub fn submitAndSignal(queue: *Queue, command_buffer_count: usize, command_buffers: [*]const *CommandBuffer, signal_semaphore: *Semaphore, signal_value: u64) void {
    const f: *const fn (queue: *Queue, command_buffer_count: usize, command_buffers: [*]const *CommandBuffer, signal_semaphore: *Semaphore, signal_value: u64) callconv(@"callconv") void = @ptrCast(internal.table(queue)[internal.slots.submit_and_signal]);
    return f(queue, command_buffer_count, command_buffers, signal_semaphore, signal_value);
}

pub fn createSemaphore(device: *Device, initial_value: u64) *Semaphore {
    const f: *const fn (device: *Device, initial_value: u64) callconv(@"callconv") *Semaphore = @ptrCast(internal.table(device)[internal.slots.create_semaphore]);
    return f(device, initial_value);
}

pub fn destroySemaphore(semaphore: *Semaphore) void {
    const f: *const fn (semaphore: *Semaphore) callconv(@"callconv") void = @ptrCast(internal.table(semaphore)[internal.slots.destroy_semaphore]);
    return f(semaphore);
}

pub fn waitSemaphore(semaphore: *Semaphore, value: u64) void {
    const f: *const fn (semaphore: *Semaphore, value: u64) callconv(@"callconv") void = @ptrCast(internal.table(semaphore)[internal.slots.wait_semaphore]);
    return f(semaphore, value);
}

pub fn createSwapchain(queue: *Queue, surface: *Surface, desc: SwapchainDesc) *Swapchain {
    const f: *const fn (queue: *Queue, surface: *Surface, desc: SwapchainDesc) callconv(@"callconv") *Swapchain = @ptrCast(internal.table(queue)[internal.slots.create_swapchain]);
    return f(queue, surface, desc);
}

pub fn destroySwapchain(swapchain: *Swapchain) void {
    const f: *const fn (swapchain: *Swapchain) callconv(@"callconv") void = @ptrCast(internal.table(swapchain)[internal.slots.destroy_swapchain]);
    return f(swapchain);
}

pub fn swapchainAcquireNextTexture(swapchain: *Swapchain, queue: *Queue, width: u32, height: u32) *Texture {
    const f: *const fn (swapchain: *Swapchain, queue: *Queue, width: u32, height: u32) callconv(@"callconv") *Texture = @ptrCast(internal.table(swapchain)[internal.slots.swapchain_acquire_next_texture]);
    return f(swapchain, queue, width, height);
}

pub fn swapchainPresent(swapchain: *Swapchain, queue: *Queue, semaphore: *Semaphore, semaphore_value: u64) void {
    const f: *const fn (swapchain: *Swapchain, queue: *Queue, semaphore: *Semaphore, semaphore_value: u64) callconv(@"callconv") void = @ptrCast(internal.table(swapchain)[internal.slots.swapchain_present]);
    return f(swapchain, queue, semaphore, semaphore_value);
}

pub fn setActiveTextureHeap(command_buffer: *CommandBuffer, heap_address: DeviceAddress) void {
    const f: *const fn (command_buffer: *CommandBuffer, heap_address: DeviceAddress) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.set_active_texture_heap]);
    return f(command_buffer, heap_address);
}

pub fn setPipeline(command_buffer: *CommandBuffer, pipeline: *Pipeline) void {
    const f: *const fn (command_buffer: *CommandBuffer, pipeline: *Pipeline) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.set_pipeline]);
    return f(command_buffer, pipeline);
}

pub fn dispatch(command_buffer: *CommandBuffer, data: DeviceAddress, x: u32, y: u32, z: u32) void {
    const f: *const fn (command_buffer: *CommandBuffer, data: DeviceAddress, x: u32, y: u32, z: u32) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.dispatch]);
    return f(command_buffer, data, x, y, z);
}

pub fn barrier(command_buffer: *CommandBuffer, before: Stage, after: Stage, hazard: Hazard) void {
    const f: *const fn (command_buffer: *CommandBuffer, before: Stage, after: Stage, hazard: Hazard) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.barrier]);
    return f(command_buffer, before, after, hazard);
}

/// 256 bytes is a typical optimal alignment for destination
pub fn copyTextureToBuffer(command_buffer: *CommandBuffer, source: DeviceAddress, destination: DeviceAddress, texture: *Texture) void {
    const f: *const fn (command_buffer: *CommandBuffer, source: DeviceAddress, destination: DeviceAddress, texture: *Texture) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.copy_texture_to_buffer]);
    return f(command_buffer, source, destination, texture);
}

pub fn copyBufferToTexture(command_buffer: *CommandBuffer, source: DeviceAddress, destination: DeviceAddress, texture: *Texture) void {
    const f: *const fn (command_buffer: *CommandBuffer, source: DeviceAddress, destination: DeviceAddress, texture: *Texture) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.copy_buffer_to_texture]);
    return f(command_buffer, source, destination, texture);
}

pub fn beginRenderPass(command_buffer: *CommandBuffer, desc: RenderPassDesc) void {
    const f: *const fn (command_buffer: *CommandBuffer, desc: RenderPassDesc) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.begin_render_pass]);
    return f(command_buffer, desc);
}

pub fn endRenderPass(command_buffer: *CommandBuffer) void {
    const f: *const fn (command_buffer: *CommandBuffer) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.end_render_pass]);
    return f(command_buffer);
}

pub fn draw(command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, vertex_count: u32, instance_count: u32) void {
    const f: *const fn (command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, vertex_count: u32, instance_count: u32) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.draw]);
    return f(command_buffer, vertex_data, pixel_data, vertex_count, instance_count);
}

pub fn drawIndexed(command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, index_count: u32) void {
    const f: *const fn (command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, index_count: u32) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.draw_indexed]);
    return f(command_buffer, vertex_data, pixel_data, index_type, indices, index_count);
}

pub fn drawIndexedInstanced(command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, index_count: u32, instance_count: u32) void {
    const f: *const fn (command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, index_count: u32, instance_count: u32) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.draw_indexed_instanced]);
    return f(command_buffer, vertex_data, pixel_data, index_type, indices, index_count, instance_count);
}

pub fn drawIndexedInstancedIndirect(command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, arguments: DeviceAddress) void {
    const f: *const fn (command_buffer: *CommandBuffer, vertex_data: DeviceAddress, pixel_data: DeviceAddress, index_type: IndexType, indices: DeviceAddress, arguments: DeviceAddress) callconv(@"callconv") void = @ptrCast(internal.table(command_buffer)[internal.slots.draw_indexed_instanced_indirect]);
    return f(command_buffer, vertex_data, pixel_data, index_type, indices, arguments);
}

pub fn textureSizeAndAlign(device: *Device, desc: TextureDesc) SizeAndAlign {
    const f: *const fn (device: *Device, desc: TextureDesc) callconv(@"callconv") SizeAndAlign = @ptrCast(internal.table(device)[internal.slots.texture_size_and_align]);
    return f(device, desc);
}

pub fn createTexture(device: *Device, desc: TextureDesc, data: DeviceAddress) *Texture {
    const f: *const fn (device: *Device, desc: TextureDesc, data: DeviceAddress) callconv(@"callconv") *Texture = @ptrCast(internal.table(device)[internal.slots.create_texture]);
    return f(device, desc, data);
}

pub fn destroyTexture(texture: *Texture) void {
    const f: *const fn (texture: *Texture) callconv(@"callconv") void = @ptrCast(internal.table(texture)[internal.slots.destroy_texture]);
    return f(texture);
}

pub fn textureStorageDescriptor(texture: *Texture, desc: TextureViewDesc) Descriptor {
    const f: *const fn (texture: *Texture, desc: TextureViewDesc) callconv(@"callconv") Descriptor = @ptrCast(internal.table(texture)[internal.slots.texture_storage_descriptor]);
    return f(texture, desc);
}

pub fn textureViewDescriptor(texture: *Texture, desc: TextureViewDesc) Descriptor {
    const f: *const fn (texture: *Texture, desc: TextureViewDesc) callconv(@"callconv") Descriptor = @ptrCast(internal.table(texture)[internal.slots.texture_view_descriptor]);
    return f(texture, desc);
}

pub fn createComputePipeline(device: *Device, ir_size: usize, ir: [*]const u8) *Pipeline {
    const f: *const fn (device: *Device, ir_size: usize, ir: [*]const u8) callconv(@"callconv") *Pipeline = @ptrCast(internal.table(device)[internal.slots.create_compute_pipeline]);
    return f(device, ir_size, ir);
}

pub fn createGraphicsPipeline(device: *Device, vertex_ir_size: usize, vertex_ir: [*]const u8, pixel_ir_size: usize, pixel_ir: [*]const u8, desc: GraphicsPipelineDesc) *Pipeline {
    const f: *const fn (device: *Device, vertex_ir_size: usize, vertex_ir: [*]const u8, pixel_ir_size: usize, pixel_ir: [*]const u8, desc: GraphicsPipelineDesc) callconv(@"callconv") *Pipeline = @ptrCast(internal.table(device)[internal.slots.create_graphics_pipeline]);
    return f(device, vertex_ir_size, vertex_ir, pixel_ir_size, pixel_ir, desc);
}

pub fn destroyPipeline(pipeline: *Pipeline) void {
    const f: *const fn (pipeline: *Pipeline) callconv(@"callconv") void = @ptrCast(internal.table(pipeline)[internal.slots.destroy_pipeline]);
    return f(pipeline);
}
