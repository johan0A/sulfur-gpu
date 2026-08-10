const std = @import("std");
const build_options = @import("options");
const gpu = @import("sf_bindings.zig");
const to_gpu = @import("bridge.zig").to_gpu;
const to_vk = @import("bridge.zig").to_vk;
const sfir = @import("sfir.zig");
const vk = @import("vulkan");
const VulkanLoader = @import("VulkanLoader.zig");
const target = @import("builtin").target;

pub const Instance = struct {
    instance: vk.InstanceProxy,
    loader: VulkanLoader,
    vk_surface_supported: bool,
    debug_messenger: vk.DebugUtilsMessengerEXT,
    sf_gpa: gpu.Allocator,
    gpa: std.mem.Allocator,

    pub fn sfCreateInstance(
        host_allocator: ?*gpu.Allocator,
    ) callconv(gpu.@"callconv") *Instance {
        return create(host_allocator) catch @panic("TODO");
    }
    fn create(
        host_allocator: ?*gpu.Allocator,
    ) !*Instance {
        const gpa: std.mem.Allocator = if (host_allocator) |ha| .{
            .ptr = @ptrCast(@alignCast(ha)),
            .vtable = wrap_sf_allocator_vtable,
        } else std.heap.smp_allocator;

        var arena_impl: std.heap.ArenaAllocator = .init(gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const loader: VulkanLoader = try .open();

        const base_dispatch: vk.BaseWrapper = .load(loader.proc);

        const available_extensions = try base_dispatch.enumerateInstanceExtensionPropertiesAlloc(null, arena);

        const surface_extensions: []const [*:0]const u8 = switch (target.os.tag) {
            .windows => &.{ vk.extensions.khr_surface.name, vk.extensions.khr_win_32_surface.name },
            else => &.{ vk.extensions.khr_surface.name, vk.extensions.khr_xlib_surface.name },
        };

        const vk_surface_supported = for (surface_extensions) |required_ext| {
            for (available_extensions) |available_ext| {
                if (std.mem.eql(u8, std.mem.span(required_ext), std.mem.sliceTo(&available_ext.extension_name, 0))) break;
            } else break false;
        } else true;

        const validation_layer = "VK_LAYER_KHRONOS_validation";
        var enable_validation_layers = build_options.validation_layers;

        if (enable_validation_layers) {
            const available_layers = try base_dispatch.enumerateInstanceLayerPropertiesAlloc(arena);
            for (available_layers) |available_layer| {
                if (std.mem.eql(u8, std.mem.sliceTo(&available_layer.layer_name, 0), validation_layer)) break;
            } else {
                std.log.warn("vulkan validation layers unsupported", .{});
                enable_validation_layers = false;
            }
        }

        var extensions: std.ArrayList([*:0]const u8) = .empty;
        try extensions.appendSlice(arena, surface_extensions);
        try extensions.append(arena, vk.extensions.ext_debug_utils.name.ptr);

        const create_info: vk.InstanceCreateInfo = .{
            .p_application_info = &.{
                .application_version = 0,
                .engine_version = 0,
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
        const handle: vk.InstanceProxy = .init(instance_handle, instance_dispatch);

        const debug_messenger_info: vk.DebugUtilsMessengerCreateInfoEXT = .{
            .message_severity = .{ .warning_bit_ext = true, .error_bit_ext = true },
            .message_type = .{ .general_bit_ext = true, .validation_bit_ext = true, .performance_bit_ext = true },
            .pfn_user_callback = debugCallback,
        };
        const debug_messenger = try handle.createDebugUtilsMessengerEXT(&debug_messenger_info, null);

        const instance = try gpa.create(Instance);
        instance.* = .{
            .instance = handle,
            .loader = loader,
            .vk_surface_supported = vk_surface_supported,
            .debug_messenger = debug_messenger,
            .sf_gpa = if (host_allocator) |ha| ha.* else undefined,
            .gpa = if (host_allocator) |ha| .{
                .ptr = @ptrCast(@alignCast(ha)),
                .vtable = wrap_sf_allocator_vtable,
            } else std.heap.smp_allocator,
        };
        return instance;
    }

    pub fn sfDestroyInstance(instance: *Instance) callconv(gpu.@"callconv") void {
        instance.instance.destroyDebugUtilsMessengerEXT(instance.debug_messenger, null);
        instance.instance.destroyInstance(null);
        instance.loader.close();
        instance.gpa.destroy(instance.instance.wrapper);
        instance.gpa.destroy(instance);
    }

    pub fn sfEnumerateAdapters(instance: *Instance, adapters_buffer_size: usize, adapters_buffer: ?[*]*Adapter, adapters_count: *usize) callconv(gpu.@"callconv") void {
        enumerateAdapters(instance, if (adapters_buffer) |buf| buf[0..adapters_buffer_size] else null, adapters_count) catch @panic("TODO");
    }
    fn enumerateAdapters(instance: *Instance, adapters_buffer_opt: ?[]*Adapter, adapters_count: *usize) !void {
        const physical_devices = try instance.instance.enumeratePhysicalDevicesAlloc(instance.gpa);
        defer instance.gpa.free(physical_devices);
        adapters_count.* = physical_devices.len;
        errdefer adapters_count.* = 0;
        const adapters_buffer = adapters_buffer_opt orelse return;
        for (0..@min(adapters_buffer.len, physical_devices.len)) |i| {
            adapters_buffer[i] = .fromPhysicalDevice(physical_devices[i]);
        }
    }
};

pub const Surface = struct {
    surface: vk.SurfaceKHR,

    pub fn sfCreateSurfaceWin32(instance: *Instance, desc: gpu.SurfaceWin32Desc) callconv(gpu.@"callconv") *Surface {
        return createWin32(instance, desc) catch @panic("TODO");
    }
    fn createWin32(instance: *Instance, desc: gpu.SurfaceWin32Desc) !*Surface {
        const info: vk.Win32SurfaceCreateInfoKHR = .{ .hinstance = @ptrCast(desc.hinstance), .hwnd = @ptrCast(desc.hwnd) };
        const surface = try instance.gpa.create(Surface);
        surface.* = .{ .surface = try instance.instance.createWin32SurfaceKHR(&info, null) };
        return surface;
    }

    pub fn sfCreateSurfaceXlib(instance: *Instance, desc: gpu.SurfaceXlibDesc) callconv(gpu.@"callconv") *Surface {
        return createXlib(instance, desc) catch @panic("TODO");
    }
    fn createXlib(instance: *Instance, desc: gpu.SurfaceXlibDesc) !*Surface {
        const info: vk.XlibSurfaceCreateInfoKHR = .{
            .dpy = @ptrCast(desc.display),
            .window = @intCast(desc.window),
        };
        const surface = try instance.gpa.create(Surface);
        surface.* = .{ .surface = try instance.instance.createXlibSurfaceKHR(&info, null) };
        return surface;
    }

    pub fn sfDestroySurface(surface: *Surface, instance: *Instance) callconv(gpu.@"callconv") void {
        destroy(surface, instance);
    }
    fn destroy(surface: *Surface, instance: *Instance) void {
        instance.instance.destroySurfaceKHR(surface.surface, null);
        instance.gpa.destroy(surface);
    }
};

pub const Adapter = opaque {
    comptime {
        std.debug.assert(@sizeOf(vk.PhysicalDevice) == @sizeOf(*Adapter));
    }
    fn asPhysicalDevice(adapter: *Adapter) vk.PhysicalDevice {
        return @enumFromInt(@intFromPtr(adapter));
    }
    fn fromPhysicalDevice(physical_device: vk.PhysicalDevice) *Adapter {
        return @ptrFromInt(@intFromEnum(physical_device));
    }
};

pub const Device = struct {
    instance: vk.InstanceProxy,
    device: vk.DeviceProxy,
    physical_device: vk.PhysicalDevice,

    queue_states: [max_queue_state_count]QueueState,
    queue_state_count: u8,
    queue_id_from_type: std.EnumArray(gpu.QueueType, QueueId),
    queues: std.EnumArray(gpu.QueueType, Queue),

    gpa: std.mem.Allocator,

    heap: AddressMap,

    descriptor_buffer_properties: ?vk.PhysicalDeviceDescriptorBufferPropertiesEXT,

    texture_heap_set_layout: vk.DescriptorSetLayout,

    pending_general_layout_transitions: std.array_hash_map.Auto(vk.Image, gpu.TextureDesc),

    memory_properties: vk.PhysicalDeviceMemoryProperties,
    has_host_visible_device_local: bool,

    const max_queue_state_count = @typeInfo(gpu.QueueType).@"enum".fields.len;

    const QueueId = enum(u8) { _ };

    const QueueState = struct {
        queue: vk.Queue,
        family: u32,

        timeline: Semaphore,
        last_submitted: u64,

        command_pool: vk.CommandPool,
        pending_command_buffers: std.ArrayList(PendingCommandBuffer),
        free_command_buffers: std.ArrayList(vk.CommandBuffer),

        const PendingCommandBuffer = struct {
            value: u64,
            command_buffer: vk.CommandBuffer,
        };
    };

    const AddressMap = struct {
        entries: std.ArrayList(Entry),

        const Entry = struct {
            buffer: vk.Buffer,
            memory: vk.DeviceMemory,
            size: usize,
            device_addr: gpu.DeviceAddress,
            host_addr: ?usize,

            fn destroy(entry: *Entry, d: Device) void {
                d.device.destroyBuffer(entry.buffer, null);
                d.device.freeMemory(entry.memory, null);
                entry.* = undefined;
            }
        };

        fn addrToEntryAndOffset(map: *const AddressMap, device_addr: gpu.DeviceAddress) struct { Entry, vk.DeviceSize } {
            const entry = map.addrToEntry(device_addr);
            const offset = device_addr - entry.device_addr;
            return .{ entry, @intCast(offset) };
        }

        fn addrToEntry(map: *const AddressMap, device_addr: gpu.DeviceAddress) Entry {
            return map.entries.items[map.indexFromAddr(device_addr)];
        }

        fn indexFromAddr(map: *const AddressMap, device_addr: gpu.DeviceAddress) usize {
            return std.sort.upperBound(
                Entry,
                map.entries.items,
                device_addr,
                order,
            ) - 1;
        }

        fn insert(
            map: *AddressMap,
            gpa: std.mem.Allocator,
            entry: Entry,
        ) !void {
            const insert_index = std.sort.upperBound(
                Entry,
                map.entries.items,
                entry.device_addr,
                order,
            );
            try map.entries.insert(gpa, insert_index, entry);
        }

        fn order(addr: usize, item: Entry) std.math.Order {
            return std.math.order(addr, item.device_addr);
        }
    };

    pub fn sfCreateDevice(
        instance: *Instance,
        adapter: *Adapter,
    ) callconv(gpu.@"callconv") *Device {
        return @ptrCast(create(
            instance,
            adapter,
        ) catch @panic("TODO"));
    }
    fn create(
        instance: *Instance,
        adapter: *Adapter,
    ) !*Device {
        var arena_impl: std.heap.ArenaAllocator = .init(instance.gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const device_handle = try createLogicalDevice(
            arena,
            adapter.asPhysicalDevice(),
            instance.instance.wrapper,
            instance.vk_surface_supported,
        );
        const device_dispatch = try instance.gpa.create(vk.DeviceWrapper);
        device_dispatch.* = .load(device_handle, instance.instance.wrapper.dispatch.vkGetDeviceProcAddr.?);
        const handle: vk.DeviceProxy = .init(device_handle, device_dispatch);

        var bindings = [_]vk.DescriptorSetLayoutBinding{.{
            .binding = 0,
            .descriptor_type = .mutable_ext,
            .descriptor_count = 0,
            .stage_flags = .{ .vertex_bit = true, .fragment_bit = true, .compute_bit = true },
            .p_immutable_samplers = null,
        }};
        const allowed_types: []const vk.DescriptorType = &.{ .storage_image, .sampled_image };
        const mutable_type_list: vk.MutableDescriptorTypeListEXT = .{
            .descriptor_type_count = allowed_types.len,
            .p_descriptor_types = allowed_types.ptr,
        };
        const mutable_info: vk.MutableDescriptorTypeCreateInfoEXT = .{
            .mutable_descriptor_type_list_count = 1,
            .p_mutable_descriptor_type_lists = &.{mutable_type_list},
        };
        const binding_flags: vk.DescriptorBindingFlags = .{
            .partially_bound_bit = true,
            .variable_descriptor_count_bit = true,
        };
        const binding_flags_info: vk.DescriptorSetLayoutBindingFlagsCreateInfo = .{
            .p_next = &mutable_info,
            .binding_count = 1,
            .p_binding_flags = &.{binding_flags},
        };
        const layout_info: vk.DescriptorSetLayoutCreateInfo = .{
            .p_next = &binding_flags_info,
            .flags = .{ .descriptor_buffer_bit_ext = true },
            .binding_count = 1,
            .p_bindings = &bindings,
        };
        var variable_support: vk.DescriptorSetVariableDescriptorCountLayoutSupport = .{ .max_variable_descriptor_count = 0 };
        var layout_support: vk.DescriptorSetLayoutSupport = .{ .p_next = &variable_support, .supported = .false };
        handle.getDescriptorSetLayoutSupport(&layout_info, &layout_support);
        bindings[0].descriptor_count = variable_support.max_variable_descriptor_count;
        const descriptor_set_layout = try handle.createDescriptorSetLayout(&layout_info, null);

        const queue_family_indices = try findQueueFamilies(arena, adapter.asPhysicalDevice(), instance.instance.wrapper);

        var queue_states: [max_queue_state_count]QueueState = undefined;
        var queue_state_count: u8 = 0;
        var queue_of_type: std.EnumArray(gpu.QueueType, QueueId) = .initUndefined();

        for (std.enums.values(gpu.QueueType)) |queue_type| {
            const family_index = queue_family_indices.get(queue_type);
            const existing: ?QueueId = for (queue_states[0..queue_state_count], 0..) |q, i| {
                if (q.family == family_index) break @enumFromInt(i);
            } else null;
            queue_of_type.set(queue_type, existing orelse blk: {
                const timeline: Semaphore = try .createVkDevice(handle, 0);
                const command_pool_info: vk.CommandPoolCreateInfo = .{
                    .flags = .{ .transient_bit = true, .reset_command_buffer_bit = true },
                    .queue_family_index = family_index,
                };
                const pool = try handle.createCommandPool(&command_pool_info, null);

                queue_states[queue_state_count] = .{
                    .queue = handle.getDeviceQueue(family_index, 0),
                    .family = family_index,
                    .timeline = timeline,
                    .last_submitted = 0,
                    .command_pool = pool,
                    .pending_command_buffers = .empty,
                    .free_command_buffers = .empty,
                };
                queue_state_count += 1;
                break :blk @enumFromInt(queue_state_count - 1);
            });
        }

        const memory_properties = instance.instance.getPhysicalDeviceMemoryProperties(adapter.asPhysicalDevice());

        const has_host_visible_device_local = for (0..memory_properties.memory_type_count) |i| {
            const t = memory_properties.memory_types[i];
            if (t.property_flags.device_local_bit and t.property_flags.host_visible_bit) {
                const memory_heap = memory_properties.memory_heaps[t.heap_index];
                if (memory_heap.size > 256 * 1024 * 1024) break true;
            }
        } else false;

        const device = try instance.gpa.create(Device);
        device.* = .{
            .instance = instance.instance,
            .device = handle,
            .physical_device = adapter.asPhysicalDevice(),

            .queue_states = queue_states,
            .queue_state_count = queue_state_count,
            .queue_id_from_type = queue_of_type,
            .queues = .initUndefined(),

            .gpa = instance.gpa,
            .heap = .{ .entries = .empty },
            .descriptor_buffer_properties = null,
            .texture_heap_set_layout = descriptor_set_layout,
            .pending_general_layout_transitions = .empty,
            .memory_properties = memory_properties,
            .has_host_visible_device_local = has_host_visible_device_local,
        };
        return device;
    }

    pub fn sfDestroyDevice(d: *Device) callconv(gpu.@"callconv") void {
        return destroy(d);
    }
    fn destroy(d: *Device) void {
        d.device.deviceWaitIdle() catch {};
        for (d.queue_states[0..d.queue_state_count]) |*queue| {
            queue.timeline.destroyVkDevice(d.*.device);
            d.device.destroyCommandPool(queue.command_pool, null);
            queue.free_command_buffers.deinit(d.gpa);
            queue.pending_command_buffers.deinit(d.gpa);
        }
        d.device.destroyDescriptorSetLayout(d.texture_heap_set_layout, null);
        d.device.destroyDevice(null);
        d.gpa.destroy(d.device.wrapper);
        // TODO: make a debug gpa and uncomment next line
        // for (d.heap.entries.items) |entry| entry.destroy(d);
        d.heap.entries.deinit(d.gpa);
        d.pending_general_layout_transitions.deinit(d.gpa);
        const gpa = d.gpa;
        gpa.destroy(d);
    }

    pub fn sfSurfaceSupportedUsage(d: *Device, surface: *Surface) callconv(gpu.@"callconv") gpu.TextureUsage {
        return surfaceUsage(d, surface) catch @panic("TODO");
    }
    fn surfaceUsage(d: *Device, surface: *Surface) !gpu.TextureUsage {
        const vk_capabilities = try d.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(d.physical_device, surface.surface);
        return to_gpu.usageFlags(vk_capabilities.supported_usage_flags);
    }

    pub fn sfSurfaceFormats(
        d: *Device,
        surface: *Surface,
        formats_buffer_size: usize,
        formats_buffer: ?[*]gpu.Format,
        formats_count: *usize,
    ) callconv(gpu.@"callconv") void {
        surfaceFormats(d, surface, if (formats_buffer) |buf| buf[0..formats_buffer_size] else null, formats_count) catch @panic("TODO");
    }
    fn surfaceFormats(
        d: *Device,
        surface: *Surface,
        formats_buffer_opt: ?[]gpu.Format,
        formats_count: *usize,
    ) !void {
        var arena_impl: std.heap.ArenaAllocator = .init(d.gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const vk_formats = try d.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(
            d.physical_device,
            surface.surface,
            arena,
        );
        var formats: std.ArrayList(gpu.Format) = try .initCapacity(arena, vk_formats.len);
        for (vk_formats) |vk_format| {
            formats.appendAssumeCapacity(to_gpu.format(vk_format.format) orelse continue);
        }

        formats_count.* = formats.items.len;
        errdefer formats_count.* = 0;
        const formats_buffer = formats_buffer_opt orelse return;
        @memcpy(
            formats_buffer[0..@min(formats_buffer.len, formats.items.len)],
            formats.items[0..@min(formats_buffer.len, formats.items.len)],
        );
    }

    pub fn sfSurfacePresentModes(
        d: *Device,
        surface: *Surface,
        modes_buffer_size: usize,
        modes_buffer: ?[*]gpu.PresentMode,
        modes_count: *usize,
    ) callconv(gpu.@"callconv") void {
        surfacePresentModes(
            d,
            surface,
            if (modes_buffer) |buf| buf[0..modes_buffer_size] else null,
            modes_count,
        ) catch @panic("TODO");
    }
    fn surfacePresentModes(
        d: *Device,
        surface: *Surface,
        modes_buffer_opt: ?[]gpu.PresentMode,
        modes_count: *usize,
    ) !void {
        var arena_impl: std.heap.ArenaAllocator = .init(d.gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const vk_modes = try d.instance.getPhysicalDeviceSurfacePresentModesAllocKHR(
            d.physical_device,
            surface.surface,
            arena,
        );
        var modes: std.ArrayList(gpu.PresentMode) = try .initCapacity(arena, vk_modes.len);
        for (vk_modes) |vk_mode| {
            modes.appendAssumeCapacity(to_gpu.presentMode(vk_mode) orelse continue);
        }

        modes_count.* = modes.items.len;
        errdefer modes_count.* = 0;
        const modes_buffer = modes_buffer_opt orelse return;
        @memcpy(
            modes_buffer[0..@min(modes_buffer.len, modes.items.len)],
            modes.items[0..@min(modes_buffer.len, modes.items.len)],
        );
    }

    pub fn sfDeviceToHostPointer(d: *Device, ptr: gpu.DeviceAddress) callconv(gpu.@"callconv") *anyopaque {
        const entry = d.heap.addrToEntry(ptr);
        const offset = ptr - entry.device_addr;
        return @ptrFromInt(entry.host_addr.? + offset);
    }

    fn descriptorBufferProperties(d: *Device) *vk.PhysicalDeviceDescriptorBufferPropertiesEXT {
        if (d.descriptor_buffer_properties == null) {
            var buffer_properties = std.mem.zeroInit(vk.PhysicalDeviceDescriptorBufferPropertiesEXT, .{});
            var properties_2: vk.PhysicalDeviceProperties2 = .{ .p_next = &buffer_properties, .properties = undefined };
            d.instance.getPhysicalDeviceProperties2(d.physical_device, &properties_2);
            d.descriptor_buffer_properties = buffer_properties;
        }
        return &d.descriptor_buffer_properties.?;
    }

    fn createLogicalDevice(
        arena: std.mem.Allocator,
        physical_device: vk.PhysicalDevice,
        instance_dispatch: *const vk.InstanceWrapper,
        presentation_enabled: bool,
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

        var mutable_descriptor_features: vk.PhysicalDeviceMutableDescriptorTypeFeaturesEXT = .{
            .mutable_descriptor_type = .true,
        };
        var descriptor_buffer_features: vk.PhysicalDeviceDescriptorBufferFeaturesEXT = .{
            .p_next = &mutable_descriptor_features,
            .descriptor_buffer = .true,
        };
        var device_features_vk13: vk.PhysicalDeviceVulkan13Features = .{
            .p_next = &descriptor_buffer_features,
            .dynamic_rendering = .true,
            .synchronization_2 = .true,
        };
        var device_features_vk12: vk.PhysicalDeviceVulkan12Features = .{
            .p_next = &device_features_vk13,
            .buffer_device_address = .true,
            .runtime_descriptor_array = .true,
            .descriptor_binding_partially_bound = .true,
            .descriptor_binding_variable_descriptor_count = .true,
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

        var required_device_extensions_buff: [64][*:0]const u8 = undefined;
        var required_device_extensions: std.ArrayList([*:0]const u8) = .initBuffer(&required_device_extensions_buff);
        required_device_extensions.appendSliceAssumeCapacity(&.{
            vk.extensions.ext_descriptor_buffer.name,
            vk.extensions.ext_mutable_descriptor_type.name,
            // vk.extensions.khr_unified_image_layouts.name, TODO
        });
        if (presentation_enabled) required_device_extensions.appendAssumeCapacity(
            vk.extensions.khr_swapchain.name,
        );

        return try instance_dispatch.createDevice(physical_device, &.{
            .p_next = &device_features_vk11,
            .p_queue_create_infos = queue_infos.ptr,
            .queue_create_info_count = @intCast(queue_infos.len),
            .pp_enabled_extension_names = required_device_extensions.items.ptr,
            .enabled_extension_count = @intCast(required_device_extensions.items.len),
            .p_enabled_features = &.{
                .shader_int_64 = .true,
                .shader_int_16 = .true,
                .sampler_anisotropy = .true,
                .multi_draw_indirect = .true,
                // .robust_buffer_access = .true, TODO: consider
            },
        }, null);
    }

    fn findQueueFamilies(
        arena: std.mem.Allocator,
        physical_device: vk.PhysicalDevice,
        instance_dispatch: *const vk.InstanceWrapper,
    ) !std.EnumArray(gpu.QueueType, u32) {
        const queue_family_indices = try instance_dispatch.getPhysicalDeviceQueueFamilyPropertiesAlloc(physical_device, arena);

        var graphics: u32 = std.math.maxInt(u32);
        for (queue_family_indices, 0..) |family, i| {
            if (family.queue_flags.graphics_bit) {
                graphics = @intCast(i);
                break;
            }
        }

        var compute = graphics;
        for (queue_family_indices, 0..) |family, i| {
            if (family.queue_flags.compute_bit and !family.queue_flags.graphics_bit) {
                compute = @intCast(i);
                break;
            }
        }

        var transfer = compute;
        for (queue_family_indices, 0..) |family, i| {
            if (family.queue_flags.transfer_bit and
                !family.queue_flags.graphics_bit and
                !family.queue_flags.compute_bit)
            {
                transfer = @intCast(i);
                break;
            }
        }

        return .init(.{
            .graphics = graphics,
            .compute = compute,
            .transfer = transfer,
        });
    }

    fn queueStateForQueueType(d: *Device, queue_type: gpu.QueueType) *QueueState {
        const queue_id = d.queue_id_from_type.get(queue_type);
        return d.queueStateForQueueId(queue_id);
    }

    fn queueStateForQueueId(d: *Device, queue_id: QueueId) *QueueState {
        return &d.queue_states[@intFromEnum(queue_id)];
    }

    fn acquireCommandBuffer(d: *Device, queue_type: gpu.QueueType) !CommandBuffer {
        const queue_id = d.queue_id_from_type.get(queue_type);
        if (d.queueStateForQueueId(queue_id).free_command_buffers.pop()) |command_buffer| {
            try d.device.resetCommandBuffer(command_buffer, .{});
            return .{ .command_buffer = command_buffer, .queue_id = queue_id };
        }

        const alloc_info: vk.CommandBufferAllocateInfo = .{
            .command_pool = d.queueStateForQueueType(queue_type).command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        };
        var command_buffer: vk.CommandBuffer = undefined;
        try d.device.allocateCommandBuffers(&alloc_info, (&command_buffer)[0..1]);
        return .{ .command_buffer = command_buffer, .queue_id = queue_id };
    }

    fn releaseCommandBuffer(d: *Device, command_buffer: CommandBuffer) void {
        const queue_state = d.queueStateForQueueId(command_buffer.queue_id);
        queue_state.free_command_buffers.append(d.gpa, command_buffer.command_buffer) catch {
            d.device.freeCommandBuffers(queue_state.command_pool, &.{command_buffer.command_buffer});
        };
    }

    fn reclaimCompletedCommandBuffers(d: *Device) void {
        for (d.queue_states[0..d.queue_state_count], 0..) |*queue_state, queue_index| {
            const queue_id: QueueId = @enumFromInt(queue_index);
            const list = &queue_state.pending_command_buffers;
            if (list.items.len == 0) continue;
            const timeline = queue_state.timeline;
            const completed = d.device.getSemaphoreCounterValue(timeline.semaphore) catch continue;
            var n: usize = 0;
            while (n < list.items.len and list.items[n].value <= completed) : (n += 1) {
                d.releaseCommandBuffer(.{
                    .command_buffer = list.items[n].command_buffer,
                    .queue_id = queue_id,
                });
            }
            const rest = list.items[n..];
            @memmove(list.items[0..rest.len], rest);
            list.items.len = rest.len;
        }
    }
};

pub const Queue = struct {
    id: Device.QueueId,
    queue_type: gpu.QueueType,

    pub fn sfCreateQueue(d: *Device, queue_type: gpu.QueueType) callconv(gpu.@"callconv") *Queue {
        return create(d, queue_type);
    }
    fn create(d: *Device, queue_type: gpu.QueueType) *Queue {
        const id = d.queue_id_from_type.get(queue_type);
        const queue = d.queues.getPtr(queue_type);
        queue.* = .{ .id = id, .queue_type = queue_type };
        return queue;
    }

    pub fn sfStartCommandRecording(queue: *Queue, d: *Device) callconv(gpu.@"callconv") *CommandBuffer {
        const dv: *Device = d;
        const cb = dv.gpa.create(CommandBuffer) catch @panic("TODO");
        cb.* = startCommandRecording(queue, dv) catch @panic("TODO");
        return @ptrCast(cb);
    }
    fn startCommandRecording(queue: *const Queue, d: *Device) !CommandBuffer {
        d.reclaimCompletedCommandBuffers();
        const command_buffer = try d.acquireCommandBuffer(queue.queue_type);
        errdefer d.releaseCommandBuffer(command_buffer);

        const begin_info: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit_bit = true } };
        try d.device.beginCommandBuffer(command_buffer.command_buffer, &begin_info);

        return command_buffer;
    }

    pub fn sfSubmit(
        queue: *Queue,
        d: *Device,
        command_buffer_count: usize,
        command_buffers: [*]const *CommandBuffer,
    ) callconv(gpu.@"callconv") void {
        submit(
            queue,
            d,
            command_buffers[0..command_buffer_count],
            null,
        ) catch @panic("TODO");
    }

    pub fn sfSubmitAndSignal(
        queue: *Queue,
        d: *Device,
        command_buffer_count: usize,
        command_buffers: [*]const *CommandBuffer,
        signal_semaphore: *Semaphore,
        signal_value: u64,
    ) callconv(gpu.@"callconv") void {
        submit(
            queue,
            d,
            command_buffers[0..command_buffer_count],
            .{ .semaphore = signal_semaphore, .value = signal_value },
        ) catch @panic("TODO");
    }

    const Signal = struct {
        semaphore: *Semaphore,
        value: u64,
    };

    fn submit(
        queue: *Queue,
        d: *Device,
        command_buffers: []const *CommandBuffer,
        extra_signal: ?Signal,
    ) !void {
        errdefer for (command_buffers) |command_buffer| d.releaseCommandBuffer(command_buffer.*);
        try queue.submitPendingGeneralLayoutTransitions(d);
        try queue.submitRecordedCommandBuffers(d, command_buffers, extra_signal);
        for (command_buffers) |command_buffer| d.gpa.destroy(command_buffer);
    }

    fn submitPendingGeneralLayoutTransitions(queue: Queue, d: *Device) !void {
        const image_count = d.pending_general_layout_transitions.count();
        if (image_count == 0) return;

        const barriers = try d.gpa.alloc(vk.ImageMemoryBarrier2, image_count);
        defer d.gpa.free(barriers);

        var image_it = d.pending_general_layout_transitions.iterator();

        for (barriers) |*barrier| {
            const item = image_it.next().?;
            const image = item.key_ptr.*;
            const info = item.value_ptr.*;

            barrier.* = .{
                .dst_stage_mask = .{
                    .all_commands_bit = true,
                },
                .dst_access_mask = .{
                    .memory_read_bit = true,
                    .memory_write_bit = true,
                },
                .old_layout = .undefined,
                .new_layout = .general,
                .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .image = image,
                .subresource_range = .{
                    .aspect_mask = to_vk.aspectsForFormat(info.format),
                    .base_mip_level = 0,
                    .level_count = info.mip_count,
                    .base_array_layer = 0,
                    .layer_count = info.layer_count,
                },
            };
        }

        const command_buffer = try queue.startCommandRecording(d);

        errdefer d.releaseCommandBuffer(command_buffer);

        const dependency_info: vk.DependencyInfo = .{
            .image_memory_barrier_count = @intCast(barriers.len),
            .p_image_memory_barriers = barriers.ptr,
        };
        d.device.cmdPipelineBarrier2(command_buffer.command_buffer, &dependency_info);

        try queue.submitRecordedCommandBuffers(d, &.{&command_buffer}, null);

        d.pending_general_layout_transitions.clearRetainingCapacity();
    }

    fn submitRecordedCommandBuffers(
        queue: Queue,
        d: *Device,
        command_buffers: []const *const CommandBuffer,
        extra_signal: ?Signal,
    ) !void {
        const submit_buffers = try d.gpa.alloc(vk.CommandBufferSubmitInfo, command_buffers.len);
        defer d.gpa.free(submit_buffers);
        for (command_buffers, submit_buffers) |command_buffer, *submit_buffer| {
            try d.device.endCommandBuffer(command_buffer.command_buffer);
            submit_buffer.* = .{
                .command_buffer = command_buffer.command_buffer,
                .device_mask = 0,
            };
        }

        const queue_state = d.queueStateForQueueId(queue.id);
        try queue_state.pending_command_buffers.ensureUnusedCapacity(d.gpa, command_buffers.len);

        const timeline = queue_state.timeline;
        const value = queue_state.last_submitted + 1;

        var signal_infos: [2]vk.SemaphoreSubmitInfo = undefined;
        signal_infos[0] = .{
            .semaphore = timeline.semaphore,
            .value = value,
            .stage_mask = .{ .all_commands_bit = true },
            .device_index = 0,
        };
        var signals: []const vk.SemaphoreSubmitInfo = signal_infos[0..1];
        if (extra_signal) |signal| {
            signal_infos[1] = .{
                .semaphore = signal.semaphore.semaphore,
                .value = signal.value,
                .stage_mask = .{ .all_commands_bit = true },
                .device_index = 0,
            };
            signals = signal_infos[0..2];
        }

        const submit_info: vk.SubmitInfo2 = .{
            .command_buffer_info_count = @intCast(submit_buffers.len),
            .p_command_buffer_infos = submit_buffers.ptr,
            .signal_semaphore_info_count = @intCast(signals.len),
            .p_signal_semaphore_infos = signals.ptr,
        };
        try d.device.queueSubmit2(queue_state.queue, &.{submit_info}, .null_handle);

        queue_state.last_submitted = value;
        for (command_buffers) |command_buffer| queue_state.pending_command_buffers.appendAssumeCapacity(.{
            .value = value,
            .command_buffer = command_buffer.command_buffer,
        });
    }
};

pub const Semaphore = struct {
    semaphore: vk.Semaphore,

    pub fn sfCreateSemaphore(d: *Device, init_value: u64) callconv(gpu.@"callconv") *Semaphore {
        return @ptrCast(create(d, init_value) catch @panic("TODO"));
    }
    fn create(d: *Device, init_value: u64) !*Semaphore {
        const dv: *Device = d;
        const semaphore = try dv.gpa.create(Semaphore);
        semaphore.* = try createVkDevice(d.device, init_value);
        return semaphore;
    }

    pub fn sfDestroySemaphore(semaphore: *Semaphore, d: *Device) callconv(gpu.@"callconv") void {
        const dv: *Device = d;
        const s: *Semaphore = semaphore;
        destroy(s, dv);
        dv.gpa.destroy(s);
    }
    fn destroy(semaphore: *Semaphore, d: *Device) void {
        destroyVkDevice(semaphore, d.device);
    }

    pub fn sfWaitSemaphore(semaphore: *Semaphore, d: *Device, value: u64) callconv(gpu.@"callconv") void {
        wait(semaphore, d, value) catch @panic("TODO");
    }
    fn wait(semaphore: *const Semaphore, d: *Device, value: u64) !void {
        const wait_info: vk.SemaphoreWaitInfo = .{
            .semaphore_count = 1,
            .p_semaphores = &.{semaphore.semaphore},
            .p_values = &.{value},
        };
        _ = try d.device.waitSemaphores(&wait_info, std.math.maxInt(u64));
    }

    fn createVkDevice(device: vk.DeviceProxy, init_value: u64) !Semaphore {
        const semaphore_type: vk.SemaphoreTypeCreateInfo = .{
            .semaphore_type = .timeline,
            .initial_value = init_value,
        };
        const timeline_create_info: vk.SemaphoreCreateInfo = .{ .p_next = &semaphore_type };
        const semaphore = try device.createSemaphore(&timeline_create_info, null);
        return .{ .semaphore = semaphore };
    }

    fn destroyVkDevice(semaphore: *Semaphore, device: vk.DeviceProxy) void {
        device.destroySemaphore(semaphore.semaphore, null);
    }
};

pub const Swapchain = struct {
    swapchain: vk.SwapchainKHR,
    surface: vk.SurfaceKHR,
    desc: gpu.SwapchainDesc,
    queue: *Queue,

    textures: []SwapchainTexture,
    acquire_fence: vk.Fence,
    current: u32,

    needs_recreate: bool,

    const SwapchainTexture = struct {
        texture: Texture,
        /// general -> present_src
        present_command_buffer: CommandBuffer,
        /// binary
        present_semaphore: vk.Semaphore,
        present_timeline: ?struct {
            semaphore: *Semaphore,
            value: u64,
        },
    };

    pub fn sfCreateSwapchain(
        d: *Device,
        queue: *Queue,
        surface: *Surface,
        options: gpu.SwapchainDesc,
    ) callconv(gpu.@"callconv") *Swapchain {
        return create(d, queue, surface, options) catch @panic("TODO");
    }
    fn create(
        d: *Device,
        queue: *Queue,
        surface: *Surface,
        options: gpu.SwapchainDesc,
    ) !*Swapchain {
        const queue_family = d.queueStateForQueueId(queue.id).family;

        // TODO: move to adapter picking
        std.debug.assert(try d.instance.getPhysicalDeviceSurfaceSupportKHR(d.physical_device, queue_family, surface.surface) == .true);

        const swapchain = try d.gpa.create(Swapchain);
        swapchain.* = .{
            .swapchain = .null_handle,
            .surface = surface.surface,
            .desc = options,
            .queue = queue,
            .textures = &.{},
            .acquire_fence = try d.device.createFence(&.{}, null),
            .current = undefined,
            .needs_recreate = true,
        };
        return swapchain;
    }

    pub fn sfDestroySwapchain(swapchain: *Swapchain, d: *Device) callconv(gpu.@"callconv") void {
        destroy(swapchain, d);
    }
    fn destroy(swapchain: *Swapchain, d: *Device) void {
        _ = d.device.queueWaitIdle(d.queueStateForQueueId(swapchain.queue.id).queue) catch {};
        swapchain.destroyImageResources(d);
        d.device.destroySwapchainKHR(swapchain.swapchain, null);
        d.device.destroyFence(swapchain.acquire_fence, null);
        d.gpa.destroy(swapchain);
    }

    pub fn sfSwapchainAcquireNextTexture(swapchain: *Swapchain, d: *Device, queue: *Queue, width: u32, height: u32) callconv(gpu.@"callconv") *Texture {
        return acquireNextTexture(swapchain, d, queue, width, height) catch @panic("TODO");
    }
    fn acquireNextTexture(swapchain: *Swapchain, d: *Device, queue: *Queue, width: u32, height: u32) !*Texture {
        var attempts: u32 = 0;
        while (true) : (attempts += 1) {
            if (attempts > 8) return error.SurfaceLost;
            if (swapchain.needs_recreate) try swapchain.recreate(d, queue, width, height);

            const result = d.device.acquireNextImageKHR(
                swapchain.swapchain,
                std.math.maxInt(u64),
                .null_handle,
                swapchain.acquire_fence,
            ) catch |err| switch (err) {
                error.OutOfDateKHR => {
                    swapchain.needs_recreate = true;
                    continue;
                },
                else => |e| return e,
            };
            const index = result.image_index;
            if (result.result == .suboptimal_khr) swapchain.needs_recreate = true;

            // TODO: make async
            _ = try d.device.waitForFences(&.{swapchain.acquire_fence}, .true, std.math.maxInt(u64));
            try d.device.resetFences(&.{swapchain.acquire_fence});

            swapchain.current = index;
            const texture = &swapchain.textures[index].texture;

            try d.pending_general_layout_transitions.put(d.gpa, texture.image, texture.desc);

            return texture;
        }
    }

    pub fn sfSwapchainPresent(
        swapchain: *Swapchain,
        d: *Device,
        queue: *Queue,
        semaphore: *Semaphore,
        semaphore_value: u64,
    ) callconv(gpu.@"callconv") void {
        present(swapchain, d, queue, semaphore, semaphore_value) catch @panic("TODO");
    }
    fn present(
        swapchain: *Swapchain,
        d: *Device,
        queue: *Queue,
        semaphore: *Semaphore,
        semaphore_value: u64,
    ) !void {
        const texture = &swapchain.textures[swapchain.current];
        texture.present_timeline = .{ .semaphore = semaphore, .value = semaphore_value };
        const queue_state = d.queueStateForQueueId(queue.id);

        try d.device.queueSubmit2(
            queue_state.queue,
            &.{.{
                .wait_semaphore_info_count = 1,
                .p_wait_semaphore_infos = &.{.{
                    .semaphore = semaphore.semaphore,
                    .value = semaphore_value,
                    .stage_mask = .{ .all_commands_bit = true },
                    .device_index = 0,
                }},
                .command_buffer_info_count = 1,
                .p_command_buffer_infos = &.{.{
                    .command_buffer = texture.present_command_buffer.command_buffer,
                    .device_mask = 0,
                }},
                .signal_semaphore_info_count = 1,
                .p_signal_semaphore_infos = &.{.{
                    .semaphore = texture.present_semaphore,
                    .value = 0,
                    .stage_mask = .{ .all_commands_bit = true },
                    .device_index = 0,
                }},
            }},
            .null_handle,
        );

        _ = d.device.queuePresentKHR(queue_state.queue, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = &.{texture.present_semaphore},
            .swapchain_count = 1,
            .p_swapchains = &.{swapchain.swapchain},
            .p_image_indices = &.{swapchain.current},
        }) catch |err| switch (err) {
            error.OutOfDateKHR => { // TODO: can we avoid the frame drop?
                swapchain.needs_recreate = true;
                return;
            },
            else => |e| return e,
        };
    }

    fn recreate(swapchain: *Swapchain, d: *Device, queue: *Queue, width: u32, height: u32) !void {
        for (swapchain.textures) |t| if (t.present_timeline) |tl| try tl.semaphore.wait(d, tl.value);
        try d.device.queueWaitIdle(d.queueStateForQueueId(queue.id).queue);

        swapchain.destroyImageResources(d);

        const capabilities = try d.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(d.physical_device, swapchain.surface);

        const min_image_extent = capabilities.min_image_extent;
        const max_image_extent = capabilities.max_image_extent;
        const surface_extent: vk.Extent2D = switch (capabilities.current_extent.width != std.math.maxInt(u32)) {
            true => capabilities.current_extent,
            false => .{
                .width = std.math.clamp(width, min_image_extent.width, max_image_extent.width),
                .height = std.math.clamp(height, min_image_extent.height, max_image_extent.height),
            },
        };

        var min_image_count = capabilities.min_image_count + 1;
        if (capabilities.max_image_count != 0) min_image_count = @min(min_image_count, capabilities.max_image_count);

        const create_info: vk.SwapchainCreateInfoKHR = .{
            .surface = swapchain.surface,
            .min_image_count = min_image_count,
            .image_format = to_vk.format(swapchain.desc.format),
            .image_color_space = .srgb_nonlinear_khr,
            .image_extent = surface_extent,
            .image_array_layers = 1,
            .image_usage = to_vk.usageFlags(swapchain.desc.usage),
            .image_sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = null,
            .pre_transform = capabilities.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = switch (swapchain.desc.present_mode) {
                .immediate => .immediate_khr,
                .mailbox => .mailbox_khr,
                .fifo => .fifo_khr,
                .fifo_relaxed => .fifo_relaxed_khr,
            },
            .clipped = .true,
            .old_swapchain = swapchain.swapchain,
        };

        const old = swapchain.swapchain;
        swapchain.swapchain = try d.device.createSwapchainKHR(&create_info, null);
        if (old != .null_handle) d.device.destroySwapchainKHR(old, null);

        const images = try d.device.getSwapchainImagesAllocKHR(swapchain.swapchain, d.gpa);
        defer d.gpa.free(images);

        const textures = try d.gpa.alloc(SwapchainTexture, images.len);
        errdefer d.gpa.free(textures);

        for (textures, images) |*texture, image| {
            const texture_info: gpu.TextureDesc = .{
                .type = .@"2d",
                .dimensions = .{ surface_extent.width, surface_extent.height, 1 },
                .mip_count = 1,
                .layer_count = 1,
                .format = swapchain.desc.format,
                .usage = swapchain.desc.usage,
            };

            const present_command_buffer = try d.acquireCommandBuffer(queue.queue_type);

            const begin_info: vk.CommandBufferBeginInfo = .{ .flags = .{ .simultaneous_use_bit = true } };
            try d.device.beginCommandBuffer(present_command_buffer.command_buffer, &begin_info);

            const image_barrier: vk.ImageMemoryBarrier2 = .{
                .src_stage_mask = .{ .all_commands_bit = true },
                .src_access_mask = .{ .memory_write_bit = true },
                .old_layout = .general,
                .new_layout = .present_src_khr,
                .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .image = image,
                .subresource_range = .{
                    .aspect_mask = to_vk.aspectsForFormat(texture_info.format),
                    .base_mip_level = 0,
                    .level_count = texture_info.mip_count,
                    .base_array_layer = 0,
                    .layer_count = texture_info.layer_count,
                },
            };
            const dependency_info: vk.DependencyInfo = .{
                .image_memory_barrier_count = 1,
                .p_image_memory_barriers = &.{image_barrier},
            };
            d.device.cmdPipelineBarrier2(present_command_buffer.command_buffer, &dependency_info);

            try d.device.endCommandBuffer(present_command_buffer.command_buffer);

            const default_view = try Texture.createView(d, image, texture_info, .{});

            texture.* = .{
                .texture = .{
                    .image = image,
                    .desc = texture_info,
                    .default_view = default_view,
                    .views = .empty,
                },
                .present_semaphore = try d.device.createSemaphore(&.{}, null),
                .present_command_buffer = present_command_buffer,
                .present_timeline = null,
            };
        }

        swapchain.textures = textures;
        swapchain.needs_recreate = false;
    }

    fn destroyImageResources(swapchain: *Swapchain, d: *Device) void {
        for (swapchain.textures) |*texture| {
            d.device.destroySemaphore(texture.present_semaphore, null);
            d.releaseCommandBuffer(texture.present_command_buffer);
            texture.texture.destroyOptions(d, false);
        }
        d.gpa.free(swapchain.textures);
        swapchain.textures = &.{};
    }
};

pub const CommandBuffer = struct {
    command_buffer: vk.CommandBuffer,
    queue_id: Device.QueueId,

    pipeline_layout: vk.PipelineLayout = .null_handle,
    pipeline_bind_point: vk.PipelineBindPoint = undefined,
    texture_heap_ptr: ?vk.DeviceAddress = null,

    pub fn sfSetActiveTextureHeap(
        command_buffer: *CommandBuffer,
        d: *Device,
        heap_ptr: gpu.DeviceAddress,
    ) callconv(gpu.@"callconv") void {
        setActiveTextureHeap(command_buffer, d, heap_ptr);
    }
    fn setActiveTextureHeap(
        command_buffer: *CommandBuffer,
        d: *Device,
        heap_ptr: gpu.DeviceAddress,
    ) void {
        const address: vk.DeviceAddress = heap_ptr;
        if (command_buffer.texture_heap_ptr == address) return;
        const binding_info: vk.DescriptorBufferBindingInfoEXT = .{
            .address = address,
            .usage = .{ .resource_descriptor_buffer_bit_ext = true },
        };
        d.device.cmdBindDescriptorBuffersEXT(
            command_buffer.command_buffer,
            &.{binding_info},
        );
        command_buffer.texture_heap_ptr = address;
        if (command_buffer.pipeline_layout != .null_handle) {
            command_buffer.setDescriptorBufferOffsets(d);
        }
    }

    pub fn sfSetPipeline(command_buffer: *CommandBuffer, d: *Device, pipeline: *Pipeline) callconv(gpu.@"callconv") void {
        return setPipeline(command_buffer, d, pipeline);
    }
    fn setPipeline(command_buffer: *CommandBuffer, d: *Device, pipeline: *Pipeline) void {
        d.device.cmdBindPipeline(
            command_buffer.command_buffer,
            pipeline.bind_point,
            pipeline.pipeline,
        );
        command_buffer.pipeline_layout = pipeline.pipeline_layout;
        command_buffer.pipeline_bind_point = pipeline.bind_point;
        d.device.cmdBindDescriptorBufferEmbeddedSamplersEXT(
            command_buffer.command_buffer,
            pipeline.bind_point,
            pipeline.pipeline_layout,
            1,
        );
        if (command_buffer.texture_heap_ptr != null) {
            command_buffer.setDescriptorBufferOffsets(d);
        }
    }

    pub fn sfDispatch(
        command_buffer: *CommandBuffer,
        d: *Device,
        data: gpu.DeviceAddress,
        x: u32,
        y: u32,
        z: u32,
    ) callconv(gpu.@"callconv") void {
        dispatch(command_buffer, d, data, x, y, z);
    }
    fn dispatch(
        command_buffer: *CommandBuffer,
        d: *Device,
        data: gpu.DeviceAddress,
        x: u32,
        y: u32,
        z: u32,
    ) void {
        const address: vk.DeviceAddress = data;
        d.device.cmdPushConstants(
            command_buffer.command_buffer,
            command_buffer.pipeline_layout,
            .{ .compute_bit = true },
            0,
            @sizeOf(vk.DeviceAddress),
            std.mem.asBytes(&address),
        );
        d.device.cmdDispatch(
            command_buffer.command_buffer,
            x,
            y,
            z,
        );
    }

    pub fn sfBarrier(
        command_buffer: *CommandBuffer,
        d: *Device,
        before: gpu.Stage,
        after: gpu.Stage,
        hazard: gpu.Hazard,
    ) callconv(gpu.@"callconv") void {
        barrier(command_buffer, d, before, after, hazard);
    }
    fn barrier(
        command_buffer: *CommandBuffer,
        d: *Device,
        before: gpu.Stage,
        after: gpu.Stage,
        hazard: gpu.Hazard,
    ) void {
        const src_stage = to_vk.pipelineStage(before);
        var dst_stage = to_vk.pipelineStage(after);
        var dst_access: vk.AccessFlags2 = .{
            .memory_read_bit = true,
            .memory_write_bit = true,
        };
        if (hazard.draw_arguments) {
            dst_stage.draw_indirect_bit = true;
        }
        if (hazard.depth_stencil) {
            dst_stage.early_fragment_tests_bit = true;
            dst_stage.late_fragment_tests_bit = true;
        }
        if (hazard.descriptors) {
            dst_access.descriptor_buffer_read_bit_ext = true;
        }
        const memory_barrier: vk.MemoryBarrier2 = .{
            .src_stage_mask = src_stage,
            .src_access_mask = .{ .memory_write_bit = true },
            .dst_stage_mask = dst_stage,
            .dst_access_mask = dst_access,
        };
        const dependency_info: vk.DependencyInfo = .{
            .memory_barrier_count = 1,
            .p_memory_barriers = (&memory_barrier)[0..1],
        };
        d.device.cmdPipelineBarrier2(command_buffer.command_buffer, &dependency_info);
    }

    /// 256 bytes is a typical optimal alignment for dest
    pub fn sfCopyTextureToBuffer(
        command_buffer: *CommandBuffer,
        d: *Device,
        source: gpu.DeviceAddress,
        destination: gpu.DeviceAddress,
        texture: *Texture,
    ) callconv(gpu.@"callconv") void {
        copyTextureToBuffer(command_buffer, d, source, destination, texture);
    }
    fn copyTextureToBuffer(
        command_buffer: *CommandBuffer,
        d: *Device,
        source: gpu.DeviceAddress,
        destination: gpu.DeviceAddress,
        texture: *Texture,
    ) void {
        _ = source;
        const entry, const offset = d.heap.addrToEntryAndOffset(destination);
        const region: vk.BufferImageCopy2 = .{
            .buffer_offset = offset,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = texture.desc.layer_count,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{
                .width = texture.desc.dimensions[0],
                .height = texture.desc.dimensions[1],
                .depth = texture.desc.dimensions[2],
            },
        };
        const info: vk.CopyImageToBufferInfo2 = .{
            .src_image = texture.image,
            .src_image_layout = .general,
            .dst_buffer = entry.buffer,
            .region_count = 1,
            .p_regions = (&region)[0..1],
        };
        d.device.cmdCopyImageToBuffer2(command_buffer.command_buffer, &info);
    }

    pub fn sfCopyBufferToTexture(
        command_buffer: *CommandBuffer,
        d: *Device,
        source: gpu.DeviceAddress,
        destination: gpu.DeviceAddress,
        texture: *Texture,
    ) callconv(gpu.@"callconv") void {
        copyBufferToTexture(command_buffer, d, source, destination, texture);
    }
    fn copyBufferToTexture(
        command_buffer: *CommandBuffer,
        d: *Device,
        source: gpu.DeviceAddress,
        destination: gpu.DeviceAddress,
        texture: *Texture,
    ) void {
        _ = destination;
        const entry, const offset = d.heap.addrToEntryAndOffset(source);
        const region: vk.BufferImageCopy2 = .{
            .buffer_offset = offset,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = texture.desc.layer_count,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{
                .width = texture.desc.dimensions[0],
                .height = texture.desc.dimensions[1],
                .depth = texture.desc.dimensions[2],
            },
        };
        const info: vk.CopyBufferToImageInfo2 = .{
            .dst_image = texture.image,
            .dst_image_layout = .general,
            .src_buffer = entry.buffer,
            .region_count = 1,
            .p_regions = (&region)[0..1],
        };
        d.device.cmdCopyBufferToImage2(command_buffer.command_buffer, &info);
    }

    pub fn sfBeginRenderPass(cb: *CommandBuffer, d: *Device, desc: gpu.RenderPassDesc) callconv(gpu.@"callconv") void {
        beginRenderPass(cb, d, desc);
    }
    fn beginRenderPass(cb: *CommandBuffer, d: *Device, desc: gpu.RenderPassDesc) void {
        const color_targets = if (desc.color_attachments) |color_attachments| color_attachments[0..desc.color_attachment_count] else &.{};
        std.debug.assert(color_targets.len <= 8);

        var color_attachments: [8]vk.RenderingAttachmentInfo = undefined;
        for (color_targets, 0..) |t, i| {
            const texture: *const Texture = @ptrCast(@alignCast(t.texture));
            color_attachments[i] = .{
                .image_view = texture.default_view,
                .image_layout = .general,
                .resolve_mode = .{},
                .resolve_image_view = .null_handle,
                .resolve_image_layout = .undefined,
                .load_op = to_vk.attachmentLoadOp(t.load_op),
                .store_op = to_vk.attachmentStoreOp(t.store_op),
                .clear_value = .{ .color = .{ .float_32 = t.clear_color } },
            };
        }

        var depth_attachment: vk.RenderingAttachmentInfo = undefined;
        if (desc.depth_attachment.texture) |t| {
            const texture: *const Texture = @ptrCast(@alignCast(t));
            depth_attachment = .{
                .image_view = texture.default_view,
                .image_layout = .general,
                .resolve_mode = .{},
                .resolve_image_view = .null_handle,
                .resolve_image_layout = .undefined,
                .load_op = to_vk.attachmentLoadOp(desc.depth_attachment.load_op),
                .store_op = to_vk.attachmentStoreOp(desc.depth_attachment.store_op),
                .clear_value = .{ .depth_stencil = .{ .depth = desc.depth_attachment.clear_value, .stencil = 0 } },
            };
        }

        var stencil_attachment: vk.RenderingAttachmentInfo = undefined;
        if (desc.stencil_attachment.texture) |t| {
            const texture: *const Texture = @ptrCast(@alignCast(t));
            stencil_attachment = .{
                .image_view = texture.default_view,
                .image_layout = .general,
                .resolve_mode = .{},
                .resolve_image_view = .null_handle,
                .resolve_image_layout = .undefined,
                .load_op = to_vk.attachmentLoadOp(desc.stencil_attachment.load_op),
                .store_op = to_vk.attachmentStoreOp(desc.stencil_attachment.store_op),
                .clear_value = .{ .depth_stencil = .{ .depth = 0, .stencil = desc.stencil_attachment.clear_value } },
            };
        }

        const extent: [2]u32 = blk: {
            if (color_targets.len > 0) {
                const texture: *const Texture = @ptrCast(@alignCast(color_targets[0].texture));
                break :blk .{
                    texture.desc.dimensions[0],
                    texture.desc.dimensions[1],
                };
            }
            if (desc.depth_attachment.texture) |t| {
                const texture: *const Texture = @ptrCast(@alignCast(t));
                break :blk .{ texture.desc.dimensions[0], texture.desc.dimensions[1] };
            }
            if (desc.stencil_attachment.texture) |t| {
                const texture: *const Texture = @ptrCast(@alignCast(t));
                break :blk .{ texture.desc.dimensions[0], texture.desc.dimensions[1] };
            }
            unreachable;
        };

        const rendering_info: vk.RenderingInfo = .{
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = extent[0], .height = extent[1] },
            },
            .layer_count = 1,
            .view_mask = 0,
            .color_attachment_count = @intCast(color_targets.len),
            .p_color_attachments = &color_attachments,
            .p_depth_attachment = if (desc.depth_attachment.texture != null) &depth_attachment else null,
            .p_stencil_attachment = if (desc.stencil_attachment.texture != null) &stencil_attachment else null,
        };
        d.device.cmdBeginRendering(cb.command_buffer, &rendering_info);

        d.device.cmdSetViewport(cb.command_buffer, 0, &.{.{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(extent[0]),
            .height = @floatFromInt(extent[1]),
            .min_depth = 0,
            .max_depth = 1,
        }});
        d.device.cmdSetScissor(cb.command_buffer, 0, &.{.{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = extent[0], .height = extent[1] },
        }});
        d.device.cmdSetDepthTestEnable(cb.command_buffer, .false);
        d.device.cmdSetDepthWriteEnable(cb.command_buffer, .false);
        d.device.cmdSetDepthCompareOp(cb.command_buffer, .always);
        d.device.cmdSetDepthBiasEnable(cb.command_buffer, .false);
        d.device.cmdSetStencilTestEnable(cb.command_buffer, .false);
    }

    pub fn sfEndRenderPass(cb: *CommandBuffer, d: *Device) callconv(gpu.@"callconv") void {
        endRenderPass(cb, d);
    }
    fn endRenderPass(cb: *CommandBuffer, d: *Device) void {
        d.device.cmdEndRendering(cb.command_buffer);
    }

    pub fn sfDraw(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: gpu.DeviceAddress,
        pixel_data: gpu.DeviceAddress,
        vertex_count: u32,
        instance_count: u32,
    ) callconv(gpu.@"callconv") void {
        draw(cb, d, vertex_data, pixel_data, vertex_count, instance_count);
    }
    fn draw(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: gpu.DeviceAddress,
        pixel_data: gpu.DeviceAddress,
        vertex_count: u32,
        instance_count: u32,
    ) void {
        cb.pushRootPointers(d, vertex_data, pixel_data);
        d.device.cmdDraw(cb.command_buffer, vertex_count, instance_count, 0, 0);
    }

    pub fn sfDrawIndexed(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: gpu.DeviceAddress,
        pixel_data: gpu.DeviceAddress,
        index_type: gpu.IndexType,
        indices: gpu.DeviceAddress,
        index_count: u32,
    ) callconv(gpu.@"callconv") void {
        cb.sfDrawIndexedInstanced(d, vertex_data, pixel_data, index_type, indices, index_count, 1);
    }

    pub fn sfDrawIndexedInstanced(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: gpu.DeviceAddress,
        pixel_data: gpu.DeviceAddress,
        index_type: gpu.IndexType,
        indices: gpu.DeviceAddress,
        index_count: u32,
        instance_count: u32,
    ) callconv(gpu.@"callconv") void {
        cb.pushRootPointers(d, vertex_data, pixel_data);
        cb.bindIndexPointer(d, index_type, indices);
        d.device.cmdDrawIndexed(cb.command_buffer, index_count, instance_count, 0, 0, 0);
    }

    pub fn sfDrawIndexedInstancedIndirect(
        cb: *CommandBuffer,
        d: *Device,
        vertex_data: gpu.DeviceAddress,
        pixel_data: gpu.DeviceAddress,
        index_type: gpu.IndexType,
        indices: gpu.DeviceAddress,
        args: gpu.DeviceAddress,
    ) callconv(gpu.@"callconv") void {
        cb.pushRootPointers(d, vertex_data, pixel_data);
        cb.bindIndexPointer(d, index_type, indices);
        const entry, const offset = d.heap.addrToEntryAndOffset(args);
        d.device.cmdDrawIndexedIndirect(
            cb.command_buffer,
            entry.buffer,
            offset,
            1,
            @sizeOf(gpu.DrawIndexedArguments),
        );
    }

    fn pushRootPointers(cb: *CommandBuffer, d: *Device, vertex_data: u64, pixel_data: u64) void {
        const addresses = [2]u64{ vertex_data, pixel_data };
        d.device.cmdPushConstants(
            cb.command_buffer,
            cb.pipeline_layout,
            .{ .vertex_bit = true, .fragment_bit = true },
            0,
            @sizeOf(vk.DeviceAddress) * 2,
            std.mem.asBytes(&addresses),
        );
    }

    fn bindIndexPointer(
        cb: *CommandBuffer,
        d: *Device,
        index_type: gpu.IndexType,
        indices: gpu.DeviceAddress,
    ) void {
        const vk_index_type: vk.IndexType = switch (index_type) {
            .uint16 => .uint16,
            .uint32 => .uint32,
        };
        const entry, const offset = d.heap.addrToEntryAndOffset(indices);
        d.device.cmdBindIndexBuffer(cb.command_buffer, entry.buffer, offset, vk_index_type);
    }

    fn setDescriptorBufferOffsets(command_buffer: *CommandBuffer, d: *const Device) void {
        d.device.cmdSetDescriptorBufferOffsetsEXT(
            command_buffer.command_buffer,
            command_buffer.pipeline_bind_point,
            command_buffer.pipeline_layout,
            0,
            &.{0},
            &.{0},
        );
    }
};

pub const Texture = struct {
    image: vk.Image,
    desc: Desc,
    default_view: vk.ImageView,
    views: std.hash_map.AutoHashMapUnmanaged(gpu.TextureViewDesc, vk.ImageView),

    const Type = gpu.TextureType;
    const Usage = gpu.TextureUsage;
    const Desc = gpu.TextureDesc;

    pub const Descriptor = opaque {
        pub fn sfDescriptorSizeAndHeapAlign(d: *Device) callconv(gpu.@"callconv") gpu.SizeAndAlign {
            return sizeAndHeapAlignment(d);
        }
        fn sizeAndHeapAlignment(d: *Device) gpu.SizeAndAlign {
            const buffer_properties = d.descriptorBufferProperties();
            return .{
                .size = @max(
                    buffer_properties.sampled_image_descriptor_size,
                    buffer_properties.storage_image_descriptor_size,
                ),
                .alignment = buffer_properties.descriptor_buffer_offset_alignment,
            };
        }

        pub fn sfStoreDescriptor(descriptor: *const gpu.Descriptor, d: *Device, heap_ptr: [*]u8, index: usize) callconv(gpu.@"callconv") void {
            const size_align = Descriptor.sfDescriptorSizeAndHeapAlign(d);
            @memcpy(
                @as([*]u8, @ptrCast(heap_ptr)) + size_align.size * index,
                descriptor.data[0..size_align.size],
            );
        }
    };

    pub fn sfTextureSizeAndAlign(d: *Device, info: Desc) callconv(gpu.@"callconv") gpu.SizeAndAlign {
        return sizeAndAlignment(d, info);
    }
    fn sizeAndAlignment(d: *Device, info: Desc) gpu.SizeAndAlign {
        const device_image_memory_requirements: vk.DeviceImageMemoryRequirements = .{
            .p_create_info = &vkImageInfo(info),
            .plane_aspect = to_vk.aspectsForFormat(info.format),
        };
        var req: vk.MemoryRequirements2 = .{ .memory_requirements = undefined };
        d.device.getDeviceImageMemoryRequirements(&device_image_memory_requirements, &req);
        return .{
            .size = req.memory_requirements.size,
            .alignment = req.memory_requirements.alignment,
        };
    }

    pub fn sfCreateTexture(d: *Device, info: Desc, texture_data: gpu.DeviceAddress) callconv(gpu.@"callconv") *Texture {
        return create(d, info, texture_data) catch @panic("TODO");
    }
    fn create(d: *Device, info: Desc, texture_data: gpu.DeviceAddress) !*Texture {
        const image = try d.device.createImage(&vkImageInfo(info), null);
        errdefer d.device.destroyImage(image, null);

        const entry, const offset = d.heap.addrToEntryAndOffset(texture_data);
        try d.device.bindImageMemory(image, entry.memory, offset);

        const default_view = try createView(d, image, info, .{});
        errdefer d.device.destroyImageView(default_view, null);

        try d.pending_general_layout_transitions.put(d.gpa, image, info);
        const texture = try d.gpa.create(Texture);
        texture.* = .{
            .image = image,
            .desc = info,
            .default_view = default_view,
            .views = .empty,
        };
        return texture;
    }

    pub fn sfDestroyTexture(texture: *Texture, d: *Device) callconv(gpu.@"callconv") void {
        destroy(texture, d);
    }
    fn destroy(texture: *Texture, d: *Device) void {
        texture.destroyOptions(d, true);
        d.gpa.destroy(texture);
    }

    fn destroyOptions(texture: *Texture, d: *Device, owns_vk_image: bool) void {
        _ = d.pending_general_layout_transitions.swapRemove(texture.image);
        if (owns_vk_image) d.device.destroyImage(texture.image, null);
        d.device.destroyImageView(texture.default_view, null);
        var it = texture.views.valueIterator();
        while (it.next()) |view| d.device.destroyImageView(view.*, null);
        texture.views.clearRetainingCapacity();
        texture.views.deinit(d.gpa);
    }

    pub fn sfTextureStorageDescriptor(texture: *Texture, d: *Device, view_info: gpu.TextureViewDesc) callconv(gpu.@"callconv") gpu.Descriptor {
        return storageDescriptor(texture, d, view_info) catch @panic("TODO");
    }
    fn storageDescriptor(texture: *Texture, d: *Device, view_info: gpu.TextureViewDesc) !gpu.Descriptor {
        const view = texture.views.get(view_info) orelse blk: {
            const view = try createView(d, texture.image, texture.desc, view_info);
            try texture.views.put(d.gpa, view_info, view);
            break :blk view;
        };
        const image_info: vk.DescriptorImageInfo = .{
            .image_view = view,
            .image_layout = .general,
            .sampler = .null_handle,
        };
        const get_info: vk.DescriptorGetInfoEXT = .{
            .type = .storage_image,
            .data = .{ .p_storage_image = &image_info },
        };
        const buffer_properties = d.descriptorBufferProperties();
        var descriptor: gpu.Descriptor = .{ .data = @splat(0) };
        d.device.getDescriptorEXT(&get_info, buffer_properties.storage_image_descriptor_size, @ptrCast(&descriptor.data));
        return descriptor;
    }

    pub fn sfTextureViewDescriptor(texture: *Texture, d: *Device, view_info: gpu.TextureViewDesc) callconv(gpu.@"callconv") gpu.Descriptor {
        return viewDescriptor(texture, d, view_info) catch @panic("TODO");
    }
    fn viewDescriptor(
        texture: *Texture,
        d: *Device,
        view_info: gpu.TextureViewDesc,
    ) !gpu.Descriptor {
        const view = texture.views.get(view_info) orelse blk: {
            const view = try createView(d, texture.image, texture.desc, view_info);
            try texture.views.put(d.gpa, view_info, view);
            break :blk view;
        };
        const image_info: vk.DescriptorImageInfo = .{
            .image_view = view,
            .image_layout = .general,
            .sampler = .null_handle,
        };
        const get_info: vk.DescriptorGetInfoEXT = .{
            .type = .sampled_image,
            .data = .{ .p_sampled_image = &image_info },
        };
        const properties = d.descriptorBufferProperties();
        var descriptor: gpu.Descriptor = .{ .data = @splat(0) };
        d.device.getDescriptorEXT(&get_info, properties.sampled_image_descriptor_size, @ptrCast(&descriptor.data));
        return descriptor;
    }

    fn vkImageInfo(info: Desc) vk.ImageCreateInfo {
        return .{
            .image_type = to_vk.textureType(info.type),
            .format = to_vk.format(info.format),
            .extent = .{ .width = info.dimensions[0], .height = info.dimensions[1], .depth = info.dimensions[2] },
            .mip_levels = info.mip_count,
            .array_layers = info.layer_count,
            .samples = .{ .@"1_bit" = true },
            .tiling = .optimal,
            .usage = to_vk.usageFlags(info.usage),
            .sharing_mode = .exclusive,
            .initial_layout = .undefined,
        };
    }

    fn createView(d: *Device, image: vk.Image, texture_info: Desc, view_info: gpu.TextureViewDesc) !vk.ImageView {
        const mip_count = if (view_info.mip_count == gpu.all_mips) vk.REMAINING_MIP_LEVELS else view_info.mip_count;
        const layer_count = if (view_info.layer_count == gpu.all_layers) vk.REMAINING_ARRAY_LAYERS else view_info.layer_count;
        const format = if (view_info.format == .none) texture_info.format else view_info.format;
        const info: vk.ImageViewCreateInfo = .{
            .image = image,
            .view_type = to_vk.viewType(texture_info.type),
            .format = to_vk.format(format),
            .subresource_range = .{
                .aspect_mask = to_vk.aspectsForFormat(texture_info.format),
                .base_mip_level = view_info.base_mip,
                .level_count = mip_count,
                .base_array_layer = view_info.base_layer,
                .layer_count = layer_count,
            },
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        };
        return d.device.createImageView(&info, null);
    }
};

pub const Pipeline = struct {
    pipeline: vk.Pipeline,
    pipeline_layout: vk.PipelineLayout,
    bind_point: vk.PipelineBindPoint,

    samplers: []vk.Sampler,
    sampler_set_layout: vk.DescriptorSetLayout,

    pub fn sfCreateComputePipeline(d: *Device, ir_size: usize, ir: [*]const u8) callconv(gpu.@"callconv") *Pipeline {
        return createCompute(d, ir[0..ir_size]) catch @panic("TODO");
    }
    fn createCompute(d: *Device, ir: []const u8) !*Pipeline {
        const parser = try sfir.parse(ir);
        const spirv = try parser.spirvAlloc(d.gpa);
        defer d.gpa.free(spirv);
        const module = try d.device.createShaderModule(&.{
            .code_size = spirv.len * @sizeOf(u32),
            .p_code = spirv.ptr,
        }, null);
        defer d.device.destroyShaderModule(module, null);

        const stage: vk.PipelineShaderStageCreateInfo = .{
            .stage = .{ .compute_bit = true },
            .module = module,
            .p_name = "main",
        };

        const samplers = try d.gpa.alloc(vk.Sampler, parser.samplerCount());
        var vertex_sampler_it = parser.samplerIterator();
        for (samplers) |*sampler| {
            const sampler_info = vertex_sampler_it.next().?;
            const sampler_create_info = to_vk.samplerCreateInfo(sampler_info);
            sampler.* = try d.device.createSampler(&sampler_create_info, null);
        }

        const push_constant_ranges = [_]vk.PushConstantRange{.{
            .stage_flags = .{ .compute_bit = true },
            .offset = 0,
            .size = @sizeOf(vk.DeviceAddress),
        }};
        const sampler_set_layout = try createSamplerSetLayout(d, samplers, &.{});
        const pipeline_layout = try createPipelineLayout(d, sampler_set_layout, &push_constant_ranges);

        const info: vk.ComputePipelineCreateInfo = .{
            .flags = .{ .descriptor_buffer_bit_ext = true },
            .stage = stage,
            .layout = pipeline_layout,
            .base_pipeline_index = -1,
        };
        var handle: vk.Pipeline = undefined;
        _ = try d.device.createComputePipelines(.null_handle, &.{info}, null, (&handle)[0..1]);

        const pipeline = try d.gpa.create(Pipeline);
        pipeline.* = .{
            .pipeline = handle,
            .pipeline_layout = pipeline_layout,
            .bind_point = .compute,

            .samplers = samplers,
            .sampler_set_layout = sampler_set_layout,
        };
        return pipeline;
    }

    pub fn sfCreateGraphicsPipeline(
        d: *Device,
        vertex_ir_size: usize,
        vertex_ir: [*]const u8,
        pixel_ir_size: usize,
        pixel_ir: [*]const u8,
        desc: gpu.GraphicsPipelineDesc,
    ) callconv(gpu.@"callconv") *Pipeline {
        return @ptrCast(createGraphics(d, vertex_ir[0..vertex_ir_size], pixel_ir[0..pixel_ir_size], desc) catch @panic("TODO"));
    }
    fn createGraphics(
        d: *Device,
        vertex_ir: []const u8,
        pixel_ir: []const u8,
        desc: gpu.GraphicsPipelineDesc,
    ) !*Pipeline {
        const color_targets = if (desc.color_targets) |color_targets| color_targets[0..desc.color_target_count] else &.{};
        std.debug.assert(color_targets.len <= 8);

        const vertex_parser = try sfir.parse(vertex_ir);
        const vertex_spirv = try vertex_parser.spirvAlloc(d.gpa);
        defer d.gpa.free(vertex_spirv);
        const vert_module = try d.device.createShaderModule(&.{
            .code_size = vertex_spirv.len * @sizeOf(u32),
            .p_code = vertex_spirv.ptr,
        }, null);
        defer d.device.destroyShaderModule(vert_module, null);

        const pixel_parser = try sfir.parse(pixel_ir);
        const pixel_spirv = try pixel_parser.spirvAlloc(d.gpa);
        defer d.gpa.free(pixel_spirv);
        const frag_module = try d.device.createShaderModule(&.{
            .code_size = pixel_spirv.len * @sizeOf(u32),
            .p_code = pixel_spirv.ptr,
        }, null);
        defer d.device.destroyShaderModule(frag_module, null);

        const stages = [_]vk.PipelineShaderStageCreateInfo{
            .{ .stage = .{ .vertex_bit = true }, .module = vert_module, .p_name = "main" },
            .{ .stage = .{ .fragment_bit = true }, .module = frag_module, .p_name = "main" },
        };

        const vertex_input: vk.PipelineVertexInputStateCreateInfo = .{};

        const input_assembly: vk.PipelineInputAssemblyStateCreateInfo = .{
            .topology = to_vk.topology(desc.topology),
            .primitive_restart_enable = .false,
        };

        const viewport_state: vk.PipelineViewportStateCreateInfo = .{
            .viewport_count = 1,
            .scissor_count = 1,
        };

        const rasterization: vk.PipelineRasterizationStateCreateInfo = .{
            .depth_clamp_enable = .false,
            .rasterizer_discard_enable = .false,
            .polygon_mode = .fill,
            .cull_mode = to_vk.cullMode(desc.cull),
            .front_face = .counter_clockwise,
            .depth_bias_enable = .false,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1,
        };

        const multisample: vk.PipelineMultisampleStateCreateInfo = .{
            .rasterization_samples = to_vk.sampleCount(@intCast(desc.sample_count)),
            .sample_shading_enable = .false,
            .min_sample_shading = 0,
            .alpha_to_coverage_enable = if (desc.alpha_to_coverage) .true else .false,
            .alpha_to_one_enable = .false,
        };

        const stencil_placeholder: vk.StencilOpState = std.mem.zeroInit(vk.StencilOpState, .{});
        const depth_stencil: vk.PipelineDepthStencilStateCreateInfo = .{
            .depth_test_enable = .false,
            .depth_write_enable = .false,
            .depth_compare_op = .always,
            .depth_bounds_test_enable = .false,
            .stencil_test_enable = .false,
            .front = stencil_placeholder,
            .back = stencil_placeholder,
            .min_depth_bounds = 0,
            .max_depth_bounds = 1,
        };

        var color_formats: [8]vk.Format = undefined;
        var blend_attachments: [8]vk.PipelineColorBlendAttachmentState = undefined;
        for (color_targets, 0..) |t, i| {
            color_formats[i] = to_vk.format(t.format);
            blend_attachments[i] = if (desc.blend_state) |bs| .{
                .blend_enable = .true,
                .src_color_blend_factor = to_vk.blendFactor(bs.src_color_factor),
                .dst_color_blend_factor = to_vk.blendFactor(bs.dst_color_factor),
                .color_blend_op = to_vk.blendOp(bs.color_op),
                .src_alpha_blend_factor = to_vk.blendFactor(bs.src_alpha_factor),
                .dst_alpha_blend_factor = to_vk.blendFactor(bs.dst_alpha_factor),
                .alpha_blend_op = to_vk.blendOp(bs.alpha_op),
                .color_write_mask = to_vk.writeMask(t.write_mask),
            } else .{
                .blend_enable = .false,
                .src_color_blend_factor = .one,
                .dst_color_blend_factor = .zero,
                .color_blend_op = .add,
                .src_alpha_blend_factor = .one,
                .dst_alpha_blend_factor = .zero,
                .alpha_blend_op = .add,
                .color_write_mask = to_vk.writeMask(t.write_mask),
            };
        }
        const color_blend: vk.PipelineColorBlendStateCreateInfo = .{
            .logic_op_enable = .false,
            .logic_op = .copy,
            .attachment_count = @intCast(color_targets.len),
            .p_attachments = &blend_attachments,
            .blend_constants = .{ 0, 0, 0, 0 },
        };

        const dynamic_states = [_]vk.DynamicState{
            .viewport,
            .scissor,
            .depth_test_enable,
            .depth_write_enable,
            .depth_compare_op,
            .depth_bias_enable,
            .depth_bias,
            .stencil_test_enable,
            .stencil_op,
            .stencil_compare_mask,
            .stencil_write_mask,
            .stencil_reference,
        };
        const dynamic_state: vk.PipelineDynamicStateCreateInfo = .{
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        };

        const samplers = try d.gpa.alloc(
            vk.Sampler,
            vertex_parser.samplerCount() + pixel_parser.samplerCount(),
        );
        var sampler_i: usize = 0;
        var vertex_sampler_it = vertex_parser.samplerIterator();
        while (vertex_sampler_it.next()) |sampler_info| : (sampler_i += 1) {
            const sampler_create_info = to_vk.samplerCreateInfo(sampler_info);
            samplers[sampler_i] = try d.device.createSampler(&sampler_create_info, null);
        }
        const vertex_samplers = samplers[0..sampler_i];

        var pixel_sampler_it = pixel_parser.samplerIterator();
        while (pixel_sampler_it.next()) |sampler_info| : (sampler_i += 1) {
            const sampler_create_info = to_vk.samplerCreateInfo(sampler_info);
            samplers[sampler_i] = try d.device.createSampler(&sampler_create_info, null);
        }
        const pixel_samplers = samplers[vertex_samplers.len..sampler_i];

        const push_constant_range: vk.PushConstantRange = .{
            .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
            .offset = 0,
            .size = @sizeOf(vk.DeviceAddress) * 2,
        };
        const sampler_set_layout = try createSamplerSetLayout(d, vertex_samplers, pixel_samplers);
        const pipeline_layout = try createPipelineLayout(d, sampler_set_layout, &.{push_constant_range});

        const rendering_info: vk.PipelineRenderingCreateInfo = .{
            .view_mask = 0,
            .color_attachment_count = @intCast(color_targets.len),
            .p_color_attachment_formats = &color_formats,
            .depth_attachment_format = to_vk.format(desc.depth_format),
            .stencil_attachment_format = to_vk.format(desc.stencil_format),
        };
        const info: vk.GraphicsPipelineCreateInfo = .{
            .p_next = &rendering_info,
            .flags = .{ .descriptor_buffer_bit_ext = true },
            .stage_count = stages.len,
            .p_stages = &stages,
            .p_vertex_input_state = &vertex_input,
            .p_input_assembly_state = &input_assembly,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterization,
            .p_multisample_state = &multisample,
            .p_depth_stencil_state = &depth_stencil,
            .p_color_blend_state = &color_blend,
            .p_dynamic_state = &dynamic_state,
            .layout = pipeline_layout,
            .render_pass = .null_handle,
            .subpass = 0,
            .base_pipeline_index = -1,
        };
        var handle: vk.Pipeline = undefined;
        _ = try d.device.createGraphicsPipelines(.null_handle, &.{info}, null, (&handle)[0..1]);

        const pipeline = try d.gpa.create(Pipeline);
        pipeline.* = .{
            .pipeline = handle,
            .pipeline_layout = pipeline_layout,
            .bind_point = .graphics,

            .samplers = samplers,
            .sampler_set_layout = sampler_set_layout,
        };
        return pipeline;
    }

    pub fn sfDestroyPipeline(pipeline: *Pipeline, d: *Device) callconv(gpu.@"callconv") void {
        destroy(pipeline, d);
    }
    fn destroy(pipeline: *Pipeline, d: *Device) void {
        d.device.destroyPipeline(pipeline.pipeline, null);
        d.device.destroyPipelineLayout(pipeline.pipeline_layout, null);
        d.device.destroyDescriptorSetLayout(pipeline.sampler_set_layout, null);
        for (pipeline.samplers) |sampler| d.device.destroySampler(sampler, null);
        d.gpa.free(pipeline.samplers);
        d.gpa.destroy(pipeline);
    }

    fn createSamplerSetLayout(
        d: *Device,
        samplers: []const vk.Sampler,
        pixel_samplers: []const vk.Sampler,
    ) !vk.DescriptorSetLayout {
        var sampler_bindings: [2]vk.DescriptorSetLayoutBinding = undefined;
        var sampler_bindings_count: u32 = 0;

        if (samplers.len != 0) {
            sampler_bindings[sampler_bindings_count] = .{
                .binding = 0,
                .descriptor_type = .sampler,
                .descriptor_count = @intCast(samplers.len),
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true, .compute_bit = true },
                .p_immutable_samplers = samplers.ptr,
            };
            sampler_bindings_count += 1;
        }
        if (pixel_samplers.len != 0) {
            sampler_bindings[sampler_bindings_count] = .{
                .binding = 1,
                .descriptor_type = .sampler,
                .descriptor_count = @intCast(pixel_samplers.len),
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true, .compute_bit = true },
                .p_immutable_samplers = pixel_samplers.ptr,
            };
            sampler_bindings_count += 1;
        }

        const sampler_layout_info: vk.DescriptorSetLayoutCreateInfo = .{
            .flags = .{
                .descriptor_buffer_bit_ext = true,
                .embedded_immutable_samplers_bit_ext = true,
            },
            .binding_count = sampler_bindings_count,
            .p_bindings = &sampler_bindings,
        };
        return try d.device.createDescriptorSetLayout(&sampler_layout_info, null);
    }

    fn createPipelineLayout(
        d: *Device,
        sampler_set_layout: vk.DescriptorSetLayout,
        push_constant_ranges: []const vk.PushConstantRange,
    ) !vk.PipelineLayout {
        const set_layouts = [_]vk.DescriptorSetLayout{
            d.texture_heap_set_layout,
            sampler_set_layout,
        };
        const pipeline_layout_info: vk.PipelineLayoutCreateInfo = .{
            .push_constant_range_count = @intCast(push_constant_ranges.len),
            .p_push_constant_ranges = push_constant_ranges.ptr,
            .set_layout_count = set_layouts.len,
            .p_set_layouts = &set_layouts,
        };
        return try d.device.createPipelineLayout(&pipeline_layout_info, null);
    }
};

pub const heap = struct {
    pub fn sfMalloc(
        d: *Device,
        bytes: usize,
        alignment: usize,
        memory: gpu.Memory,
    ) callconv(gpu.@"callconv") gpu.DeviceAddress {
        return malloc(d, bytes, .fromByteUnits(alignment), memory) catch @panic("TODO");
    }
    fn malloc(
        d: *Device,
        bytes: usize,
        alignment: std.mem.Alignment,
        memory: gpu.Memory,
    ) !gpu.DeviceAddress {
        std.debug.assert(bytes > 0);

        const usage: vk.BufferUsageFlags = switch (memory) {
            .default => .{
                .storage_buffer_bit = true,
                .index_buffer_bit = true,
                .indirect_buffer_bit = true,
                .transfer_src_bit = true,
                .shader_device_address_bit = true,
                .resource_descriptor_buffer_bit_ext = true,
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

        var families_buf: [Device.max_queue_state_count]u32 = undefined;
        for (d.queue_states[0..d.queue_state_count], 0..) |q, i| families_buf[i] = q.family;
        const families = families_buf[0..d.queue_state_count];

        const concurrent = families.len > 1;
        var buffer_info: vk.BufferCreateInfo = .{
            .size = bytes,
            .usage = usage,
            .sharing_mode = if (concurrent) .concurrent else .exclusive,
            .queue_family_index_count = if (concurrent) @intCast(families.len) else 0,
            .p_queue_family_indices = if (concurrent) families.ptr else null,
        };
        var buffer = try d.device.createBuffer(&buffer_info, null);
        errdefer d.device.destroyBuffer(buffer, null);

        var buffer_memory_requirements = d.device.getBufferMemoryRequirements(buffer);

        const padded = buffer_memory_requirements.alignment < alignment.toByteUnits();
        if (padded) {
            d.device.destroyBuffer(buffer, null);
            buffer_info.size = bytes + alignment.toByteUnits() - 1;
            buffer = try d.device.createBuffer(&buffer_info, null);
            buffer_memory_requirements = d.device.getBufferMemoryRequirements(buffer);
        }

        const memory_type_bits = switch (memory) {
            .default, .readback => buffer_memory_requirements.memory_type_bits,
            .gpu => bits: {
                const color_bits = probeImageMemoryTypeBits(d.*, .r8g8b8a8_unorm, .{
                    .sampled_bit = true,
                    .transfer_dst_bit = true,
                    .color_attachment_bit = true,
                });
                const depth_bits = probeImageMemoryTypeBits(d.*, .d32_sfloat, .{
                    .depth_stencil_attachment_bit = true,
                    .sampled_bit = true,
                });
                break :bits buffer_memory_requirements.memory_type_bits & color_bits & depth_bits;
            },
        };

        const properties: vk.MemoryPropertyFlags = switch (memory) {
            .default => .{
                .device_local_bit = d.has_host_visible_device_local,
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
        const buffer_memory = try d.device.allocateMemory(&.{
            .p_next = &alloc_flags,
            .allocation_size = buffer_memory_requirements.size,
            .memory_type_index = findMemoryType(d.*, memory_type_bits, properties),
        }, null);
        errdefer d.device.freeMemory(buffer_memory, null);

        try d.device.bindBufferMemory(buffer, buffer_memory, 0);

        const raw_device_addr = d.device.getBufferDeviceAddress(&.{ .buffer = buffer });
        const device_addr = std.mem.alignForward(u64, raw_device_addr, alignment.toByteUnits());
        const delta: usize = @intCast(device_addr - raw_device_addr);
        if (!padded) std.debug.assert(delta == 0);
        std.debug.assert(delta + bytes <= buffer_info.size);

        const host_addr: ?usize = switch (memory) {
            .readback, .default => @intFromPtr(
                try d.device.mapMemory(buffer_memory, 0, vk.WHOLE_SIZE, .{}),
            ) + delta,
            .gpu => null,
        };

        try d.heap.insert(d.gpa, .{
            .buffer = buffer,
            .memory = buffer_memory,
            .size = bytes,
            .device_addr = device_addr,
            .host_addr = host_addr,
        });

        return device_addr;
    }

    pub fn sfFree(d: *Device, ptr: gpu.DeviceAddress) callconv(gpu.@"callconv") void {
        free(d, ptr);
    }
    fn free(d: *Device, ptr: gpu.DeviceAddress) void {
        const index = d.heap.indexFromAddr(ptr);
        var entry = d.heap.entries.orderedRemove(index);
        entry.destroy(d.*);
    }

    // TODO: cache this
    fn findMemoryType(d: Device, type_filter: u32, properties: vk.MemoryPropertyFlags) u32 {
        for (0..d.memory_properties.memory_type_count) |i| {
            if ((type_filter & (@as(u32, 1) << @intCast(i))) != 0 and
                (d.memory_properties.memory_types[i].property_flags.intersect(properties)) == properties)
            {
                return @intCast(i);
            }
        }
        @panic(""); // TODO
    }

    // TODO: cache this
    fn probeImageMemoryTypeBits(d: Device, format: vk.Format, usage: vk.ImageUsageFlags) u32 {
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

const wrap_sf_allocator = struct {
    fn alloc(user_data: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const sf_gpa: *gpu.Allocator = @ptrCast(@alignCast(user_data));
        return sf_gpa.alloc(sf_gpa.user_data, len, alignment.toByteUnits());
    }
    fn remap(user_data: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const sf_gpa: *gpu.Allocator = @ptrCast(@alignCast(user_data));
        return sf_gpa.remap(sf_gpa.user_data, memory.ptr, memory.len, alignment.toByteUnits(), new_len);
    }
    fn free(user_data: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        _ = ret_addr;
        const sf_gpa: *gpu.Allocator = @ptrCast(@alignCast(user_data));
        return sf_gpa.free(sf_gpa.user_data, memory.ptr, memory.len, alignment.toByteUnits());
    }
};
const wrap_sf_allocator_vtable: *const std.mem.Allocator.VTable = &.{
    .alloc = wrap_sf_allocator.alloc,
    .remap = wrap_sf_allocator.remap,
    .free = wrap_sf_allocator.free,
    .resize = std.mem.Allocator.noResize,
};

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
    if (message_severity.error_bit_ext or message_severity.warning_bit_ext) {
        std.debug.dumpCurrentStackTrace(.{});
    }
    return .false;
}

fn checkFunctionSignature(comptime ImplFn: type, comptime InterfaceFn: type) bool {
    if (ImplFn == InterfaceFn) return true;
    const a = @typeInfo(ImplFn);
    const b = @typeInfo(InterfaceFn);
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
    return switch (b) {
        .@"fn" => |bf| blk: {
            const af = a.@"fn";
            if (af.params.len != bf.params.len) break :blk false;
            if (!std.meta.eql(af.calling_convention, bf.calling_convention)) break :blk false;
            for (af.params, bf.params) |pa, pb| if (!checkFunctionSignature(pa.type.?, pb.type.?)) break :blk false;
            break :blk checkFunctionSignature(af.return_type.?, bf.return_type.?);
        },
        .pointer => |bp| bp.size == a.pointer.size and
            bp.is_const == a.pointer.is_const and
            (@typeInfo(bp.child) == .@"opaque" or checkFunctionSignature(a.pointer.child, bp.child)),
        .optional => |bo| checkFunctionSignature(a.optional.child, bo.child),
        else => false,
    };
}

inline fn symbol(interface_func: anytype, func: anytype, name: []const u8) void {
    if (!checkFunctionSignature(@TypeOf(func), @TypeOf(interface_func))) @compileError("type mismatch");
    @export(&func, .{ .name = name });
}

comptime {
    @setEvalBranchQuota(10000);
    symbol(gpu.createInstance, Instance.sfCreateInstance, "sfCreateInstance");
    symbol(gpu.destroyInstance, Instance.sfDestroyInstance, "sfDestroyInstance");
    symbol(gpu.enumerateAdapters, Instance.sfEnumerateAdapters, "sfEnumerateAdapters");
    symbol(gpu.createSurfaceWin32, Surface.sfCreateSurfaceWin32, "sfCreateSurfaceWin32");
    symbol(gpu.createSurfaceXlib, Surface.sfCreateSurfaceXlib, "sfCreateSurfaceXlib");
    symbol(gpu.destroySurface, Surface.sfDestroySurface, "sfDestroySurface");
    symbol(gpu.surfaceSupportedUsage, Device.sfSurfaceSupportedUsage, "sfSurfaceSupportedUsage");
    symbol(gpu.surfaceFormats, Device.sfSurfaceFormats, "sfSurfaceFormats");
    symbol(gpu.surfacePresentModes, Device.sfSurfacePresentModes, "sfSurfacePresentModes");
    symbol(gpu.createDevice, Device.sfCreateDevice, "sfCreateDevice");
    symbol(gpu.destroyDevice, Device.sfDestroyDevice, "sfDestroyDevice");
    symbol(gpu.deviceToHostPointer, Device.sfDeviceToHostPointer, "sfDeviceToHostPointer");
    symbol(gpu.malloc, heap.sfMalloc, "sfMalloc");
    symbol(gpu.free, heap.sfFree, "sfFree");
    symbol(gpu.descriptorSizeAndHeapAlign, Texture.Descriptor.sfDescriptorSizeAndHeapAlign, "sfDescriptorSizeAndHeapAlign");
    symbol(gpu.storeDescriptor, Texture.Descriptor.sfStoreDescriptor, "sfStoreDescriptor");
    symbol(gpu.createQueue, Queue.sfCreateQueue, "sfCreateQueue");
    symbol(gpu.startCommandRecording, Queue.sfStartCommandRecording, "sfStartCommandRecording");
    symbol(gpu.submit, Queue.sfSubmit, "sfSubmit");
    symbol(gpu.submitAndSignal, Queue.sfSubmitAndSignal, "sfSubmitAndSignal");
    symbol(gpu.createSemaphore, Semaphore.sfCreateSemaphore, "sfCreateSemaphore");
    symbol(gpu.destroySemaphore, Semaphore.sfDestroySemaphore, "sfDestroySemaphore");
    symbol(gpu.waitSemaphore, Semaphore.sfWaitSemaphore, "sfWaitSemaphore");
    symbol(gpu.createSwapchain, Swapchain.sfCreateSwapchain, "sfCreateSwapchain");
    symbol(gpu.destroySwapchain, Swapchain.sfDestroySwapchain, "sfDestroySwapchain");
    symbol(gpu.swapchainAcquireNextTexture, Swapchain.sfSwapchainAcquireNextTexture, "sfSwapchainAcquireNextTexture");
    symbol(gpu.swapchainPresent, Swapchain.sfSwapchainPresent, "sfSwapchainPresent");
    symbol(gpu.setActiveTextureHeap, CommandBuffer.sfSetActiveTextureHeap, "sfSetActiveTextureHeap");
    symbol(gpu.setPipeline, CommandBuffer.sfSetPipeline, "sfSetPipeline");
    symbol(gpu.dispatch, CommandBuffer.sfDispatch, "sfDispatch");
    symbol(gpu.barrier, CommandBuffer.sfBarrier, "sfBarrier");
    symbol(gpu.copyTextureToBuffer, CommandBuffer.sfCopyTextureToBuffer, "sfCopyTextureToBuffer");
    symbol(gpu.copyBufferToTexture, CommandBuffer.sfCopyBufferToTexture, "sfCopyBufferToTexture");
    symbol(gpu.beginRenderPass, CommandBuffer.sfBeginRenderPass, "sfBeginRenderPass");
    symbol(gpu.endRenderPass, CommandBuffer.sfEndRenderPass, "sfEndRenderPass");
    symbol(gpu.draw, CommandBuffer.sfDraw, "sfDraw");
    symbol(gpu.drawIndexed, CommandBuffer.sfDrawIndexed, "sfDrawIndexed");
    symbol(gpu.drawIndexedInstanced, CommandBuffer.sfDrawIndexedInstanced, "sfDrawIndexedInstanced");
    symbol(gpu.drawIndexedInstancedIndirect, CommandBuffer.sfDrawIndexedInstancedIndirect, "sfDrawIndexedInstancedIndirect");
    symbol(gpu.textureSizeAndAlign, Texture.sfTextureSizeAndAlign, "sfTextureSizeAndAlign");
    symbol(gpu.createTexture, Texture.sfCreateTexture, "sfCreateTexture");
    symbol(gpu.destroyTexture, Texture.sfDestroyTexture, "sfDestroyTexture");
    symbol(gpu.textureStorageDescriptor, Texture.sfTextureStorageDescriptor, "sfTextureStorageDescriptor");
    symbol(gpu.textureViewDescriptor, Texture.sfTextureViewDescriptor, "sfTextureViewDescriptor");
    symbol(gpu.createComputePipeline, Pipeline.sfCreateComputePipeline, "sfCreateComputePipeline");
    symbol(gpu.createGraphicsPipeline, Pipeline.sfCreateGraphicsPipeline, "sfCreateGraphicsPipeline");
    symbol(gpu.destroyPipeline, Pipeline.sfDestroyPipeline, "sfDestroyPipeline");
}
