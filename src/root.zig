pub const Instance = struct {
    instance: vk.InstanceProxy,

    pub fn create(
        gpa: std.mem.Allocator,
        proc: vk.PfnGetInstanceProcAddr,
        required_surface_extensions: []const [*:0]const u8,
    ) !Instance {
        var arena_impl: std.heap.ArenaAllocator = .init(gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const base_dispatch: vk.BaseWrapper = .load(proc);

        const available_extensions = try base_dispatch.enumerateInstanceExtensionPropertiesAlloc(null, arena);
        for (required_surface_extensions) |required_ext| {
            for (available_extensions) |available_ext| {
                if (std.mem.eql(u8, std.mem.span(required_ext), std.mem.sliceTo(&available_ext.extension_name, 0))) break;
            } else return error.RequiredSurfaceExtensionNotAvailable;
        }

        const validation_layer = "VK_LAYER_KHRONOS_validation";

        const enable_validation_layers = true; // TODO: enable from build.zig

        if (enable_validation_layers) {
            const available_layers = try base_dispatch.enumerateInstanceLayerPropertiesAlloc(arena);
            for (available_layers) |available_layer| {
                if (std.mem.eql(u8, std.mem.sliceTo(&available_layer.layer_name, 0), validation_layer)) break;
            } else std.debug.panic("validation layers unsupported", .{});
        }

        var extensions: std.ArrayList([*:0]const u8) = .empty;
        try extensions.appendSlice(arena, @ptrCast(required_surface_extensions));
        try extensions.append(arena, vk.extensions.ext_debug_utils.name.ptr);

        const create_info: vk.InstanceCreateInfo = .{
            .p_application_info = &.{
                .p_application_name = "Vulkan Tutorial",
                .application_version = vk.makeApiVersion(1, 0, 0, 0).toU32(),
                .p_engine_name = "No Engine",
                .engine_version = vk.makeApiVersion(1, 0, 0, 0).toU32(),
                .api_version = vk.makeApiVersion(1, 3, 0, 0).toU32(),
            },
            .enabled_extension_count = @intCast(extensions.items.len),
            .pp_enabled_extension_names = extensions.items.ptr,
            .pp_enabled_layer_names = if (enable_validation_layers) &.{validation_layer} else null,
            .enabled_layer_count = if (enable_validation_layers) 1 else 0,
        };
        const instance_handle = try base_dispatch.createInstance(&create_info, null);

        const instance_dispatch = try gpa.create(vk.InstanceWrapper);
        instance_dispatch.* = .load(instance_handle, base_dispatch.dispatch.vkGetInstanceProcAddr.?);
        const instance: vk.InstanceProxy = .init(instance_handle, instance_dispatch);
        return .{ .instance = instance };
    }

    pub fn destroy(instance: Instance, gpa: std.mem.Allocator) void {
        instance.instance.destroyInstance(null);
        gpa.destroy(instance.instance.wrapper);
    }
};

pub const Adapter = struct {
    physical_device: vk.PhysicalDevice,
};

pub fn enumerateAdapters(gpa: std.mem.Allocator, instance: Instance) ![]Adapter {
    const physical_devices = try instance.instance.enumeratePhysicalDevicesAlloc(gpa);
    defer gpa.free(physical_devices);
    const adapters = try gpa.alloc(Adapter, physical_devices.len);
    for (adapters, physical_devices) |*adapter, physical_device| adapter.* = .{ .physical_device = physical_device };
    return adapters;
}

pub const Device = struct {
    instance: vk.InstanceProxy,
    device: vk.DeviceProxy,
    physical_device: vk.PhysicalDevice,

    queue_families: QueueFamilies,

    debug_messenger: vk.DebugUtilsMessengerEXT,
    gpa: std.mem.Allocator,

    pub fn create(
        gpa: std.mem.Allocator,
        instance: Instance,
        adapter: Adapter,
    ) !Device {
        var arena_impl: std.heap.ArenaAllocator = .init(gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const device_handle = try createLogicalDevice(arena, adapter.physical_device, instance.instance.wrapper);
        const device_dispatch = try gpa.create(vk.DeviceWrapper);
        device_dispatch.* = .load(device_handle, instance.instance.wrapper.dispatch.vkGetDeviceProcAddr.?);
        const device: vk.DeviceProxy = .init(device_handle, device_dispatch);

        const debug_callback = struct {
            fn debugCallback(
                message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
                message_types: vk.DebugUtilsMessageTypeFlagsEXT,
                p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
                p_user_data: ?*anyopaque,
            ) callconv(vk.vulkan_call_conv) vk.Bool32 {
                _ = .{ message_types, p_user_data };
                const callback_data = p_callback_data orelse @panic("");
                const message = std.mem.span(callback_data.p_message orelse "no message");
                if (message_severity.error_bit_ext) {
                    std.log.err("Validation: {s}", .{message});
                } else if (message_severity.warning_bit_ext) {
                    std.log.warn("Validation: {s}", .{message});
                } else {
                    std.log.info("Validation: {s}", .{message});
                }
                std.debug.dumpCurrentStackTrace(.{});
                return .false;
            }
        };
        const debug_messenger_info: vk.DebugUtilsMessengerCreateInfoEXT = .{
            .message_severity = .{ .verbose_bit_ext = true, .warning_bit_ext = true, .error_bit_ext = true },
            .message_type = .{ .general_bit_ext = true, .validation_bit_ext = true, .performance_bit_ext = true },
            .pfn_user_callback = debug_callback.debugCallback,
        };
        const debug_messenger = try instance.instance.createDebugUtilsMessengerEXT(&debug_messenger_info, null);

        return .{
            .instance = instance.instance,
            .device = device,
            .queue_families = try findQueueFamilies(arena, adapter.physical_device, instance.instance.wrapper),
            .debug_messenger = debug_messenger,
            .physical_device = adapter.physical_device,
            .gpa = gpa,
        };
    }

    pub fn destroy(self: Device) void {
        self.device.deviceWaitIdle() catch {};
        self.device.destroyDevice(null);
        self.gpa.destroy(self.device.wrapper);
        self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger, null);
    }

    pub fn surfaceCapabilities(d: Device, gpa: std.mem.Allocator, surface: vk.SurfaceKHR) !SurfaceCapabilities {
        var arena_impl: std.heap.ArenaAllocator = .init(d.gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const vk_formats = try d.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(d.physical_device, surface, arena);
        var formats: std.ArrayList(Format) = try .initCapacity(arena, vk_formats.len);
        errdefer formats.deinit(gpa);
        for (vk_formats) |vk_format| formats.appendAssumeCapacity(vk_to_gpu.format(vk_format.format) orelse continue);

        const vk_modes = try d.instance.getPhysicalDeviceSurfacePresentModesAllocKHR(d.physical_device, surface, arena);
        var modes: std.ArrayList(PresentMode) = try .initCapacity(arena, vk_modes.len);
        errdefer modes.deinit(gpa);
        for (vk_modes) |vk_mode| modes.appendAssumeCapacity(vk_to_gpu.presentMode(vk_mode) orelse continue);

        const vk_capabilities = try d.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(d.physical_device, surface);
        return .{
            .usages = vk_to_gpu.usageFlags(vk_capabilities.supported_usage_flags),
            .formats = try gpa.dupe(Format, formats.items),
            .present_modes = try gpa.dupe(PresentMode, modes.items),
        };
    }

    pub fn rawAlloc(
        d: Device,
        bytes: usize,
        alignment: std.mem.Alignment,
        memory: Memory,
    ) !*anyopaque {
        const usage: vk.BufferUsageFlags = switch (memory) {
            .default => .{
                .storage_buffer_bit = true,
                .index_buffer_bit = true,
                .indirect_buffer_bit = true,
                .transfer_src_bit = true,
                .shader_device_address_bit = true,
            },
            .gpu => .{
                .storage_buffer_bit = true,
                .index_buffer_bit = true,
                .indirect_buffer_bit = true,
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
                .shader_device_address_bit = true,
            },
            .readback => .{
                .storage_buffer_bit = true,
                .transfer_dst_bit = true,
                .shader_device_address_bit = true,
            },
        };

        const info: vk.BufferCreateInfo = .{
            .size = bytes,
            .usage = usage,
            .sharing_mode = .exclusive, // TODO: exclusive or concurrent?
        };
        const buffer = try d.device.createBuffer(&info, null);

        const buffer_memory_requirements = d.device.getBufferMemoryRequirements(buffer);

        // TODO: cache this
        const color_bits = probeImageMemoryTypeBits(d, .r8g8b8a8_unorm, .{ .sampled_bit = true, .transfer_dst_bit = true, .color_attachment_bit = true });
        const depth_bits = probeImageMemoryTypeBits(d, .d32_sfloat, .{ .depth_stencil_attachment_bit = true, .sampled_bit = true });

        const memory_requirements: vk.MemoryRequirements = .{
            .size = buffer_memory_requirements.size,
            .alignment = alignment.max(.fromByteUnits(buffer_memory_requirements.alignment)).toByteUnits(),
            .memory_type_bits = switch (memory) {
                .default, .readback => buffer_memory_requirements.memory_type_bits,
                .gpu => buffer_memory_requirements.memory_type_bits & color_bits & depth_bits,
            },
        };

        const properties: vk.MemoryPropertyFlags = switch (memory) {
            .default => .{
                .device_local_bit = true, // TODO: if ReBAR is not available dont use device_local_bit
                .host_visible_bit = true,
                .host_coherent_bit = true,
            },
            .gpu => .{
                .device_local_bit = true,
            },
            .readback => .{
                .host_visible_bit = true,
                .host_cached_bit = true,
                .host_coherent_bit = true,
            },
        };
        const alloc_flags: vk.MemoryAllocateFlagsInfo = .{
            .flags = .{ .device_address_bit = true },
            .device_mask = 0,
        };
        const index = findMemoryType(d, memory_requirements.memory_type_bits, properties);
        const alloc_info: vk.MemoryAllocateInfo = .{
            .p_next = &alloc_flags,
            .allocation_size = memory_requirements.size,
            .memory_type_index = index,
        };

        const buffer_memory = try d.device.allocateMemory(&alloc_info, null);
        try d.device.bindBufferMemory(buffer, buffer_memory, 0);

        const gpu_ptr = d.device.getBufferDeviceAddress(&.{ .buffer = buffer });
        const cpu_ptr = switch (memory) {
            .readback, .default => try d.device.mapMemory(buffer_memory, 0, vk.WHOLE_SIZE, .{}),
            .gpu => null,
        };
        _ = cpu_ptr; // autofix

        // TODO:
        // return .{
        //     .buffer = buffer,
        //     .memory = buffer_memory,
        //     .size = bytes,
        //     .gpu_ptr = gpu_ptr,
        //     .cpu_ptr = cpu_ptr,
        // };

        return @ptrFromInt(gpu_ptr);
    }

    fn findMemoryType(d: Device, type_filter: u32, properties: vk.MemoryPropertyFlags) u32 {
        const mem_properties = d.instance.getPhysicalDeviceMemoryProperties(d.physical_device); // TODO: cache this
        for (0..mem_properties.memory_type_count) |i| {
            if ((type_filter & (@as(u32, 1) << @intCast(i))) != 0 and
                (mem_properties.memory_types[i].property_flags.intersect(properties)) == properties)
            {
                return @intCast(i);
            }
        }
        @panic(""); // TODO
    }

    fn probeImageMemoryTypeBits(d: Device, format: vk.Format, usage: vk.ImageUsageFlags) u32 { // TODO: cache this
        const ici: vk.ImageCreateInfo = .{
            .image_type = .@"2d",
            .format = format,
            .extent = .{ .width = 16, .height = 16, .depth = 1 },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .{ .@"1_bit" = true },
            .tiling = .optimal,
            .usage = usage,
            .sharing_mode = .exclusive,
            .initial_layout = .undefined,
        };
        var req: vk.MemoryRequirements2 = .{ .memory_requirements = undefined };
        d.device.getDeviceImageMemoryRequirements(&.{ .plane_aspect = .{}, .p_create_info = &ici }, &req);
        return req.memory_requirements.memory_type_bits;
    }
};

pub const Memory = enum(u8) {
    default,
    gpu,
    readback,
};

pub fn createLogicalDevice(
    arena: std.mem.Allocator,
    physical_device: vk.PhysicalDevice,
    instance_dispatch: *const vk.InstanceWrapper,
) !vk.Device {
    var queue_family_count: u32 = undefined;
    instance_dispatch.getPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

    const queue_infos = try arena.alloc(vk.DeviceQueueCreateInfo, queue_family_count);
    for (queue_infos, 0..) |*queue_info, i| {
        queue_info.* = .{
            .queue_family_index = @intCast(i),
            .queue_count = 1,
            .p_queue_priorities = &.{1},
        };
    }

    var device_features_vk13: vk.PhysicalDeviceVulkan13Features = .{
        .dynamic_rendering = .true,
        .synchronization_2 = .true,
    };
    var device_features_vk12: vk.PhysicalDeviceVulkan12Features = .{
        .p_next = &device_features_vk13,
        .buffer_device_address = .true,
        .runtime_descriptor_array = .true,
        .descriptor_binding_partially_bound = .true,
        .descriptor_binding_sampled_image_update_after_bind = .true,
        .descriptor_binding_storage_buffer_update_after_bind = .true,
        .scalar_block_layout = .true,
        .timeline_semaphore = .true,
        .shader_float_16 = .true,
        .shader_int_8 = .true,
        .storage_buffer_8_bit_access = .true,
        .uniform_and_storage_buffer_8_bit_access = .true,
    };
    const device_features_vk11: vk.PhysicalDeviceVulkan11Features = .{
        .p_next = &device_features_vk12,
        .shader_draw_parameters = .true,
        .storage_buffer_16_bit_access = .true,
        .uniform_and_storage_buffer_16_bit_access = .true,
    };
    const required_device_extensions = [_][*:0]const u8{vk.extensions.khr_swapchain.name};
    return try instance_dispatch.createDevice(physical_device, &.{
        .p_next = &device_features_vk11,
        .p_queue_create_infos = queue_infos.ptr,
        .queue_create_info_count = @intCast(queue_infos.len),
        .pp_enabled_extension_names = &required_device_extensions,
        .enabled_extension_count = required_device_extensions.len,
        .p_enabled_features = &.{
            .shader_int_64 = .true,
            .shader_int_16 = .true,
            .sampler_anisotropy = .true,
            .multi_draw_indirect = .true,
            // .robust_buffer_access = .true, TODO: consider
        },
    }, null);
}

pub const QueueFamilies = struct {
    graphics: u32,
    graphics_index: u32,
    compute: u32,
    compute_index: u32,
    transfer: u32,
    transfer_index: u32,
};

fn findQueueFamilies(
    arena: std.mem.Allocator,
    physical_device: vk.PhysicalDevice,
    instance_dispatch: *const vk.InstanceWrapper,
) !QueueFamilies {
    const queue_families = try instance_dispatch.getPhysicalDeviceQueueFamilyPropertiesAlloc(physical_device, arena);

    var graphics: u32 = std.math.maxInt(u32);
    for (queue_families, 0..) |family, i| {
        if (family.queue_flags.graphics_bit) {
            graphics = @intCast(i);
            break;
        }
    }

    var compute = graphics;
    for (queue_families, 0..) |family, i| {
        if (family.queue_flags.compute_bit and !family.queue_flags.graphics_bit) {
            compute = @intCast(i);
            break;
        }
    }

    var transfer = compute;
    for (queue_families, 0..) |family, i| {
        if (family.queue_flags.transfer_bit and
            !family.queue_flags.graphics_bit and
            !family.queue_flags.compute_bit)
        {
            transfer = @intCast(i);
            break;
        }
    }

    const next_index = try arena.alloc(u32, queue_families.len);
    @memset(next_index, 0);

    const local = struct {
        fn claim(idx: []u32, families: []const vk.QueueFamilyProperties, fam: u32) u32 {
            if (fam == std.math.maxInt(u32)) return std.math.maxInt(u32);
            const max = families[fam].queue_count;
            const i = @min(idx[fam], max - 1);
            idx[fam] += 1;
            return i;
        }
    };

    return .{
        .graphics = graphics,
        .graphics_index = local.claim(next_index, queue_families, graphics),
        .compute = compute,
        .compute_index = local.claim(next_index, queue_families, compute),
        .transfer = transfer,
        .transfer_index = local.claim(next_index, queue_families, transfer),
    };
}

pub const QueueType = enum {
    graphics,
    compute,
    transfer,
};

pub const Queue = struct {
    queue: vk.Queue,

    pub fn create(d: Device, @"type": QueueType) Queue {
        const queue_family, const queue_index = switch (@"type") {
            .graphics => .{ d.queue_families.graphics, d.queue_families.graphics_index },
            .compute => .{ d.queue_families.compute, d.queue_families.compute_index },
            .transfer => .{ d.queue_families.transfer, d.queue_families.transfer_index },
        };
        const queue = d.device.getDeviceQueue(queue_family, queue_index);
        return .{ .queue = queue };
    }
};

pub const Swapchain = struct {
    const SwapchainOptions = struct {
        format: Format,
        present_mode: PresentMode,
        usage: UsageFlags = .{ .color_attachment = true },
        frames_in_flight: u32 = 2,
        min_image_count: u32,
    };

    pub fn create(
        d: Device,
        queue: Queue,
        surface: vk.SurfaceKHR,
        options: SwapchainOptions,
    ) !Swapchain {
        _ = queue; // autofix
        _ = d; // autofix
        _ = options; // autofix
        _ = surface; // autofix

        return .{};
    }

    // pub fn acquireNextTexture(swapchain: Swapchain) Texture {}
};

pub const SurfaceCapabilities = struct {
    usages: UsageFlags,
    formats: []const Format,
    present_modes: []const PresentMode,
};

pub const UsageFlags = packed struct(u8) {
    sampled: bool = false,
    storage: bool = false,
    color_attachment: bool = false,
    depth_stencil_attachment: bool = false,
    transfer_src: bool = false,
    transfer_dst: bool = false,
    padding: u2 = undefined,
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

pub const Semaphore = struct {
    semaphore: vk.Semaphore,

    pub fn create(d: Device, init_value: u64) !Semaphore {
        const semaphore_type: vk.SemaphoreTypeCreateInfo = .{
            .semaphore_type = .timeline,
            .initial_value = init_value,
        };
        const timeline_create_info: vk.SemaphoreCreateInfo = .{ .p_next = &semaphore_type };
        const semaphore = try d.device.createSemaphore(&timeline_create_info, null);
        return .{ .semaphore = semaphore };
    }

    pub fn destroy(semaphore: Semaphore, d: Device) void {
        d.device.destroySemaphore(semaphore.semaphore, null);
    }

    pub fn wait(semaphore: Semaphore, d: Device, value: u64) !void {
        const wait_info: vk.SemaphoreWaitInfo = .{
            .semaphore_count = 1,
            .p_semaphores = &.{semaphore.semaphore},
            .p_values = &.{value},
        };
        _ = try d.device.waitSemaphores(&wait_info, std.math.maxInt(u64)); // TODO: handle result?
    }
};

const std = @import("std");
pub const vk = @import("vulkan");
const vk_to_gpu = @import("bridge.zig").vk_to_gpu;
const gpu_to_vk = @import("bridge.zig").gpu_to_vk;
