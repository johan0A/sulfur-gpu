struct Data {
    uint32_t output_texture;
    float32_t time;
};

[[vk::push_constant]]
uniform Data* data;

[[vk::binding(0, 0)]]
RWTexture2D<float4> texture_heap[];

float positiveMod(float x, float y) {
    return x - y * floor(x / y);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 id : SV_DispatchThreadID) {
    const uint output_texture = data.output_texture;
    const float time = data.time;

    var texture = texture_heap[output_texture];

    uint width;
    uint height;
    texture.GetDimensions(width, height);

    if (id.x >= width || id.y >= height) {
        return;
    }

    const uint2 texel_coord = id.xy;

    float2 frag_coord = float2(id.xy) + 0.5f;
    frag_coord.y = float(height) - frag_coord.y;

    const float2 resolution = float2(width, height);
    const float2 p = (2.0f * frag_coord - resolution) / resolution.y;

    const float tau = 6.28318530718f;
    const float a = atan2(p.x, p.y);
    const float r = length(p) * 0.75f;

    float2 uv = float2(a / tau, r);

    float x_col = (uv.x - time / 3.0f) * 3.0f;
    x_col = positiveMod(x_col, 3.0f);

    float3 horizontal_color = float3(0.25f, 0.25f, 0.25f);

    if (x_col < 1.0f) {
        horizontal_color.r += 1.0f - x_col;
        horizontal_color.g += x_col;
    } else if (x_col < 2.0f) {
        x_col -= 1.0f;
        horizontal_color.g += 1.0f - x_col;
        horizontal_color.b += x_col;
    } else {
        x_col -= 2.0f;
        horizontal_color.b += 1.0f - x_col;
        horizontal_color.r += x_col;
    }

    uv = 2.0f * uv - 1.0f;

    const float oscillation = clamp(
        floor(5.0f + 10.0f * cos(time)),
        0.0f,
        10.0f
    );

    float beam_width = 0.7f;
    beam_width += 0.5f * cos(uv.x * 10.0f * tau * 0.15f * oscillation);
    beam_width *= abs(1.0f / (30.0f * uv.y));

    const float3 final_color = beam_width * horizontal_color;

    texture[texel_coord] = float4(final_color, 1.0f);
}