struct VertexOutput {
    float4 position : SV_Position;

    [[vk::location(0)]]
    float3 color : COLOR0;
};

struct Data {
    float3 *positions;
    float3 *colors;
};

[[vk::push_constant]]
uniform Data *data;

[shader("vertex")]
VertexOutput main(uint vertex_index : SV_VertexID) {
    VertexOutput output;
    output.position = float4(data.positions[vertex_index], 1.0);
    output.color = data.colors[vertex_index];
    return output;
}