struct VertexOutput {
    float4 position : SV_Position;

    [[vk::location(0)]]
    float3 color : COLOR0;
};

[shader("vertex")]
VertexOutput main(uint vertex_index : SV_VertexID) {
    static const float3 positions[3] = {
        float3(-1.0, 1.0, 0.0),
        float3(0.0, -1.0, 0.0),
        float3(1.0,  1.0, 0.0)
    };

    static const float3 colors[3] = {
        float3(0.0, 0.0, 1.0),
        float3(0.0, 1.0, 0.0),
        float3(1.0, 0.0, 0.0)
    };

    VertexOutput output;
    output.position = float4(positions[vertex_index], 1.0);
    output.color = colors[vertex_index];

    return output;
}