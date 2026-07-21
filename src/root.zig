const std = @import("std");
pub const vk = @import("vulkan");
const vk_to_gpu = @import("bridge.zig").vk_to_gpu;
const gpu_to_vk = @import("bridge.zig").gpu_to_vk;

pub const Allocator = @import("DeviceAllocator.zig");

pub const SizeAndAlignment = struct {
    size: usize,
    alignment: std.mem.Alignment,
};

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

pub const PointerAttributes = struct {
    @"const": bool = false,
    @"volatile": bool = false,
    @"align": ?std.mem.Alignment = null,
    optional: bool = false,
};

pub const PointerInfo = struct {
    pub const Size = enum {
        one,
        many,
    };
    size: Size,
    Element: type,
    attributes: PointerAttributes,
};

pub fn Ptr(
    size: PointerInfo.Size,
    Element: type,
    attributes: PointerAttributes,
) type {
    return extern struct {
        addr: u64,

        pub const Host = blk: {
            const H = @Pointer(switch (size) {
                .one => .one,
                .many => .many,
            }, .{
                .@"const" = attributes.@"const",
                .@"volatile" = attributes.@"volatile",
                .@"align" = if (attributes.@"align") |a| a.toByteUnits() else null,
            }, Element, null);
            break :blk if (attributes.optional) ?H else H;
        };

        pub const info: PointerInfo = .{
            .size = size,
            .Element = Element,
            .attributes = attributes,
        };

        pub const @"null": @This() =
            if (attributes.optional) .{ .addr = 0 } else @compileError("pointer is not optional");

        pub const alignement: ?std.mem.Alignment = if (attributes.@"align") |a| a else switch (Element) {
            anyopaque => null,
            else => .of(Element),
        };

        const unwrapped_attributes: PointerAttributes = blk: {
            var a = attributes;
            a.optional = false;
            break :blk a;
        };

        pub fn fromInt(addr: u64) @This() {
            const result: @This() = .{ .addr = addr };
            result.assertAlignment();
            result.assertZero();
            return result;
        }

        pub fn from(ptr: anytype) @This() {
            const Src = @TypeOf(ptr);
            comptime {
                if (!isDevicePtr(Src))
                    @compileError("expected a device pointer, found '" ++ @typeName(Src) ++ "'");
                _ = @as(Host, @as(Src.Host, undefined));
            }
            return .{ .addr = ptr.addr };
        }

        pub fn cast(ptr: anytype) @This() {
            comptime blk: {
                if (!isDevicePtr(@TypeOf(ptr)))
                    @compileError("expected a device pointer, found '" ++ @typeName(@TypeOf(ptr)) ++ "'");
                const ptr_align = @TypeOf(ptr).alignement orelse break :blk;
                const this_align = alignement orelse break :blk;
                if (this_align.compare(.gt, ptr_align))
                    @compileError("cast increases pointer alignment; use alignCast");
            }
            return .{ .addr = ptr.addr };
        }

        pub fn alignCast(ptr: anytype) @This() {
            const Src = @TypeOf(ptr);
            comptime {
                if (!isDevicePtr(Src))
                    @compileError("expected a device pointer, found '" ++ @typeName(Src) ++ "'");
                var a = Src.info.attributes;
                a.@"align" = attributes.@"align";
                _ = @as(Host, @as(Ptr(Src.info.size, Src.info.Element, a).Host, undefined));
            }
            return .fromInt(ptr.addr);
        }

        pub fn isNull(ptr: @This()) bool {
            comptime std.debug.assert(attributes.optional);
            return ptr.addr == 0;
        }

        pub fn unwrap(ptr: @This()) ?Ptr(size, Element, unwrapped_attributes) {
            if (ptr.addr == 0) return null;
            return .fromInt(ptr.addr);
        }

        pub fn slice(ptr: @This(), len: u64) Slice(Element, unwrapped_attributes) {
            comptime std.debug.assert(size == .many);
            ptr.assertZero();
            return .{ .ptr = .fromInt(ptr.addr), .len = len };
        }

        fn assertAlignment(ptr: @This()) void {
            if (alignement != null) std.debug.assert(std.mem.isAligned(ptr.addr, alignement.?.toByteUnits()));
        }

        fn assertZero(ptr: @This()) void {
            if (!attributes.optional) std.debug.assert(ptr.addr != 0);
        }
    };
}

pub const SliceInfo = struct {
    Element: type,
    attributes: PointerAttributes,
};

pub fn Slice(
    Element: type,
    attributes: PointerAttributes,
) type {
    return extern struct {
        ptr: Pointer,
        len: u64,

        const Pointer = Ptr(.many, Element, attributes);

        pub const info: SliceInfo = .{
            .Element = Element,
            .attributes = attributes,
        };

        pub const Host = blk: {
            const H = @Pointer(.slice, .{
                .@"const" = attributes.@"const",
                .@"volatile" = attributes.@"volatile",
                .@"align" = if (attributes.@"align") |a| a.toByteUnits() else null,
            }, Element, null);
            break :blk if (attributes.optional) ?H else H;
        };

        const dangling_ptr: Pointer = .fromInt(
            (Pointer.alignement orelse .@"1").backward(std.math.maxInt(u64)),
        );

        pub const empty: @This() = .{ .ptr = dangling_ptr, .len = 0 };

        pub fn from(src: anytype) @This() {
            const Src = @TypeOf(src);
            comptime {
                if (!isDeviceSlice(Src) and !isDevicePtr(Src))
                    @compileError("expected a device pointer or slice, found '" ++ @typeName(Src) ++ "'");
                _ = @as(Host, @as(Src.Host, undefined));
            }
            if (comptime isDeviceSlice(Src)) {
                return .{ .ptr = .{ .addr = src.ptr.addr }, .len = src.len };
            } else {
                return .{
                    .ptr = .{ .addr = src.addr },
                    .len = @typeInfo(Src.info.Element).array.len,
                };
            }
        }

        pub fn cast(src: anytype) @This() {
            const Src = @TypeOf(src);
            comptime if (!isDeviceSlice(Src))
                @compileError("expected a device slice, found '" ++ @typeName(Src) ++ "'");
            const byte_len = src.len * @sizeOf(Src.info.Element);
            std.debug.assert(byte_len % @sizeOf(Element) == 0);
            return .{
                .ptr = .cast(src.ptr),
                .len = byte_len / @sizeOf(Element),
            };
        }

        pub fn alignCast(src: anytype) @This() {
            const Src = @TypeOf(src);
            comptime {
                if (!isDeviceSlice(Src))
                    @compileError("expected a device slice, found '" ++ @typeName(Src) ++ "'");
                var a = Src.info.attributes;
                a.@"align" = attributes.@"align";
                _ = @as(Host, @as(Slice(Src.info.Element, a).Host, undefined));
            }
            return .{ .ptr = .fromInt(src.ptr.addr), .len = src.len };
        }

        pub fn asBytes(self: @This()) Slice(u8, blk: {
            var a = attributes;
            a.@"align" = @TypeOf(self.ptr).alignement;
            break :blk a;
        }) {
            return .{
                .ptr = .{ .addr = self.ptr.addr },
                .len = self.len * @sizeOf(Element),
            };
        }
    };
}

fn isDevicePtr(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!@hasDecl(T, "info")) return false;
    return @TypeOf(T.info) == PointerInfo;
}

fn isDeviceSlice(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!@hasDecl(T, "info")) return false;
    return @TypeOf(T.info) == SliceInfo;
}

pub const Instance = struct {
    instance: vk.InstanceProxy,
    presentation_enabled: bool,
    debug_messenger: vk.DebugUtilsMessengerEXT,

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

        const debug_messenger_info: vk.DebugUtilsMessengerCreateInfoEXT = .{
            .message_severity = .{ .verbose_bit_ext = true, .warning_bit_ext = true, .error_bit_ext = true },
            .message_type = .{ .general_bit_ext = true, .validation_bit_ext = true, .performance_bit_ext = true },
            .pfn_user_callback = debugCallback,
        };
        const debug_messenger = try instance.createDebugUtilsMessengerEXT(&debug_messenger_info, null);

        return .{
            .instance = instance,
            .presentation_enabled = required_surface_extensions.len != 0,
            .debug_messenger = debug_messenger,
        };
    }

    pub fn destroy(instance: *Instance, gpa: std.mem.Allocator) void {
        instance.instance.destroyDebugUtilsMessengerEXT(instance.debug_messenger, null);
        instance.instance.destroyInstance(null);
        gpa.destroy(instance.instance.wrapper);
        instance.* = undefined;
    }

    pub fn enumerateAdaptersAlloc(instance: Instance, gpa: std.mem.Allocator) ![]Adapter {
        const physical_devices = try instance.instance.enumeratePhysicalDevicesAlloc(gpa);
        defer gpa.free(physical_devices);
        const adapters = try gpa.alloc(Adapter, physical_devices.len);
        for (adapters, physical_devices) |*adapter, physical_device| adapter.* = .{ .physical_device = physical_device };
        return adapters;
    }
};

pub const Adapter = struct {
    physical_device: vk.PhysicalDevice,
};

pub const SurfaceCapabilities = struct {
    usage: Texture.Usage,
    formats: []const Format,
    present_modes: []const PresentMode,
};

pub const Device = struct {
    instance: vk.InstanceProxy,
    device: vk.DeviceProxy,
    physical_device: vk.PhysicalDevice,

    queue_family_indices: std.EnumArray(Queue.Type, u32),
    queue_indices: std.EnumArray(Queue.Type, u32),
    command_pools: std.EnumArray(Queue.Type, vk.CommandPool),

    gpa: std.mem.Allocator,

    heap: AdressMap,

    descriptor_buffer_properties: ?vk.PhysicalDeviceDescriptorBufferPropertiesEXT,

    descriptor_set_layout: vk.DescriptorSetLayout,
    pipeline_layout: vk.PipelineLayout,

    pending_general_layout_transitions: std.array_hash_map.Auto(vk.Image, Texture.Info),

    free_command_buffers: std.EnumArray(Queue.Type, std.ArrayList(vk.CommandBuffer)),
    in_flight_command_buffers: std.ArrayList(InFlightCommandBuffer),

    memory_properties: vk.PhysicalDeviceMemoryProperties,
    has_host_visible_device_local: bool,

    const InFlightCommandBuffer = struct {
        semaphore: vk.Semaphore,
        semaphore_value: u64,
        command_buffer: CommandBuffer,
    };

    const AdressMap = struct {
        entries: std.ArrayList(Entry),

        const Entry = struct {
            buffer: vk.Buffer,
            memory: vk.DeviceMemory,
            size: usize,
            device_addr: u64,
            host_addr: ?usize,

            fn destroy(entry: *Entry, d: Device) void {
                d.device.destroyBuffer(entry.buffer, null);
                d.device.freeMemory(entry.memory, null);
                entry.* = undefined;
            }
        };

        fn addrToEntryAndOffset(map: *const AdressMap, device_addr: u64) struct { Entry, vk.DeviceSize } {
            const entry = map.addrToEntry(device_addr);
            const offset = device_addr - entry.device_addr;
            return .{ entry, @intCast(offset) };
        }

        fn addrToEntry(map: *const AdressMap, device_addr: u64) Entry {
            return map.entries.items[map.indexFromAddr(device_addr)];
        }

        fn indexFromAddr(map: *const AdressMap, device_addr: u64) usize {
            return std.sort.upperBound(
                Entry,
                map.entries.items,
                device_addr,
                order,
            ) - 1;
        }

        fn insert(
            map: *AdressMap,
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

    pub fn create(
        gpa: std.mem.Allocator,
        instance: Instance,
        adapter: Adapter,
    ) !Device {
        var arena_impl: std.heap.ArenaAllocator = .init(gpa);
        defer arena_impl.deinit();
        const arena = arena_impl.allocator();

        const device_handle = try createLogicalDevice(arena, adapter.physical_device, instance.instance.wrapper, instance.presentation_enabled);
        const device_dispatch = try gpa.create(vk.DeviceWrapper);
        device_dispatch.* = .load(device_handle, instance.instance.wrapper.dispatch.vkGetDeviceProcAddr.?);
        const device: vk.DeviceProxy = .init(device_handle, device_dispatch);

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

        var command_pools: std.EnumArray(Queue.Type, vk.CommandPool) = .initUndefined();
        var it = command_pools.iterator();
        while (it.next()) |entry| {
            const info: vk.CommandPoolCreateInfo = .{
                .flags = .{ .transient_bit = true, .reset_command_buffer_bit = true },
                .queue_family_index = queue_families.queue_family_indices.get(entry.key),
            };
            entry.value.* = try device.createCommandPool(&info, null);
        }

        const memory_properties = instance.instance.getPhysicalDeviceMemoryProperties(adapter.physical_device);

        const has_host_visible_device_local = for (0..memory_properties.memory_type_count) |i| {
            const t = memory_properties.memory_types[i];
            if (t.property_flags.device_local_bit and t.property_flags.host_visible_bit) {
                const memory_heap = memory_properties.memory_heaps[t.heap_index];
                if (memory_heap.size > 256 * 1024 * 1024) break true;
            }
        } else false;

        return .{
            .instance = instance.instance,
            .device = device,
            .queue_family_indices = queue_families.queue_family_indices,
            .queue_indices = queue_families.queue_indices,
            .command_pools = command_pools,
            .physical_device = adapter.physical_device,
            .gpa = gpa,
            .heap = .{ .entries = .empty },
            .descriptor_buffer_properties = null,
            .descriptor_set_layout = descriptor_set_layout,
            .pipeline_layout = pipeline_layout,
            .pending_general_layout_transitions = .empty,
            .free_command_buffers = .initFill(.empty),
            .in_flight_command_buffers = .empty,
            .memory_properties = memory_properties,
            .has_host_visible_device_local = has_host_visible_device_local,
        };
    }

    pub fn destroy(d: *Device) void {
        d.device.deviceWaitIdle() catch {};
        for (d.command_pools.values) |pool| d.device.destroyCommandPool(pool, null);
        d.device.destroyPipelineLayout(d.pipeline_layout, null);
        d.device.destroyDescriptorSetLayout(d.descriptor_set_layout, null);
        d.device.destroyDevice(null);
        d.gpa.destroy(d.device.wrapper);
        // TODO: make a debug gpa and uncomment next line
        // for (d.heap.entries.items) |entry| entry.destroy(d);
        d.heap.entries.deinit(d.gpa);
        d.pending_general_layout_transitions.deinit(d.gpa);
        for (&d.free_command_buffers.values) |*list| list.deinit(d.gpa);
        d.in_flight_command_buffers.deinit(d.gpa);
        d.* = undefined;
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
            .usage = vk_to_gpu.usageFlags(vk_capabilities.supported_usage_flags),
            .formats = try gpa.dupe(Format, formats.items),
            .present_modes = try gpa.dupe(PresentMode, modes.items),
        };
    }

    pub fn deviceToHostPointer(d: Device, ptr: anytype) @TypeOf(ptr).Host {
        const Src = @TypeOf(ptr);

        if (comptime isDeviceSlice(Src)) {
            const Many = Ptr(.many, Src.info.Element, Src.info.attributes);
            if (comptime Src.info.attributes.optional) {
                const many = d.deviceToHostPointer(@as(Many, .{ .addr = ptr.ptr.addr })) orelse return null;
                return many[0..@intCast(ptr.len)];
            }
            if (ptr.len == 0) return &.{};
            return d.deviceToHostPointer(ptr.ptr)[0..@intCast(ptr.len)];
        }

        comptime std.debug.assert(isDevicePtr(Src));

        if (comptime Src.info.attributes.optional) {
            if (ptr.addr == 0) return null;
        }

        const entry = d.heap.addrToEntry(ptr.addr);
        const offset = ptr.addr - entry.device_addr;
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
    ) !struct {
        queue_family_indices: std.EnumArray(Queue.Type, u32),
        queue_indices: std.EnumArray(Queue.Type, u32),
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

    fn acquireCommandBuffer(d: *Device, queue_type: Queue.Type) !CommandBuffer {
        if (d.free_command_buffers.getPtr(queue_type).pop()) |command_buffer|
            return .{ .command_buffer = command_buffer, .queue_type = queue_type };

        const alloc_info: vk.CommandBufferAllocateInfo = .{
            .command_pool = d.command_pools.get(queue_type),
            .level = .primary,
            .command_buffer_count = 1,
        };
        var command_buffer: vk.CommandBuffer = undefined;
        try d.device.allocateCommandBuffers(&alloc_info, (&command_buffer)[0..1]);
        return .{ .command_buffer = command_buffer, .queue_type = queue_type };
    }

    fn releaseCommandBuffer(d: *Device, command_buffer: CommandBuffer) void {
        d.free_command_buffers.getPtr(command_buffer.queue_type).append(d.gpa, command_buffer.command_buffer) catch {
            d.device.freeCommandBuffers(d.command_pools.get(command_buffer.queue_type), &.{command_buffer.command_buffer});
        };
    }

    fn reclaimCompletedCommandBuffers(d: *Device) void {
        var i: usize = 0;
        while (i < d.in_flight_command_buffers.items.len) {
            const entry = d.in_flight_command_buffers.items[i];
            const completed = d.device.getSemaphoreCounterValue(entry.semaphore) catch {
                i += 1;
                continue;
            };
            if (completed < entry.semaphore_value) {
                i += 1;
                continue;
            }
            _ = d.in_flight_command_buffers.swapRemove(i);
            d.releaseCommandBuffer(entry.command_buffer);
        }
    }
};

pub const Queue = struct {
    queue: vk.Queue,
    queue_type: Type,

    pub const Type = enum {
        graphics,
        compute,
        transfer,
    };

    pub fn create(d: Device, queue_type: Type) Queue {
        const queue_family_index = d.queue_family_indices.get(queue_type);
        const queue_index = d.queue_indices.get(queue_type);
        const queue = d.device.getDeviceQueue(queue_family_index, queue_index);
        return .{ .queue = queue, .queue_type = queue_type };
    }

    pub fn startRecording(queue: Queue, d: *Device) !CommandBuffer {
        d.reclaimCompletedCommandBuffers();
        const command_buffer = try d.acquireCommandBuffer(queue.queue_type);
        errdefer d.releaseCommandBuffer(command_buffer);

        const begin_info: vk.CommandBufferBeginInfo = .{ .flags = .{ .one_time_submit_bit = true } };
        try d.device.beginCommandBuffer(command_buffer.command_buffer, &begin_info);

        var image_it = d.pending_general_layout_transitions.iterator();
        const image_count = d.pending_general_layout_transitions.count();
        if (image_count != 0) {
            const barriers = try d.gpa.alloc(vk.ImageMemoryBarrier2, image_count);
            defer d.gpa.free(barriers);

            for (barriers) |*b| {
                const item = image_it.next() orelse break;
                const image = item.key_ptr.*;
                const info = item.value_ptr.*;
                b.* = .{
                    .dst_stage_mask = .{ .all_commands_bit = true },
                    .dst_access_mask = .{ .memory_read_bit = true, .memory_write_bit = true },
                    .old_layout = .undefined,
                    .new_layout = .general,
                    .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .image = image,
                    .subresource_range = .{
                        .aspect_mask = gpu_to_vk.aspectsForFormat(info.format),
                        .base_mip_level = 0,
                        .level_count = info.mip_count,
                        .base_array_layer = 0,
                        .layer_count = info.layer_count,
                    },
                };
            }

            const dependency_info: vk.DependencyInfo = .{
                .image_memory_barrier_count = @intCast(barriers.len),
                .p_image_memory_barriers = barriers.ptr,
            };
            d.device.cmdPipelineBarrier2(
                command_buffer.command_buffer,
                &dependency_info,
            );
            d.pending_general_layout_transitions.clearRetainingCapacity();
        }

        return command_buffer;
    }

    pub fn submitAndSignal(
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

        try d.in_flight_command_buffers.ensureUnusedCapacity(d.gpa, command_buffers.len);

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

        for (command_buffers) |command_buffer| d.in_flight_command_buffers.appendAssumeCapacity(.{
            .semaphore = signal_semaphore.semaphore,
            .semaphore_value = signal_value,
            .command_buffer = command_buffer,
        });
    }
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

    pub fn destroy(semaphore: *Semaphore, d: Device) void {
        d.device.destroySemaphore(semaphore.semaphore, null);
        semaphore.* = undefined;
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

pub const Swapchain = struct {
    swapchain: vk.SwapchainKHR,
    queue: Queue,

    textures: []SwapchainTexture,
    acquire_fence: vk.Fence,
    current: u32,

    const SwapchainTexture = struct {
        texture: Texture,
        /// general -> present_src
        present_command_buffer: CommandBuffer,
        /// binary
        present_semaphore: vk.Semaphore,
    };

    pub const Options = struct {
        format: Format,
        present_mode: PresentMode,
        usage: Texture.Usage,
        // TODO: reconsider including dimensions
        dimensions: [2]u32 = .{ 1, 1 },
    };

    pub fn create(
        d: *Device,
        queue: Queue,
        surface: vk.SurfaceKHR,
        options: Options,
    ) !Swapchain {
        const queue_family = d.queue_family_indices.get(queue.queue_type);

        // TODO: move to adapter picking
        std.debug.assert(try d.instance.getPhysicalDeviceSurfaceSupportKHR(d.physical_device, queue_family, surface) == .true);

        const capabilities = try d.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(d.physical_device, surface);

        const min_image_extent = capabilities.min_image_extent;
        const max_image_extent = capabilities.max_image_extent;
        const extent: vk.Extent2D = switch (capabilities.current_extent.width != std.math.maxInt(u32)) {
            true => capabilities.current_extent,
            false => .{
                .width = std.math.clamp(options.dimensions[0], min_image_extent.width, max_image_extent.width),
                .height = std.math.clamp(options.dimensions[1], min_image_extent.height, max_image_extent.height),
            },
        };

        var min_image_count = capabilities.min_image_count + 1;
        if (capabilities.max_image_count != 0) min_image_count = @min(min_image_count, capabilities.max_image_count);

        const create_info: vk.SwapchainCreateInfoKHR = .{
            .surface = surface,
            .min_image_count = min_image_count,
            .image_format = gpu_to_vk.format(options.format),
            .image_color_space = .srgb_nonlinear_khr,
            .image_extent = extent,
            .image_array_layers = 1,
            .image_usage = gpu_to_vk.usageFlags(options.usage),
            .image_sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = null,
            .pre_transform = capabilities.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = switch (options.present_mode) {
                .immediate => .immediate_khr,
                .mailbox => .mailbox_khr,
                .fifo => .fifo_khr,
                .fifo_relaxed => .fifo_relaxed_khr,
            },
            .clipped = .true,
            .old_swapchain = .null_handle,
        };
        const swapchain = try d.device.createSwapchainKHR(&create_info, null);
        errdefer d.device.destroySwapchainKHR(swapchain, null);

        const images = try d.device.getSwapchainImagesAllocKHR(swapchain, d.gpa);
        defer d.gpa.free(images);

        const textures = try d.gpa.alloc(SwapchainTexture, images.len);
        errdefer d.gpa.free(textures);
        for (textures, images) |*texture, image| {
            const texture_info: Texture.Info = .{
                .type = .@"2d",
                .dimensions = .{ extent.width, extent.height, 1 },
                .mip_count = 1,
                .layer_count = 1,
                .format = options.format,
                .usage = options.usage,
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
                    .aspect_mask = gpu_to_vk.aspectsForFormat(texture_info.format),
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

            texture.* = .{
                .texture = .{
                    .image = image,
                    .info = texture_info,
                    .views = .empty,
                },
                .present_semaphore = try d.device.createSemaphore(&.{}, null),
                .present_command_buffer = present_command_buffer,
            };
        }

        return .{
            .swapchain = swapchain,
            .queue = queue,
            .textures = textures,
            .acquire_fence = try d.device.createFence(&.{}, null),
            .current = undefined,
        };
    }

    pub fn destroy(swapchain: *Swapchain, d: *Device) void {
        _ = d.device.queueWaitIdle(swapchain.queue.queue) catch {};

        d.device.destroySwapchainKHR(swapchain.swapchain, null);
        for (swapchain.textures) |*texture| {
            texture.texture.destroyInner(d, false);
            d.releaseCommandBuffer(texture.present_command_buffer);
            d.device.destroySemaphore(texture.present_semaphore, null);
        }
        d.gpa.free(swapchain.textures);
        d.device.destroyFence(swapchain.acquire_fence, null);
        swapchain.* = undefined;
    }

    pub fn acquireNextTexture(swapchain: *Swapchain, d: *Device) !*Texture {
        const result = d.device.acquireNextImageKHR(
            swapchain.swapchain,
            std.math.maxInt(u64),
            .null_handle,
            swapchain.acquire_fence,
        ) catch |err| switch (err) {
            error.OutOfDateKHR => @panic("TODO"), // TODO
            else => |e| return e,
        };
        const index = result.image_index;
        _ = result.result; // TODO: handle suboptimal_khr: flag for recreate after present

        _ = try d.device.waitForFences(&.{swapchain.acquire_fence}, .true, std.math.maxInt(u64));
        try d.device.resetFences(&.{swapchain.acquire_fence});

        swapchain.current = index;
        const texture = &swapchain.textures[index].texture;

        try d.pending_general_layout_transitions.put(d.gpa, texture.image, texture.info);

        return texture;
    }

    pub fn present(
        swapchain: *Swapchain,
        d: *Device,
        queue: Queue,
        semaphore: Semaphore,
        semaphore_value: u64,
    ) !void {
        const texture = &swapchain.textures[swapchain.current];

        try d.device.queueSubmit2(
            queue.queue,
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

        _ = d.device.queuePresentKHR(queue.queue, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = &.{texture.present_semaphore},
            .swapchain_count = 1,
            .p_swapchains = &.{swapchain.swapchain},
            .p_image_indices = &.{swapchain.current},
        }) catch |err| switch (err) {
            error.OutOfDateKHR => @panic("TODO"), // TODO
            else => return err,
        };
    }
};

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

pub const CommandBuffer = struct {
    command_buffer: vk.CommandBuffer,
    queue_type: Queue.Type,

    pub fn setActiveTextureHeapPtr(command_buffer: CommandBuffer, d: Device, heap_ptr: Slice(u8, .{})) void {
        const binding_info: vk.DescriptorBufferBindingInfoEXT = .{
            .address = heap_ptr.ptr.addr,
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
        data: Ptr(.one, anyopaque, .{}),
        grid_dimensions: [3]u32,
    ) void {
        const address: vk.DeviceAddress = data.addr;
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

    pub fn barrier(
        command_buffer: CommandBuffer,
        d: Device,
        before: Stage,
        after: Stage,
        hazard: Hazard, // TODO: investigate how to handle hazards flags
    ) void {
        const src_stage = gpu_to_vk.pipelineStage(before);
        var dst_stage = gpu_to_vk.pipelineStage(after);
        if (hazard.draw_arguments) {
            dst_stage.draw_indirect_bit = true;
        }
        if (hazard.depth_stencil) {
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

    /// 256 bytes is a typical optimal alignment
    pub fn copyTextureToBuffer(
        command_buffer: CommandBuffer,
        d: *Device,
        dest: Slice(u8, .{ .@"align" = .@"16" }),
        src: Slice(u8, .{}),
        texture: Texture,
    ) void {
        _ = src;
        const entry, const offset = d.heap.addrToEntryAndOffset(dest.ptr.addr);
        const region: vk.BufferImageCopy2 = .{
            .buffer_offset = offset,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = texture.info.layer_count,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{
                .width = texture.info.dimensions[0],
                .height = texture.info.dimensions[1],
                .depth = texture.info.dimensions[2],
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

pub const Texture = struct {
    image: vk.Image,
    info: Info,
    views: std.hash_map.AutoHashMapUnmanaged(ViewInfo, vk.ImageView),

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

    pub const Info = struct {
        type: Type = .@"2d",
        dimensions: [3]u32,
        mip_count: u32 = 1,
        layer_count: u32 = 1,
        // sample_count: u32 = 1, TODO
        format: Format = .none,
        usage: Usage = .{},
    };

    pub const ViewInfo = struct {
        const all_mips = std.math.maxInt(u8);
        const all_layers = std.math.maxInt(u16);

        format: Format = .none,
        base_mip: u8 = 0,
        mip_count: u8 = all_mips,
        base_layer: u16 = 0,
        layer_count: u16 = all_layers,
    };

    pub const Descriptor = struct {
        data: [64]u8,

        pub fn sizeAndHeapAlignment(d: *Device) SizeAndAlignment {
            const buffer_properties = d.descriptorBufferProperties();
            return .{
                .size = descriptorSize(buffer_properties.*),
                .alignment = .fromByteUnits(buffer_properties.descriptor_buffer_offset_alignment),
            };
        }

        pub fn store(descriptor: Descriptor, d: *Device, heap_ptr: []u8, index: usize) void {
            const buffer_properties = d.descriptorBufferProperties();
            const size = descriptorSize(buffer_properties.*);
            @memcpy(
                @as([*]u8, @ptrCast(heap_ptr)) + size * index,
                descriptor.data[0..size],
            );
        }

        fn descriptorSize(buffer_properties: vk.PhysicalDeviceDescriptorBufferPropertiesEXT) usize {
            return @max(
                buffer_properties.sampled_image_descriptor_size,
                buffer_properties.storage_image_descriptor_size,
            );
        }
    };

    pub fn sizeAndAlignment(d: Device, info: Info) SizeAndAlignment {
        const device_image_memory_requirements: vk.DeviceImageMemoryRequirements = .{
            .p_create_info = &vkImageInfo(info),
            .plane_aspect = gpu_to_vk.aspectsForFormat(info.format),
        };
        var req: vk.MemoryRequirements2 = .{ .memory_requirements = undefined };
        d.device.getDeviceImageMemoryRequirements(&device_image_memory_requirements, &req);
        return .{
            .size = req.memory_requirements.size,
            .alignment = .fromByteUnits(req.memory_requirements.alignment),
        };
    }

    pub fn create(d: *Device, info: Info, texture_data: Slice(u8, .{})) !Texture {
        const image = try d.device.createImage(&vkImageInfo(info), null);

        const entry, const offset = d.heap.addrToEntryAndOffset(texture_data.ptr.addr);
        try d.device.bindImageMemory(image, entry.memory, offset);

        try d.pending_general_layout_transitions.put(d.gpa, image, info);
        return .{
            .image = image,
            .info = info,
            .views = .empty,
        };
    }

    pub fn destroy(texture: *Texture, d: *Device) void {
        texture.destroyInner(d, true);
    }

    fn destroyInner(texture: *Texture, d: *Device, destroy_image: bool) void {
        _ = d.pending_general_layout_transitions.swapRemove(texture.image);
        if (destroy_image) d.device.destroyImage(texture.image, null);
        var it = texture.views.valueIterator();
        while (it.next()) |view| d.device.destroyImageView(view.*, null);
        texture.views.deinit(d.gpa);
        texture.* = undefined;
    }

    pub fn storageDescriptor(texture: *Texture, d: *Device, view_info: ViewInfo) !Descriptor {
        const view = texture.views.get(view_info) orelse blk: {
            const mips_level = if (view_info.mip_count == ViewInfo.all_mips) vk.REMAINING_MIP_LEVELS else view_info.mip_count;
            const layer_count = if (view_info.layer_count == ViewInfo.all_layers) vk.REMAINING_ARRAY_LAYERS else view_info.layer_count;
            const format = if (view_info.format == .none) texture.info.format else view_info.format;
            const info: vk.ImageViewCreateInfo = .{
                .image = texture.image,
                .view_type = gpu_to_vk.viewType(texture.info.type),
                .format = gpu_to_vk.format(format),
                .subresource_range = .{
                    .aspect_mask = gpu_to_vk.aspectsForFormat(texture.info.format),
                    .base_mip_level = view_info.base_mip,
                    .level_count = mips_level,
                    .base_array_layer = view_info.base_layer,
                    .layer_count = layer_count,
                },
                .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            };
            const view = try d.device.createImageView(&info, null);
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
            .data = .{ .p_sampled_image = &image_info },
        };
        const buffer_properties = d.descriptorBufferProperties();
        var descriptor: Descriptor = .{ .data = @splat(0) };
        d.device.getDescriptorEXT(&get_info, buffer_properties.storage_image_descriptor_size, @ptrCast(&descriptor.data));
        return descriptor;
    }

    fn vkImageInfo(info: Info) vk.ImageCreateInfo {
        return .{
            .image_type = gpu_to_vk.textureType(info.type),
            .format = gpu_to_vk.format(info.format),
            .extent = .{ .width = info.dimensions[0], .height = info.dimensions[1], .depth = info.dimensions[2] },
            .mip_levels = info.mip_count,
            .array_layers = info.layer_count,
            .samples = .{ .@"1_bit" = true },
            .tiling = .optimal,
            .usage = gpu_to_vk.usageFlags(info.usage),
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

    pub fn destroy(pipeline: *Pipeline, d: Device) void {
        d.device.destroyPipeline(pipeline.pipeline, null);
        pipeline.* = undefined;
    }
};

pub const heap = struct {
    pub fn rawDeviceAllocator(d: *Device) Allocator {
        return .{
            .ptr = @ptrCast(d),
            .vtable = &.{
                .alloc = raw_device_allocator.alloc,
                .resize = Allocator.noResize, // TODO
                .remap = Allocator.noRemap, // TODO
                .free = raw_device_allocator.free,
            },
        };
    }

    pub const raw_device_allocator = struct {
        pub fn alloc(
            self: *anyopaque,
            len: usize,
            alignment: std.mem.Alignment,
            memory_type: Memory,
            ret_addr: usize,
        ) Ptr(.many, u8, .{ .optional = true }) {
            _ = ret_addr;
            const device: *Device = @ptrCast(@alignCast(self));
            return .cast(rawAlloc(device, len, alignment, memory_type) catch return .null);
        }

        pub fn free(
            self: *anyopaque,
            memory: Slice(u8, .{}),
            alignment: std.mem.Alignment,
            memory_type: Memory,
            ret_addr: usize,
        ) void {
            _ = alignment;
            _ = memory_type;
            _ = ret_addr;
            const device: *Device = @ptrCast(@alignCast(self));
            return rawFree(device, .cast(memory.ptr));
        }

        pub fn rawAlloc(
            d: *Device,
            bytes: usize,
            alignment: std.mem.Alignment,
            memory: Memory,
        ) !Ptr(.one, anyopaque, .{}) {
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
            var buffer_info: vk.BufferCreateInfo = .{
                .size = bytes,
                .usage = usage,
                .sharing_mode = if (concurrent) .concurrent else .exclusive,
                .queue_family_index_count = if (concurrent) unique_queue_families_count else 0,
                .p_queue_family_indices = if (concurrent) &unique_queue_families_buff else null,
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

            return .fromInt(device_addr);
        }

        pub fn rawFree(d: *Device, ptr: Ptr(.one, anyopaque, .{})) void {
            const index = d.heap.indexFromAddr(ptr.addr);
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

    pub const FixedBufferAllocator = struct {
        regions: std.EnumArray(Memory, Region),

        const Region = struct {
            buffer: Slice(u8, .{}),
            end_index: u64,

            const empty: Region = .{ .buffer = .empty, .end_index = 0 };

            fn ownsAddr(r: *const Region, addr: u64) bool {
                return addr >= r.buffer.ptr.addr and addr < r.buffer.ptr.addr + r.buffer.len;
            }

            fn isLastAllocation(r: *const Region, memory: Slice(u8, .{})) bool {
                return memory.ptr.addr + memory.len == r.buffer.ptr.addr + r.end_index;
            }

            fn alloc(
                r: *Region,
                len: usize,
                alignment: std.mem.Alignment,
            ) Ptr(.many, u8, .{ .optional = true }) {
                if (r.buffer.len == 0) return .null;
                const addr = std.mem.alignForward(
                    u64,
                    r.buffer.ptr.addr + r.end_index,
                    alignment.toByteUnits(),
                );
                const new_end = addr + len - r.buffer.ptr.addr;
                if (new_end > r.buffer.len) return .null;
                r.end_index = new_end;
                return .fromInt(addr);
            }

            fn resize(r: *Region, memory: Slice(u8, .{}), new_len: usize) bool {
                std.debug.assert(r.ownsAddr(memory.ptr.addr));
                if (!r.isLastAllocation(memory)) return new_len <= memory.len;
                if (new_len <= memory.len) {
                    r.end_index -= memory.len - new_len;
                    return true;
                }
                const grow = new_len - memory.len;
                if (r.end_index + grow > r.buffer.len) return false;
                r.end_index += grow;
                return true;
            }

            fn free(r: *Region, memory: Slice(u8, .{})) void {
                std.debug.assert(r.ownsAddr(memory.ptr.addr));
                if (r.isLastAllocation(memory)) r.end_index -= memory.len;
            }
        };

        pub fn init(buffers: std.EnumArray(Memory, Slice(u8, .{}))) FixedBufferAllocator {
            var fba: FixedBufferAllocator = .{ .regions = .initFill(.empty) };
            for (std.enums.values(Memory)) |m| {
                fba.regions.getPtr(m).* = .{ .buffer = buffers.get(m), .end_index = 0 };
            }
            return fba;
        }

        pub fn initAlloc(
            gpa: Allocator,
            sizes: std.enums.EnumFieldStruct(Memory, ?usize, @as(?usize, null)),
            default_size: usize,
        ) !FixedBufferAllocator {
            var fba: FixedBufferAllocator = .{ .regions = .initFill(.empty) };
            errdefer fba.deinit(gpa);
            inline for (comptime std.enums.values(Memory)) |memory| {
                const size = @field(sizes, @tagName(memory)) orelse default_size;
                const buffer = try gpa.alloc(u8, size, memory);
                if (size > 0) {
                    fba.regions.getPtr(memory).* = .{
                        .buffer = buffer,
                        .end_index = 0,
                    };
                }
            }
            return fba;
        }

        pub fn deinit(fba: *FixedBufferAllocator, gpa: Allocator) void {
            var it = fba.regions.iterator();
            while (it.next()) |item| {
                if (item.value.buffer.len > 0) gpa.free(item.value.buffer, item.key);
                item.value.* = .empty;
            }
        }

        pub fn reset(fba: *FixedBufferAllocator) void {
            for (&fba.regions.values) |*r| r.end_index = 0;
        }

        pub fn allocator(fba: *FixedBufferAllocator) Allocator {
            return .{
                .ptr = @ptrCast(fba),
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .remap = remap,
                    .free = free,
                },
            };
        }

        fn alloc(
            self: *anyopaque,
            len: usize,
            alignment: std.mem.Alignment,
            memory_type: Memory,
            ret_addr: usize,
        ) Ptr(.many, u8, .{ .optional = true }) {
            _ = ret_addr;
            const fba: *FixedBufferAllocator = @ptrCast(@alignCast(self));
            return fba.regions.getPtr(memory_type).alloc(len, alignment);
        }

        fn resize(
            self: *anyopaque,
            memory: Slice(u8, .{}),
            alignment: std.mem.Alignment,
            new_len: usize,
            memory_type: Memory,
            ret_addr: usize,
        ) bool {
            _ = alignment;
            _ = ret_addr;
            const fba: *FixedBufferAllocator = @ptrCast(@alignCast(self));
            return fba.regions.getPtr(memory_type).resize(memory, new_len);
        }

        fn remap(
            self: *anyopaque,
            memory: Slice(u8, .{}),
            alignment: std.mem.Alignment,
            new_len: usize,
            memory_type: Memory,
            ret_addr: usize,
        ) Ptr(.many, u8, .{ .optional = true }) {
            return if (resize(self, memory, alignment, new_len, memory_type, ret_addr))
                .{ .addr = memory.ptr.addr }
            else
                .null;
        }

        fn free(
            self: *anyopaque,
            memory: Slice(u8, .{}),
            alignment: std.mem.Alignment,
            memory_type: Memory,
            ret_addr: usize,
        ) void {
            _ = alignment;
            _ = ret_addr;
            const fba: *FixedBufferAllocator = @ptrCast(@alignCast(self));
            fba.regions.getPtr(memory_type).free(memory);
        }
    };
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
    std.debug.dumpCurrentStackTrace(.{});
    return .false;
}
