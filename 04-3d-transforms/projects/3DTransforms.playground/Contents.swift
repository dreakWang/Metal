import MetalKit
import PlaygroundSupport

// set up View
device = MTLCreateSystemDefaultDevice()!
let frame = NSRect(x: 0, y: 0, width: 200, height: 200)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)
view.device = device

// Metal set up is done in Utility.swift

// set up render pass
guard let drawable = view.currentDrawable,
  let descriptor = view.currentRenderPassDescriptor,
  let commandBuffer = commandQueue.makeCommandBuffer(),
  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
    fatalError()
}
renderEncoder.setRenderPipelineState(pipelineState)

// drawing code here
//var vertices: [float3] = [[0, 0, 0.5]]
var vertices: [float3] = [
    [-0.7,  0.8,   1],
    [-0.7, -0.4,   1],
    [ 0.4,  0.2,   1]
]
var matrix = matrix_identity_float4x4

renderEncoder.setVertexBytes(&matrix,
           length: MemoryLayout<float4x4>.stride, index: 1)
/*
 Here, you create an MTLBuffer containing vertices.
 The length is the number of vertices multiplied by the size of a float3 .
 */
let originalBuffer = device.makeBuffer(bytes: &vertices,
                                       length: MemoryLayout<float3>.stride * vertices.count,
                                       options: [])
/*
 Set up the buffers for the vertex and fragment functions
 you assign the MTLBuffer containing vertices to index 0 and then assign the color,
 light gray, to index 0 for the fragment function. lightGrayColor is defined in Utility.swift.
 */
renderEncoder.setVertexBuffer(originalBuffer,
                              offset: 0,
                              index: 0)
renderEncoder.setFragmentBytes(&lightGrayColor,
                               length: MemoryLayout<float4>.stride,
                               index: 0)

renderEncoder.drawPrimitives(type: .triangle,
                             vertexStart: 0,
                             vertexCount: vertices.count)

/*
 You’ll now move the vertex right and down and create a second buffer with the new values.
 Here, you added a displacement value to the original vertex and created a new MTLBuffer
 that holds these new values.
 */
//vertices[0] += [0.3, -0.4, 0]
//process each vertex and multiply by the transformation matrix
//float4($0, 1) ++
/*
vertices = vertices.map {
    let vertex = matrix * float4($0, 1)
    return [vertex.x, vertex.y, vertex.z]
}
 */
/*
 above, You may have noticed that this vertex processing code is taking place on the CPU.
 This is serial processing, which is much more inefficient compared to parallel processing.
 There’s another place where each vertex is being processed — the GPU.
 You can pass the GPU your transformation matrix and multiply every vertex
 in the vertices array by the matrix in the vertex shader.
 The GPU is optimized for matrix calculation.
 */

// translate
//matrix.columns.3 = [0.3, -0.4, 0, 1]
// scaling
/*
let scaleX: Float = 1.2
let scaleY: Float = 0.5
matrix = float4x4 (
    [scaleX, 0, 0, 0],
    [0, scaleY, 0, 0],
    [0,      0, 1, 0],
    [0,      0, 0, 1]
)
 */
let angle = Float.pi / 2.0
//matrix.columns.0 = [cos(angle), -sin(angle), 0, 0]
//matrix.columns.1 = [sin(angle), cos(angle), 0, 0]
var distanceVector = float4(vertices.last!.x,
                            vertices.last!.y,
                            vertices.last!.z, 1)
var translate = matrix_identity_float4x4
translate.columns.3 = distanceVector
var rotate = matrix_identity_float4x4
rotate.columns.0 = [cos(angle), -sin(angle), 0, 0]
rotate.columns.1 = [sin(angle), cos(angle), 0, 0]
/*
 Remember the steps. Step 1 was to translate all the other vertices
 by the distance from the world origin. You can achieve this
 by setting a matrix to the vertex’s vector value and using the translate matrix’s inverse.
 相当于把坐标系左移，然后旋转，然后再移动回去，可以去掉translate和rotate看下效果
 */
matrix = translate * rotate * translate.inverse


renderEncoder.setVertexBytes(&matrix,
                             length: MemoryLayout<float4x4>.stride,
                             index: 1)


var transformedBuffer = device.makeBuffer(bytes: &vertices,
                                          length: MemoryLayout<float3>.stride * vertices.count,
                                          options: [])
/*
 Set up the vertex function with the new buffer, color the point red and draw.
 */
renderEncoder.setVertexBuffer(transformedBuffer,
                              offset: 0,
                              index: 0)

renderEncoder.setFragmentBytes(&redColor,
                               length: MemoryLayout<float4>.stride,
                               index: 0)

renderEncoder.drawPrimitives(type: .triangle,
                             vertexStart: 0,
                             vertexCount: vertices.count)



renderEncoder.endEncoding()
commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view
