struct FragmentInput {
    [[vk::location(0)]]
    float2 uv : TEXCOORD;
};

[[vk::binding(1, 1)]]
SamplerState samplers[1];

[[vk::binding(0, 0)]]
Texture2D<float4> texture_heap[];

[shader("fragment")]
float4 main(FragmentInput input) : SV_Target0 {
    SamplerState sampler = samplers[0];
    Texture2D<float4> texture = texture_heap[0];

    return texture.Sample(sampler, input.uv);
}