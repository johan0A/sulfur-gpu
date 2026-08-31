// Generated file, do not edit.
// version: 0.1.0

const std = @import("std");
const sf = @import("sf_minimal.zig");

const HandleTypes = struct {
    Surface: type,
    Device: type,
    Queue: type,
    Semaphore: type,
    Swapchain: type,
    CommandBuffer: type,
    Texture: type,
    Pipeline: type,
};

fn Functions(handle_types: HandleTypes) type {
    return struct {
        createSurfaceWin32: fn (
            device: *handle_types.Device,
            desc: sf.SurfaceWin32Desc,
        ) *handle_types.Surface,
        createSurfaceXlib: fn (
            device: *handle_types.Device,
            desc: sf.SurfaceXlibDesc,
        ) *handle_types.Surface,
        destroySurface: fn (
            surface: *handle_types.Surface,
        ) void,
        surfaceSupportedUsage: fn (
            device: *handle_types.Device,
            surface: *handle_types.Surface,
        ) sf.TextureUsage,
        surfaceFormats: fn (
            device: *handle_types.Device,
            surface: *handle_types.Surface,
            formats_capacity: usize,
            formats: ?[*]sf.Format,
            format_count: *usize,
        ) void,
        surfacePresentModes: fn (
            device: *handle_types.Device,
            surface: *handle_types.Surface,
            present_modes_capacity: usize,
            present_modes: ?[*]sf.PresentMode,
            present_mode_count: *usize,
        ) void,
        deviceToHostPointer: fn (
            device: *handle_types.Device,
            address: sf.DeviceAddress,
        ) *anyopaque,
        malloc: fn (
            device: *handle_types.Device,
            size: usize,
            alignment: usize,
            memory: sf.Memory,
        ) sf.DeviceAddress,
        free: fn (
            device: *handle_types.Device,
            address: sf.DeviceAddress,
        ) void,
        descriptorSizeAndHeapAlign: fn (
            device: *handle_types.Device,
        ) sf.SizeAndAlign,
        storeDescriptor: fn (
            device: *handle_types.Device,
            descriptor: *const sf.Descriptor,
            heap: [*]u8,
            index: usize,
        ) void,
        getQueue: fn (
            device: *handle_types.Device,
            queue_type: sf.QueueType,
        ) *handle_types.Queue,
        startCommandRecording: fn (
            queue: *handle_types.Queue,
            command_buffer: **handle_types.CommandBuffer,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            Unknown,
        }!void,
        submit: fn (
            queue: *handle_types.Queue,
            command_buffer_count: usize,
            command_buffers: [*]const *handle_types.CommandBuffer,
        ) error{
            OutOfDeviceMemory,
            OutOfMemory,
            DeviceLost,
            Unknown,
        }!void,
        submitAndSignal: fn (
            queue: *handle_types.Queue,
            command_buffer_count: usize,
            command_buffers: [*]const *handle_types.CommandBuffer,
            signal_semaphore: *handle_types.Semaphore,
            signal_value: u64,
        ) error{
            OutOfDeviceMemory,
            OutOfMemory,
            DeviceLost,
            Unknown,
        }!void,
        createSemaphore: fn (
            device: *handle_types.Device,
            initial_value: u64,
            semaphore: **handle_types.Semaphore,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            Unknown,
        }!void,
        destroySemaphore: fn (
            semaphore: *handle_types.Semaphore,
        ) void,
        waitSemaphore: fn (
            semaphore: *handle_types.Semaphore,
            value: u64,
        ) error{
            OutOfDeviceMemory,
            OutOfMemory,
            DeviceLost,
            Unknown,
        }!void,
        createSwapchain: fn (
            queue: *handle_types.Queue,
            surface: *handle_types.Surface,
            desc: sf.SwapchainDesc,
            swapchain: **handle_types.Swapchain,
        ) error{
            OutOfDeviceMemory,
            OutOfMemory,
            SurfaceLost,
            Unknown,
        }!void,
        destroySwapchain: fn (
            swapchain: *handle_types.Swapchain,
        ) void,
        swapchainAcquireNextTexture: fn (
            swapchain: *handle_types.Swapchain,
            queue: *handle_types.Queue,
            width: u32,
            height: u32,
            texture: **handle_types.Texture,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            DeviceLost,
            SurfaceLost,
            Unknown,
        }!void,
        swapchainPresent: fn (
            swapchain: *handle_types.Swapchain,
            queue: *handle_types.Queue,
            semaphore: *handle_types.Semaphore,
            semaphore_value: u64,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            DeviceLost,
            SurfaceLost,
            Unknown,
        }!void,
        setActiveTextureHeap: fn (
            command_buffer: *handle_types.CommandBuffer,
            heap_address: sf.DeviceAddress,
        ) void,
        setPipeline: fn (
            command_buffer: *handle_types.CommandBuffer,
            pipeline: *handle_types.Pipeline,
        ) void,
        dispatch: fn (
            command_buffer: *handle_types.CommandBuffer,
            data: sf.DeviceAddress,
            x: u32,
            y: u32,
            z: u32,
        ) void,
        barrier: fn (
            command_buffer: *handle_types.CommandBuffer,
            before: sf.Stage,
            after: sf.Stage,
            hazard: sf.Hazard,
        ) void,
        copyTextureToBuffer: fn (
            command_buffer: *handle_types.CommandBuffer,
            source: sf.DeviceAddress,
            destination: sf.DeviceAddress,
            texture: *handle_types.Texture,
        ) void,
        copyBufferToTexture: fn (
            command_buffer: *handle_types.CommandBuffer,
            source: sf.DeviceAddress,
            destination: sf.DeviceAddress,
            texture: *handle_types.Texture,
        ) void,
        beginRenderPass: fn (
            command_buffer: *handle_types.CommandBuffer,
            desc: sf.RenderPassDesc,
        ) void,
        endRenderPass: fn (
            command_buffer: *handle_types.CommandBuffer,
        ) void,
        draw: fn (
            command_buffer: *handle_types.CommandBuffer,
            vertex_data: sf.DeviceAddress,
            pixel_data: sf.DeviceAddress,
            vertex_count: u32,
            instance_count: u32,
        ) void,
        drawIndexed: fn (
            command_buffer: *handle_types.CommandBuffer,
            vertex_data: sf.DeviceAddress,
            pixel_data: sf.DeviceAddress,
            index_type: sf.IndexType,
            indices: sf.DeviceAddress,
            index_count: u32,
        ) void,
        drawIndexedInstanced: fn (
            command_buffer: *handle_types.CommandBuffer,
            vertex_data: sf.DeviceAddress,
            pixel_data: sf.DeviceAddress,
            index_type: sf.IndexType,
            indices: sf.DeviceAddress,
            index_count: u32,
            instance_count: u32,
        ) void,
        drawIndexedInstancedIndirect: fn (
            command_buffer: *handle_types.CommandBuffer,
            vertex_data: sf.DeviceAddress,
            pixel_data: sf.DeviceAddress,
            index_type: sf.IndexType,
            indices: sf.DeviceAddress,
            arguments: sf.DeviceAddress,
        ) void,
        textureSizeAndAlign: fn (
            device: *handle_types.Device,
            desc: sf.TextureDesc,
        ) sf.SizeAndAlign,
        createTexture: fn (
            device: *handle_types.Device,
            desc: sf.TextureDesc,
            data: sf.DeviceAddress,
            texture: **handle_types.Texture,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            Unknown,
        }!void,
        destroyTexture: fn (
            texture: *handle_types.Texture,
        ) void,
        textureStorageDescriptor: fn (
            texture: *handle_types.Texture,
            desc: sf.TextureViewDesc,
            descriptor: *sf.Descriptor,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            Unknown,
        }!void,
        textureViewDescriptor: fn (
            texture: *handle_types.Texture,
            desc: sf.TextureViewDesc,
            descriptor: *sf.Descriptor,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            Unknown,
        }!void,
        createComputePipeline: fn (
            device: *handle_types.Device,
            ir_size: usize,
            ir: [*]const u8,
            pipeline: **handle_types.Pipeline,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            Unknown,
        }!void,
        createGraphicsPipeline: fn (
            device: *handle_types.Device,
            vertex_ir_size: usize,
            vertex_ir: [*]const u8,
            pixel_ir_size: usize,
            pixel_ir: [*]const u8,
            desc: sf.GraphicsPipelineDesc,
            pipeline: **handle_types.Pipeline,
        ) error{
            OutOfMemory,
            OutOfDeviceMemory,
            Unknown,
        }!void,
        destroyPipeline: fn (
            pipeline: *handle_types.Pipeline,
        ) void,
    };
}

const Error = error{
    OutOfMemory,
    OutOfDeviceMemory,
    DeviceLost,
    SurfaceLost,
    Unknown,
};

fn cResult(result: anytype) sf.Result {
    if (result) return .ok else |err| return switch (@as(Error, err)) {
        error.OutOfMemory => .out_of_memory,
        error.OutOfDeviceMemory => .out_of_device_memory,
        error.DeviceLost => .device_lost,
        error.SurfaceLost => .surface_lost,
        error.Unknown => .unknown,
    };
}

fn CFunctions(comptime handle_types: HandleTypes, comptime functions: Functions(handle_types)) type {
    return struct {
        pub fn createSurfaceWin32(
            device: *handle_types.Device,
            desc: sf.SurfaceWin32Desc,
        ) callconv(sf.@"callconv") *handle_types.Surface {
            return functions.createSurfaceWin32(
                device,
                desc,
            );
        }

        pub fn createSurfaceXlib(
            device: *handle_types.Device,
            desc: sf.SurfaceXlibDesc,
        ) callconv(sf.@"callconv") *handle_types.Surface {
            return functions.createSurfaceXlib(
                device,
                desc,
            );
        }

        pub fn destroySurface(
            surface: *handle_types.Surface,
        ) callconv(sf.@"callconv") void {
            return functions.destroySurface(
                surface,
            );
        }

        pub fn surfaceSupportedUsage(
            device: *handle_types.Device,
            surface: *handle_types.Surface,
        ) callconv(sf.@"callconv") sf.TextureUsage {
            return functions.surfaceSupportedUsage(
                device,
                surface,
            );
        }

        pub fn surfaceFormats(
            device: *handle_types.Device,
            surface: *handle_types.Surface,
            formats_capacity: usize,
            formats: ?[*]sf.Format,
            format_count: *usize,
        ) callconv(sf.@"callconv") void {
            return functions.surfaceFormats(
                device,
                surface,
                formats_capacity,
                formats,
                format_count,
            );
        }

        pub fn surfacePresentModes(
            device: *handle_types.Device,
            surface: *handle_types.Surface,
            present_modes_capacity: usize,
            present_modes: ?[*]sf.PresentMode,
            present_mode_count: *usize,
        ) callconv(sf.@"callconv") void {
            return functions.surfacePresentModes(
                device,
                surface,
                present_modes_capacity,
                present_modes,
                present_mode_count,
            );
        }

        pub fn deviceToHostPointer(
            device: *handle_types.Device,
            address: sf.DeviceAddress,
        ) callconv(sf.@"callconv") *anyopaque {
            return functions.deviceToHostPointer(
                device,
                address,
            );
        }

        pub fn malloc(
            device: *handle_types.Device,
            size: usize,
            alignment: usize,
            memory: sf.Memory,
        ) callconv(sf.@"callconv") sf.DeviceAddress {
            return functions.malloc(
                device,
                size,
                alignment,
                memory,
            );
        }

        pub fn free(
            device: *handle_types.Device,
            address: sf.DeviceAddress,
        ) callconv(sf.@"callconv") void {
            return functions.free(
                device,
                address,
            );
        }

        pub fn descriptorSizeAndHeapAlign(
            device: *handle_types.Device,
        ) callconv(sf.@"callconv") sf.SizeAndAlign {
            return functions.descriptorSizeAndHeapAlign(
                device,
            );
        }

        pub fn storeDescriptor(
            device: *handle_types.Device,
            descriptor: *const sf.Descriptor,
            heap: [*]u8,
            index: usize,
        ) callconv(sf.@"callconv") void {
            return functions.storeDescriptor(
                device,
                descriptor,
                heap,
                index,
            );
        }

        pub fn getQueue(
            device: *handle_types.Device,
            queue_type: sf.QueueType,
        ) callconv(sf.@"callconv") *handle_types.Queue {
            return functions.getQueue(
                device,
                queue_type,
            );
        }

        pub fn startCommandRecording(
            queue: *handle_types.Queue,
            command_buffer: **handle_types.CommandBuffer,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.startCommandRecording(
                queue,
                command_buffer,
            ));
        }

        pub fn submit(
            queue: *handle_types.Queue,
            command_buffer_count: usize,
            command_buffers: [*]const *handle_types.CommandBuffer,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.submit(
                queue,
                command_buffer_count,
                command_buffers,
            ));
        }

        pub fn submitAndSignal(
            queue: *handle_types.Queue,
            command_buffer_count: usize,
            command_buffers: [*]const *handle_types.CommandBuffer,
            signal_semaphore: *handle_types.Semaphore,
            signal_value: u64,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.submitAndSignal(
                queue,
                command_buffer_count,
                command_buffers,
                signal_semaphore,
                signal_value,
            ));
        }

        pub fn createSemaphore(
            device: *handle_types.Device,
            initial_value: u64,
            semaphore: **handle_types.Semaphore,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.createSemaphore(
                device,
                initial_value,
                semaphore,
            ));
        }

        pub fn destroySemaphore(
            semaphore: *handle_types.Semaphore,
        ) callconv(sf.@"callconv") void {
            return functions.destroySemaphore(
                semaphore,
            );
        }

        pub fn waitSemaphore(
            semaphore: *handle_types.Semaphore,
            value: u64,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.waitSemaphore(
                semaphore,
                value,
            ));
        }

        pub fn createSwapchain(
            queue: *handle_types.Queue,
            surface: *handle_types.Surface,
            desc: sf.SwapchainDesc,
            swapchain: **handle_types.Swapchain,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.createSwapchain(
                queue,
                surface,
                desc,
                swapchain,
            ));
        }

        pub fn destroySwapchain(
            swapchain: *handle_types.Swapchain,
        ) callconv(sf.@"callconv") void {
            return functions.destroySwapchain(
                swapchain,
            );
        }

        pub fn swapchainAcquireNextTexture(
            swapchain: *handle_types.Swapchain,
            queue: *handle_types.Queue,
            width: u32,
            height: u32,
            texture: **handle_types.Texture,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.swapchainAcquireNextTexture(
                swapchain,
                queue,
                width,
                height,
                texture,
            ));
        }

        pub fn swapchainPresent(
            swapchain: *handle_types.Swapchain,
            queue: *handle_types.Queue,
            semaphore: *handle_types.Semaphore,
            semaphore_value: u64,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.swapchainPresent(
                swapchain,
                queue,
                semaphore,
                semaphore_value,
            ));
        }

        pub fn setActiveTextureHeap(
            command_buffer: *handle_types.CommandBuffer,
            heap_address: sf.DeviceAddress,
        ) callconv(sf.@"callconv") void {
            return functions.setActiveTextureHeap(
                command_buffer,
                heap_address,
            );
        }

        pub fn setPipeline(
            command_buffer: *handle_types.CommandBuffer,
            pipeline: *handle_types.Pipeline,
        ) callconv(sf.@"callconv") void {
            return functions.setPipeline(
                command_buffer,
                pipeline,
            );
        }

        pub fn dispatch(
            command_buffer: *handle_types.CommandBuffer,
            data: sf.DeviceAddress,
            x: u32,
            y: u32,
            z: u32,
        ) callconv(sf.@"callconv") void {
            return functions.dispatch(
                command_buffer,
                data,
                x,
                y,
                z,
            );
        }

        pub fn barrier(
            command_buffer: *handle_types.CommandBuffer,
            before: sf.Stage,
            after: sf.Stage,
            hazard: sf.Hazard,
        ) callconv(sf.@"callconv") void {
            return functions.barrier(
                command_buffer,
                before,
                after,
                hazard,
            );
        }

        pub fn copyTextureToBuffer(
            command_buffer: *handle_types.CommandBuffer,
            source: sf.DeviceAddress,
            destination: sf.DeviceAddress,
            texture: *handle_types.Texture,
        ) callconv(sf.@"callconv") void {
            return functions.copyTextureToBuffer(
                command_buffer,
                source,
                destination,
                texture,
            );
        }

        pub fn copyBufferToTexture(
            command_buffer: *handle_types.CommandBuffer,
            source: sf.DeviceAddress,
            destination: sf.DeviceAddress,
            texture: *handle_types.Texture,
        ) callconv(sf.@"callconv") void {
            return functions.copyBufferToTexture(
                command_buffer,
                source,
                destination,
                texture,
            );
        }

        pub fn beginRenderPass(
            command_buffer: *handle_types.CommandBuffer,
            desc: sf.RenderPassDesc,
        ) callconv(sf.@"callconv") void {
            return functions.beginRenderPass(
                command_buffer,
                desc,
            );
        }

        pub fn endRenderPass(
            command_buffer: *handle_types.CommandBuffer,
        ) callconv(sf.@"callconv") void {
            return functions.endRenderPass(
                command_buffer,
            );
        }

        pub fn draw(
            command_buffer: *handle_types.CommandBuffer,
            vertex_data: sf.DeviceAddress,
            pixel_data: sf.DeviceAddress,
            vertex_count: u32,
            instance_count: u32,
        ) callconv(sf.@"callconv") void {
            return functions.draw(
                command_buffer,
                vertex_data,
                pixel_data,
                vertex_count,
                instance_count,
            );
        }

        pub fn drawIndexed(
            command_buffer: *handle_types.CommandBuffer,
            vertex_data: sf.DeviceAddress,
            pixel_data: sf.DeviceAddress,
            index_type: sf.IndexType,
            indices: sf.DeviceAddress,
            index_count: u32,
        ) callconv(sf.@"callconv") void {
            return functions.drawIndexed(
                command_buffer,
                vertex_data,
                pixel_data,
                index_type,
                indices,
                index_count,
            );
        }

        pub fn drawIndexedInstanced(
            command_buffer: *handle_types.CommandBuffer,
            vertex_data: sf.DeviceAddress,
            pixel_data: sf.DeviceAddress,
            index_type: sf.IndexType,
            indices: sf.DeviceAddress,
            index_count: u32,
            instance_count: u32,
        ) callconv(sf.@"callconv") void {
            return functions.drawIndexedInstanced(
                command_buffer,
                vertex_data,
                pixel_data,
                index_type,
                indices,
                index_count,
                instance_count,
            );
        }

        pub fn drawIndexedInstancedIndirect(
            command_buffer: *handle_types.CommandBuffer,
            vertex_data: sf.DeviceAddress,
            pixel_data: sf.DeviceAddress,
            index_type: sf.IndexType,
            indices: sf.DeviceAddress,
            arguments: sf.DeviceAddress,
        ) callconv(sf.@"callconv") void {
            return functions.drawIndexedInstancedIndirect(
                command_buffer,
                vertex_data,
                pixel_data,
                index_type,
                indices,
                arguments,
            );
        }

        pub fn textureSizeAndAlign(
            device: *handle_types.Device,
            desc: sf.TextureDesc,
        ) callconv(sf.@"callconv") sf.SizeAndAlign {
            return functions.textureSizeAndAlign(
                device,
                desc,
            );
        }

        pub fn createTexture(
            device: *handle_types.Device,
            desc: sf.TextureDesc,
            data: sf.DeviceAddress,
            texture: **handle_types.Texture,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.createTexture(
                device,
                desc,
                data,
                texture,
            ));
        }

        pub fn destroyTexture(
            texture: *handle_types.Texture,
        ) callconv(sf.@"callconv") void {
            return functions.destroyTexture(
                texture,
            );
        }

        pub fn textureStorageDescriptor(
            texture: *handle_types.Texture,
            desc: sf.TextureViewDesc,
            descriptor: *sf.Descriptor,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.textureStorageDescriptor(
                texture,
                desc,
                descriptor,
            ));
        }

        pub fn textureViewDescriptor(
            texture: *handle_types.Texture,
            desc: sf.TextureViewDesc,
            descriptor: *sf.Descriptor,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.textureViewDescriptor(
                texture,
                desc,
                descriptor,
            ));
        }

        pub fn createComputePipeline(
            device: *handle_types.Device,
            ir_size: usize,
            ir: [*]const u8,
            pipeline: **handle_types.Pipeline,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.createComputePipeline(
                device,
                ir_size,
                ir,
                pipeline,
            ));
        }

        pub fn createGraphicsPipeline(
            device: *handle_types.Device,
            vertex_ir_size: usize,
            vertex_ir: [*]const u8,
            pixel_ir_size: usize,
            pixel_ir: [*]const u8,
            desc: sf.GraphicsPipelineDesc,
            pipeline: **handle_types.Pipeline,
        ) callconv(sf.@"callconv") sf.Result {
            return cResult(functions.createGraphicsPipeline(
                device,
                vertex_ir_size,
                vertex_ir,
                pixel_ir_size,
                pixel_ir,
                desc,
                pipeline,
            ));
        }

        pub fn destroyPipeline(
            pipeline: *handle_types.Pipeline,
        ) callconv(sf.@"callconv") void {
            return functions.destroyPipeline(
                pipeline,
            );
        }
    };
}

pub fn map(
    comptime handle_types: HandleTypes,
    comptime functions: Functions(handle_types),
) std.StaticStringMap(*const anyopaque) {
    const c_functions = CFunctions(handle_types, functions);
    return .initComptime(@as([]const struct { []const u8, *const anyopaque }, &.{
        .{ "sfCreateSurfaceWin32", @ptrCast(&c_functions.createSurfaceWin32) },
        .{ "sfCreateSurfaceXlib", @ptrCast(&c_functions.createSurfaceXlib) },
        .{ "sfDestroySurface", @ptrCast(&c_functions.destroySurface) },
        .{ "sfSurfaceSupportedUsage", @ptrCast(&c_functions.surfaceSupportedUsage) },
        .{ "sfSurfaceFormats", @ptrCast(&c_functions.surfaceFormats) },
        .{ "sfSurfacePresentModes", @ptrCast(&c_functions.surfacePresentModes) },
        .{ "sfDeviceToHostPointer", @ptrCast(&c_functions.deviceToHostPointer) },
        .{ "sfMalloc", @ptrCast(&c_functions.malloc) },
        .{ "sfFree", @ptrCast(&c_functions.free) },
        .{ "sfDescriptorSizeAndHeapAlign", @ptrCast(&c_functions.descriptorSizeAndHeapAlign) },
        .{ "sfStoreDescriptor", @ptrCast(&c_functions.storeDescriptor) },
        .{ "sfGetQueue", @ptrCast(&c_functions.getQueue) },
        .{ "sfStartCommandRecording", @ptrCast(&c_functions.startCommandRecording) },
        .{ "sfSubmit", @ptrCast(&c_functions.submit) },
        .{ "sfSubmitAndSignal", @ptrCast(&c_functions.submitAndSignal) },
        .{ "sfCreateSemaphore", @ptrCast(&c_functions.createSemaphore) },
        .{ "sfDestroySemaphore", @ptrCast(&c_functions.destroySemaphore) },
        .{ "sfWaitSemaphore", @ptrCast(&c_functions.waitSemaphore) },
        .{ "sfCreateSwapchain", @ptrCast(&c_functions.createSwapchain) },
        .{ "sfDestroySwapchain", @ptrCast(&c_functions.destroySwapchain) },
        .{ "sfSwapchainAcquireNextTexture", @ptrCast(&c_functions.swapchainAcquireNextTexture) },
        .{ "sfSwapchainPresent", @ptrCast(&c_functions.swapchainPresent) },
        .{ "sfSetActiveTextureHeap", @ptrCast(&c_functions.setActiveTextureHeap) },
        .{ "sfSetPipeline", @ptrCast(&c_functions.setPipeline) },
        .{ "sfDispatch", @ptrCast(&c_functions.dispatch) },
        .{ "sfBarrier", @ptrCast(&c_functions.barrier) },
        .{ "sfCopyTextureToBuffer", @ptrCast(&c_functions.copyTextureToBuffer) },
        .{ "sfCopyBufferToTexture", @ptrCast(&c_functions.copyBufferToTexture) },
        .{ "sfBeginRenderPass", @ptrCast(&c_functions.beginRenderPass) },
        .{ "sfEndRenderPass", @ptrCast(&c_functions.endRenderPass) },
        .{ "sfDraw", @ptrCast(&c_functions.draw) },
        .{ "sfDrawIndexed", @ptrCast(&c_functions.drawIndexed) },
        .{ "sfDrawIndexedInstanced", @ptrCast(&c_functions.drawIndexedInstanced) },
        .{ "sfDrawIndexedInstancedIndirect", @ptrCast(&c_functions.drawIndexedInstancedIndirect) },
        .{ "sfTextureSizeAndAlign", @ptrCast(&c_functions.textureSizeAndAlign) },
        .{ "sfCreateTexture", @ptrCast(&c_functions.createTexture) },
        .{ "sfDestroyTexture", @ptrCast(&c_functions.destroyTexture) },
        .{ "sfTextureStorageDescriptor", @ptrCast(&c_functions.textureStorageDescriptor) },
        .{ "sfTextureViewDescriptor", @ptrCast(&c_functions.textureViewDescriptor) },
        .{ "sfCreateComputePipeline", @ptrCast(&c_functions.createComputePipeline) },
        .{ "sfCreateGraphicsPipeline", @ptrCast(&c_functions.createGraphicsPipeline) },
        .{ "sfDestroyPipeline", @ptrCast(&c_functions.destroyPipeline) },
    }));
}
