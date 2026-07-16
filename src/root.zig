pub const Instance = struct {
    instance: vk.InstanceProxy,
    presentation_supported: bool,

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
        return .{
            .instance = instance,
            .presentation_supported = required_surface_extensions.len != 0,
        };
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

    queue_family_indices: std.EnumArray(QueueType, u32),
    queue_indices: std.EnumArray(QueueType, u32),
    command_pools: std.EnumArray(QueueType, vk.CommandPool),

    debug_messenger: vk.DebugUtilsMessengerEXT,
    gpa: std.mem.Allocator,

    heap: Heap,

    descriptor_buffer_properties: ?vk.PhysicalDeviceDescriptorBufferPropertiesEXT,

    descriptor_set_layout: vk.DescriptorSetLayout,
    pipeline_layout: vk.PipelineLayout,

    undefined_layout_textures: std.array_hash_map.Auto(vk.Image, Texture.Config),

    memory_properties: vk.PhysicalDeviceMemoryProperties,
    memory_supports_host_visible: bool,

    const Heap = struct {
        entries: std.ArrayList(Entry),

        const Entry = struct {
            buffer: vk.Buffer,
            memory: vk.DeviceMemory,
            size: usize,
            gpu_addr: usize,
            cpu_addr: ?usize,

            fn destroy(entry: Entry, d: Device) void {
                d.device.destroyBuffer(entry.buffer, null);
                d.device.freeMemory(entry.memory, null);
            }
        };

        fn entryFromAddr(heap: *const Heap, gpu_addr: usize) Entry {
            return heap.entries.items[heap.indexFromAddr(gpu_addr)];
        }

        fn entryAndOffsetFromAddr(heap: *const Heap, gpu_addr: usize) struct { Entry, vk.DeviceSize } {
            const entry = heap.entryFromAddr(gpu_addr);
            const offset = gpu_addr - entry.gpu_addr;
            return .{ entry, @intCast(offset) };
        }

        fn indexFromAddr(heap: *const Heap, gpu_addr: usize) usize {
            return std.sort.upperBound(
                Entry,
                heap.entries.items,
                gpu_addr,
                order,
            ) - 1;
        }

        fn insert(
            heap: *Heap,
            gpa: std.mem.Allocator,
            entry: Entry,
        ) !void {
            const insert_index = std.sort.upperBound(
                Entry,
                heap.entries.items,
                entry.gpu_addr,
                order,
            );
            try heap.entries.insert(gpa, insert_index, entry);
        }

        fn order(addr: usize, item: Entry) std.math.Order {
            return std.math.order(addr, item.gpu_addr);
        }
    };

    pub fn create(
        gpa: std.mem.Allocator,
        instance: Instance,
        adapter: Adapter,
    ) !Device {
        var arena_impl: std.heap.ArenaAllocator = .init(gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const device_handle = try createLogicalDevice(arena, adapter.physical_device, instance.instance.wrapper, instance.presentation_supported);
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

        var binding: vk.DescriptorSetLayoutBinding = .{
            .binding = 0,
            .descriptor_type = .mutable_ext,
            .descriptor_count = undefined,
            .stage_flags = .{ .compute_bit = true },
            .p_immutable_samplers = null,
        };
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
            .p_bindings = &.{binding},
        };
        var variable_support: vk.DescriptorSetVariableDescriptorCountLayoutSupport = .{ .max_variable_descriptor_count = 0 };
        var layout_support: vk.DescriptorSetLayoutSupport = .{ .p_next = &variable_support, .supported = .false };
        device.getDescriptorSetLayoutSupport(&layout_info, &layout_support);
        binding.descriptor_count = variable_support.max_variable_descriptor_count;
        const descriptor_set_layout = try device.createDescriptorSetLayout(&layout_info, null);

        const push_constant_ranges: []const vk.PushConstantRange = &.{.{
            .stage_flags = .{ .compute_bit = true },
            .offset = 0,
            .size = @sizeOf(vk.DeviceAddress),
        }};
        const create_info: vk.PipelineLayoutCreateInfo = .{
            .push_constant_range_count = push_constant_ranges.len,
            .p_push_constant_ranges = push_constant_ranges.ptr,
            .set_layout_count = 1,
            .p_set_layouts = &.{descriptor_set_layout},
        };
        const pipeline_layout = try device.createPipelineLayout(&create_info, null);

        const queue_families = try findQueueFamilies(arena, adapter.physical_device, instance.instance.wrapper);

        var command_pools: std.EnumArray(QueueType, vk.CommandPool) = .initUndefined();
        var it = command_pools.iterator();
        while (it.next()) |entry| {
            const info: vk.CommandPoolCreateInfo = .{
                .flags = .{ .transient_bit = true, .reset_command_buffer_bit = true },
                .queue_family_index = queue_families.queue_family_indices.get(entry.key),
            };
            entry.value.* = try device.createCommandPool(&info, null);
        }

        const memory_properties = instance.instance.getPhysicalDeviceMemoryProperties(adapter.physical_device);

        const memory_supports_host_visible = for (0..memory_properties.memory_type_count) |i| {
            const t = memory_properties.memory_types[i];
            if (t.property_flags.device_local_bit and t.property_flags.host_visible_bit) {
                const heap = memory_properties.memory_heaps[t.heap_index];
                if (heap.size > 256 * 1024 * 1024) break true;
            }
        } else false;

        return .{
            .instance = instance.instance,
            .device = device,
            .queue_family_indices = queue_families.queue_family_indices,
            .queue_indices = queue_families.queue_indices,
            .command_pools = command_pools,
            .debug_messenger = debug_messenger,
            .physical_device = adapter.physical_device,
            .gpa = gpa,
            .heap = .{ .entries = .empty },
            .descriptor_buffer_properties = null,
            .descriptor_set_layout = descriptor_set_layout,
            .pipeline_layout = pipeline_layout,
            .undefined_layout_textures = .empty,
            .memory_properties = memory_properties,
            .memory_supports_host_visible = memory_supports_host_visible,
        };
    }

    pub fn destroy(d: *Device) void {
        d.device.deviceWaitIdle() catch {};
        for (d.command_pools.values) |pool| d.device.destroyCommandPool(pool, null);
        d.device.destroyPipelineLayout(d.pipeline_layout, null);
        d.device.destroyDescriptorSetLayout(d.descriptor_set_layout, null);
        d.device.destroyDevice(null);
        d.gpa.destroy(d.device.wrapper);
        d.instance.destroyDebugUtilsMessengerEXT(d.debug_messenger, null);
        // TODO: make a debug gpa and uncomment next line
        // for (d.heap.entries.items) |entry| entry.destroy(d);
        d.heap.entries.deinit(d.gpa);
        d.undefined_layout_textures.deinit(d.gpa);
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

    // TODO: make gpu pointer a distinct u64-sized type
    pub fn rawAlloc(
        d: *Device,
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

        var unique_queue_families_buff: [d.queue_family_indices.values.len]u32 = undefined;
        var unique_queue_families_count: u32 = 0;
        for (d.queue_family_indices.values, 0..) |family, i| {
            for (d.queue_family_indices.values[0..i]) |previous_family| {
                if (family == previous_family) break;
            } else {
                unique_queue_families_buff[unique_queue_families_count] = family;
                unique_queue_families_count += 1;
            }
        }

        const concurrent = unique_queue_families_count > 1;
        const info: vk.BufferCreateInfo = .{
            .size = bytes,
            .usage = usage,
            .sharing_mode = if (concurrent) .concurrent else .exclusive,
            .queue_family_index_count = if (concurrent) unique_queue_families_count else 0,
            .p_queue_family_indices = if (concurrent) &unique_queue_families_buff else null,
        };
        const buffer = try d.device.createBuffer(&info, null);

        const buffer_memory_requirements = d.device.getBufferMemoryRequirements(buffer);

        // TODO: cache this
        const color_bits = probeImageMemoryTypeBits(d.*, .r8g8b8a8_unorm, .{ .sampled_bit = true, .transfer_dst_bit = true, .color_attachment_bit = true });
        const depth_bits = probeImageMemoryTypeBits(d.*, .d32_sfloat, .{ .depth_stencil_attachment_bit = true, .sampled_bit = true });

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
                .device_local_bit = d.memory_supports_host_visible,
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
        const index = findMemoryType(d.*, memory_requirements.memory_type_bits, properties);
        const alloc_info: vk.MemoryAllocateInfo = .{
            .p_next = &alloc_flags,
            .allocation_size = memory_requirements.size,
            .memory_type_index = index,
        };

        const buffer_memory = try d.device.allocateMemory(&alloc_info, null);
        try d.device.bindBufferMemory(buffer, buffer_memory, 0);

        const gpu_addr: usize = @intCast(d.device.getBufferDeviceAddress(&.{ .buffer = buffer }));
        const cpu_addr: ?usize = switch (memory) {
            .readback, .default => @intFromPtr(try d.device.mapMemory(buffer_memory, 0, vk.WHOLE_SIZE, .{})),
            .gpu => null,
        };

        try d.heap.insert(d.gpa, .{
            .buffer = buffer,
            .memory = buffer_memory,
            .size = bytes,
            .gpu_addr = gpu_addr,
            .cpu_addr = cpu_addr,
        });

        return @ptrFromInt(gpu_addr);
    }

    pub fn deviceToHostPointer(d: Device, ptr: *anyopaque) *anyopaque {
        const address = @intFromPtr(ptr);
        const entry = d.heap.entryFromAddr(address);
        const offset = address - entry.gpu_addr;
        return @ptrFromInt(entry.cpu_addr.? + offset);
    }

    pub fn rawFree(d: *Device, gpu_ptr: *anyopaque) void {
        const index = d.heap.indexFromAddr(@intFromPtr(gpu_ptr));
        const entry = d.heap.entries.orderedRemove(index);
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
        presentation_supported: bool,
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
        if (presentation_supported) required_device_extensions.appendAssumeCapacity(
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
    ) !struct {
        queue_family_indices: std.EnumArray(QueueType, u32),
        queue_indices: std.EnumArray(QueueType, u32),
    } {
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

        const next_index = try arena.alloc(u32, queue_family_indices.len);
        @memset(next_index, 0);

        const local = struct {
            fn claim(indices: []u32, families: []const vk.QueueFamilyProperties, family: u32) u32 {
                if (family == std.math.maxInt(u32)) return std.math.maxInt(u32);
                const max = families[family].queue_count;
                const index = @min(indices[family], max - 1);
                indices[family] += 1;
                return index;
            }
        };

        return .{
            .queue_family_indices = .init(.{
                .graphics = graphics,
                .compute = compute,
                .transfer = transfer,
            }),
            .queue_indices = .init(.{
                .graphics = local.claim(next_index, queue_family_indices, graphics),
                .compute = local.claim(next_index, queue_family_indices, compute),
                .transfer = local.claim(next_index, queue_family_indices, transfer),
            }),
        };
    }
};

pub const Memory = enum(u8) {
    default,
    gpu,
    readback,
};

pub const QueueType = enum {
    graphics,
    compute,
    transfer,
};

pub const Queue = struct {
    queue: vk.Queue,
    queue_type: QueueType,

    pub fn create(d: Device, queue_type: QueueType) Queue {
        const queue_family_index = d.queue_family_indices.get(queue_type);
        const queue_index = d.queue_indices.get(queue_type);
        const queue = d.device.getDeviceQueue(queue_family_index, queue_index);
        return .{ .queue = queue, .queue_type = queue_type };
    }

    pub fn submitSignal(
        queue: Queue,
        d: *Device,
        command_buffers: []const CommandBuffer,
        signal_semaphore: Semaphore,
        signal_value: u64,
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

        const signal_info: vk.SemaphoreSubmitInfo = .{
            .semaphore = signal_semaphore.semaphore,
            .value = signal_value,
            .stage_mask = .{ .all_commands_bit = true },
            .device_index = 0,
        };
        const submit_info: vk.SubmitInfo2 = .{
            .command_buffer_info_count = @intCast(submit_buffers.len),
            .p_command_buffer_infos = submit_buffers.ptr,
            .signal_semaphore_info_count = 1,
            .p_signal_semaphore_infos = (&signal_info)[0..1],
        };
        try d.device.queueSubmit2(
            queue.queue,
            &.{submit_info},
            .null_handle,
        );
    }
};

pub const SurfaceCapabilities = struct {
    usages: Texture.Usage,
    formats: []const Format,
    present_modes: []const PresentMode,
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
        _ = try d.device.waitSemaphores(&wait_info, std.math.maxInt(u64));
    }
};

pub const Texture = struct {
    image: vk.Image,
    config: Config,
    views: std.hash_map.AutoHashMapUnmanaged(ViewDesc, vk.ImageView),

    pub const Type = enum {
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

    // TODO: Config or Descriptor?
    pub const Config = struct {
        type: Type = .@"2d",
        dimensions: [3]u32,
        mip_count: u32 = 1,
        layer_count: u32 = 1,
        // sample_count: u32 = 1, TODO
        format: Format = .none,
        usage: Usage = .{},
    };

    pub const SizeAndAlign = struct {
        size: usize,
        alignement: std.mem.Alignment,
    };

    pub const Descriptor = struct {
        pub fn sizeAndHeapAlign(d: *Device) SizeAndAlign {
            const buffer_properties = d.descriptorBufferProperties();
            return .{
                .size = descriptorSize(buffer_properties.*),
                .alignement = .fromByteUnits(buffer_properties.descriptor_buffer_offset_alignment),
            };
        }

        pub fn store(descriptor: Descriptor, d: *Device, heap: *anyopaque, index: usize) void {
            const buffer_properties = d.descriptorBufferProperties();
            const size = descriptorSize(buffer_properties.*);
            @memcpy(
                @as([*]u8, @ptrCast(heap)) + size * index,
                descriptor.data[0..size],
            );
        }

        fn descriptorSize(buffer_properties: vk.PhysicalDeviceDescriptorBufferPropertiesEXT) usize {
            return @max(
                buffer_properties.sampled_image_descriptor_size,
                buffer_properties.storage_image_descriptor_size,
            );
        }

        data: [64]u8,
    };

    const ViewDesc = struct {
        const all_mips = std.math.maxInt(u8);
        const all_layers = std.math.maxInt(u16);

        format: Format = .none,
        base_mip: u8 = 0,
        mip_count: u8 = all_mips,
        base_layer: u16 = 0,
        layer_count: u16 = all_layers,
    };

    pub fn RwTextureViewDescriptor(texture: *Texture, d: *Device, view_desc: ViewDesc) !Descriptor {
        const view = texture.views.get(view_desc) orelse blk: {
            const mips_level = if (view_desc.mip_count == ViewDesc.all_mips) vk.REMAINING_MIP_LEVELS else view_desc.mip_count;
            const layer_count = if (view_desc.layer_count == ViewDesc.all_layers) vk.REMAINING_ARRAY_LAYERS else view_desc.layer_count;
            const format = if (view_desc.format == .none) texture.config.format else view_desc.format;
            const info: vk.ImageViewCreateInfo = .{
                .image = texture.image,
                .view_type = gpu_to_vk.viewType(texture.config.type),
                .format = gpu_to_vk.format(format),
                .subresource_range = .{
                    .aspect_mask = gpu_to_vk.aspectsForFormat(texture.config.format),
                    .base_mip_level = view_desc.base_mip,
                    .level_count = mips_level,
                    .base_array_layer = view_desc.base_layer,
                    .layer_count = layer_count,
                },
                .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            };
            const view = try d.device.createImageView(&info, null);
            try texture.views.put(d.gpa, view_desc, view);
            break :blk view;
        };
        const image_info: vk.DescriptorImageInfo = .{
            .image_view = view,
            .image_layout = .general,
            .sampler = .null_handle,
        };
        const get_info: vk.DescriptorGetInfoEXT = .{
            .type = .storage_image,
            .data = .{ .p_sampled_image = &image_info },
        };
        const buffer_properties = d.descriptorBufferProperties();
        var descriptor: Descriptor = .{ .data = @splat(0) };
        d.device.getDescriptorEXT(&get_info, buffer_properties.storage_image_descriptor_size, @ptrCast(&descriptor.data));
        return descriptor;
    }

    pub fn sizeAndAlign(d: Device, config: Config) SizeAndAlign {
        const info: vk.DeviceImageMemoryRequirements = .{
            .p_create_info = &textureInfo(config),
            .plane_aspect = gpu_to_vk.aspectsForFormat(config.format),
        };
        var req: vk.MemoryRequirements2 = .{ .memory_requirements = undefined };
        d.device.getDeviceImageMemoryRequirements(&info, &req);
        return .{
            .size = req.memory_requirements.size,
            .alignement = .fromByteUnits(req.memory_requirements.alignment),
        };
    }

    pub fn create(d: *Device, config: Config, texture_ptr: *anyopaque) !Texture {
        const image = try d.device.createImage(&textureInfo(config), null);

        const entry, const offset = d.heap.entryAndOffsetFromAddr(@intFromPtr(texture_ptr));
        try d.device.bindImageMemory(image, entry.memory, offset);

        try d.undefined_layout_textures.put(d.gpa, image, config);
        return .{
            .image = image,
            .config = config,
            .views = .empty,
        };
    }

    pub fn destroy(texture: *Texture, d: *Device) void {
        _ = d.undefined_layout_textures.swapRemove(texture.image);
        d.device.destroyImage(texture.image, null);
        var it = texture.views.valueIterator();
        while (it.next()) |view| d.device.destroyImageView(view.*, null);
        texture.views.deinit(d.gpa);
    }

    fn textureInfo(config: Config) vk.ImageCreateInfo {
        return .{
            .image_type = gpu_to_vk.textureType(config.type),
            .format = gpu_to_vk.format(config.format),
            .extent = .{ .width = config.dimensions[0], .height = config.dimensions[1], .depth = config.dimensions[2] },
            .mip_levels = config.mip_count,
            .array_layers = config.layer_count,
            .samples = .{ .@"1_bit" = true },
            .tiling = .optimal,
            .usage = gpu_to_vk.usageFlags(config.usage),
            .sharing_mode = .exclusive,
            .initial_layout = .undefined,
        };
    }
};

pub const Pipeline = struct {
    pipeline: vk.Pipeline,
    bind_point: vk.PipelineBindPoint,

    pub fn createCompute(d: Device, source: []const u32) !Pipeline {
        const module_info: vk.ShaderModuleCreateInfo = .{
            .code_size = source.len * @sizeOf(u32),
            .p_code = source.ptr,
        };
        const module = try d.device.createShaderModule(&module_info, null);
        defer d.device.destroyShaderModule(module, null);

        const info: vk.ComputePipelineCreateInfo = .{
            .flags = .{ .descriptor_buffer_bit_ext = true },
            .stage = .{
                .stage = .{ .compute_bit = true },
                .module = module,
                .p_name = "main",
            },
            .layout = d.pipeline_layout,
            .base_pipeline_index = -1,
        };
        var pipeline: vk.Pipeline = undefined;
        _ = try d.device.createComputePipelines(.null_handle, &.{info}, null, (&pipeline)[0..1]);

        return .{ .pipeline = pipeline, .bind_point = .compute };
    }

    pub fn destroy(pipeline: Pipeline, d: Device) void {
        d.device.destroyPipeline(pipeline.pipeline, null);
    }
};

pub const CommandBuffer = struct {
    command_buffer: vk.CommandBuffer,

    pub fn startRecording(queue: Queue, d: *Device) !CommandBuffer {
        const alloc_info: vk.CommandBufferAllocateInfo = .{
            .command_pool = d.command_pools.get(queue.queue_type),
            .level = .primary,
            .command_buffer_count = 1,
        };
        var command_buffer: vk.CommandBuffer = undefined;
        try d.device.allocateCommandBuffers(&alloc_info, (&command_buffer)[0..1]);

        const begin_info: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit_bit = true } };
        try d.device.beginCommandBuffer(command_buffer, &begin_info);

        var image_it = d.undefined_layout_textures.iterator();
        const image_count = d.undefined_layout_textures.count();
        if (image_count != 0) {
            const barriers = try d.gpa.alloc(vk.ImageMemoryBarrier2, image_count);
            defer d.gpa.free(barriers);

            for (barriers) |*b| {
                const item = image_it.next() orelse break;
                const image = item.key_ptr.*;
                const config = item.value_ptr.*;
                b.* = .{
                    .src_stage_mask = .{},
                    .src_access_mask = .{},
                    .dst_stage_mask = .{ .all_commands_bit = true },
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
                        .aspect_mask = gpu_to_vk.aspectsForFormat(config.format),
                        .base_mip_level = 0,
                        .level_count = config.mip_count,
                        .base_array_layer = 0,
                        .layer_count = config.layer_count,
                    },
                };
            }

            const dependency_info: vk.DependencyInfo = .{
                .image_memory_barrier_count = @intCast(barriers.len),
                .p_image_memory_barriers = barriers.ptr,
            };
            d.device.cmdPipelineBarrier2(
                command_buffer,
                &dependency_info,
            );
            d.undefined_layout_textures.clearRetainingCapacity();
        }

        return .{ .command_buffer = command_buffer };
    }

    pub fn setActiveTextureHeapPtr(command_buffer: CommandBuffer, d: Device, heap_address: *anyopaque) void {
        const binding_info: vk.DescriptorBufferBindingInfoEXT = .{
            .address = @intFromPtr(heap_address),
            .usage = .{ .resource_descriptor_buffer_bit_ext = true },
        };
        d.device.cmdBindDescriptorBuffersEXT(
            command_buffer.command_buffer,
            &.{binding_info},
        );

        const indices = [_]u32{0};
        const offsets = [_]vk.DeviceSize{0};
        d.device.cmdSetDescriptorBufferOffsetsEXT(
            command_buffer.command_buffer,
            .compute,
            d.pipeline_layout,
            0,
            &indices,
            &offsets,
        );
        d.device.cmdSetDescriptorBufferOffsetsEXT(
            command_buffer.command_buffer,
            .graphics,
            d.pipeline_layout,
            0,
            &indices,
            &offsets,
        );
    }

    pub fn setPipeline(command_buffer: CommandBuffer, d: Device, pipeline: Pipeline) void {
        d.device.cmdBindPipeline(
            command_buffer.command_buffer,
            pipeline.bind_point,
            pipeline.pipeline,
        );
    }

    pub fn dispatch(
        command_buffer: CommandBuffer,
        d: Device,
        data_gpu: *anyopaque,
        grid_dimensions: [3]u32,
    ) void {
        const address: vk.DeviceAddress = @intFromPtr(data_gpu);
        d.device.cmdPushConstants(
            command_buffer.command_buffer,
            d.pipeline_layout,
            .{ .compute_bit = true },
            0,
            @sizeOf(vk.DeviceAddress),
            std.mem.asBytes(&address),
        );

        d.device.cmdDispatch(
            command_buffer.command_buffer,
            grid_dimensions[0],
            grid_dimensions[1],
            grid_dimensions[2],
        );
    }

    pub const Stage = packed struct {
        transfer: bool = false,
        compute: bool = false,
        raster_color_out: bool = false,
        raster_depth_out: bool = false,
        pixel_shader: bool = false,
        vertex_shader: bool = false,
    };

    pub const Hazard = packed struct {
        draw_arguments: bool = false,
        descriptors: bool = false,
        depth_stencil: bool = false,
    };

    pub fn barrier(
        command_buffer: CommandBuffer,
        d: Device,
        before: Stage,
        after: Stage,
        hazards: Hazard,
    ) void {
        const src_stage = gpu_to_vk.pipelineStage(before);
        var dst_stage = gpu_to_vk.pipelineStage(after);
        if (hazards.draw_arguments) {
            dst_stage.draw_indirect_bit = true;
        }
        if (hazards.depth_stencil) {
            dst_stage.early_fragment_tests_bit = true;
            dst_stage.late_fragment_tests_bit = true;
        }
        const memory_barrier: vk.MemoryBarrier2 = .{
            .src_stage_mask = src_stage,
            .src_access_mask = .{ .memory_write_bit = true },
            .dst_stage_mask = dst_stage,
            .dst_access_mask = .{
                .memory_read_bit = true,
                .memory_write_bit = true,
            },
        };
        const dependency_info: vk.DependencyInfo = .{
            .memory_barrier_count = 1,
            .p_memory_barriers = (&memory_barrier)[0..1],
        };
        d.device.cmdPipelineBarrier2(command_buffer.command_buffer, &dependency_info);
    }

    /// dest_gpu minimal alignement: 16 bytes
    /// 256 bytes is a typical optimal alignement
    pub fn copyFromTexture(
        command_buffer: CommandBuffer,
        d: *Device,
        dest_gpu: *anyopaque,
        src_gpu: *anyopaque,
        texture: Texture,
    ) void {
        _ = src_gpu;
        const entry, const offset = d.heap.entryAndOffsetFromAddr(@intFromPtr(dest_gpu));
        const region: vk.BufferImageCopy2 = .{
            .buffer_offset = offset,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = texture.config.layer_count,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{
                .width = texture.config.dimensions[0],
                .height = texture.config.dimensions[1],
                .depth = texture.config.dimensions[2],
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
};

const std = @import("std");
pub const vk = @import("vulkan");
const vk_to_gpu = @import("bridge.zig").vk_to_gpu;
const gpu_to_vk = @import("bridge.zig").gpu_to_vk;
