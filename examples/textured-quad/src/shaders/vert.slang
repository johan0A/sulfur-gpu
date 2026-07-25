struct VertexOutput {
    float4 position : SV_Position;

    [[vk::location(0)]]
    float2 uv : TEXCOORD;
};

struct Data {
    float3 *positions;
    float2 *uvs;
};

[[vk::push_constant]]
uniform Data *data;

[shader("vertex")]
VertexOutput main(uint vertex_index : SV_VertexID) {
    VertexOutput output;
    output.position = float4(data.positions[vertex_index], 1.0);
    output.uv = data.uvs[vertex_index];
    return output;
}