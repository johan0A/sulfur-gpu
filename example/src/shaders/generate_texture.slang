struct Data {
    uint output_texture;
};

[[vk::push_constant]]
uniform Data* data;

[[vk::binding(0, 0)]]
RWTexture2D<float4> texture_heap[];

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 id : SV_DispatchThreadID) {
    uint output_texture = data->output_texture;
    texture_heap[output_texture][id.xy] = float4(
        float(id.x) / 7.0,
        float(id.y) / 7.0,
        0.25,
        1.0
    );
}