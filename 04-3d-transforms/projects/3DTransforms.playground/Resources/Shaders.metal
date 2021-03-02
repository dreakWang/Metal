#include <metal_stdlib>
using namespace metal;

/*
 Here, you set the [[position]] attribute which tells the rasterizer
 which value contains the position.
 You also create a property with the [[point_size]] attribute.
 Points are tiny; the size of a pixel. On a retina screen, you wouldn’t see the point,
 so you’ll make it larger.
 The value of this property tells the GPU the size of the point that it will draw.
 */
struct VertexOut {
  float4 position [[position]];
  float point_size [[point_size]];
};


/*
 Initially you’ll just draw a single point,
 but shortly you’ll be sending to the GPU the three vertices of a triangle.
 These will be an array of float3s containing the xyz position of the vertex.
 On the Swift side, you’ll set the vertices up in buffer index 0.
 constant tells the GPU to use constant address space.
 This is optimized for accessing the same variable over several vertex functions in parallel.
 Device address space, keyword device,
 is best for when you access different parts of a buffer over the parallel functions.
 You would use device when using a buffer with points and color data interleaved, for example.
 */
//vertex VertexOut
//       vertex_main(constant float3 *vertices [[buffer(0)]],
/*
 The attribute [[vertex_id]] informs the vertex function of the current id of the vertex.
 It’s the index into the array.
 */
//  uint id [[vertex_id]])

vertex VertexOut vertex_main(constant float3 *vertices [[buffer(0)]],
                             constant float4x4 &matrix [[buffer(1)]],
                             uint id [[vertex_id]]
                             )

{
  //Extract out the vertex position from the array and turn it into a float4.
  VertexOut vertex_out {
    //.position = float4(vertices[id], 1),
    .position = matrix * float4(vertices[id], 1),
    //Set the point size. You can make this larger or smaller as you prefer.
    .point_size = 20.0
  };
  return vertex_out;
}

/*
 You’ll send the fragment function the color that it should draw.
 You’ll put this color value in buffer index 0 on the Swift side.
 */
fragment float4 fragment_main(constant float4 &color [[buffer(0)]]) {
  return color;
}
