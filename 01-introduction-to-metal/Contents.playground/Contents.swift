import PlaygroundSupport
import MetalKit

//Check for a suitable GPU by creating a device
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("GPU is not support")
}

//This configures an MTKView for the Metal renderer
//MTKView is a subclass of NSView on macOS and of UIView on iOS.
let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)
//MTLClearColor represents an RGBA value
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.9, alpha: 1)

//The allocator manages the memory for the mesh data.
let allocator = MTKMeshBufferAllocator(device: device)
/*
 Model I/O creates a sphere with the specified size and returns an MDLMesh
 with all the vertex information in data buffers.
 */
let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75],
                      segments: [100, 100],
                      inwardNormals: false,
                      geometryType: .triangles,
                      allocator: allocator)
let mesh = try MTKMesh(mesh: mdlMesh,
                       device: device)
//create a command queue
guard let commandQueue = device.makeCommandQueue() else {
    fatalError("Could not create a command queue")
}

let shader = """
#include <metal_stdlib>
using namespace metal;
struct VertexIn {
  float4 position [[ attribute(0) ]];
};
vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
  return vertex_in.position;
}
fragment float4 fragment_main() {
  return float4(1, 0, 0, 1);
}
"""

/*
 Set up a Metal library containing these two functions.
 The compiler will check that these functions exist and
 make them available to a pipeline descriptor
 */
let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
pipelineDescriptor.vertexFunction = vertexFunction
pipelineDescriptor.fragmentFunction = fragmentFunction
/*
 You’ll also describe to the GPU how the vertices are laid out
 in memory using a vertex descriptor.
 Model I/O automatically created a vertex descriptor when it loaded the sphere mesh,
 so you can just use that one.
 */
pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

//Create the pipeline state from the descriptor
let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
/*
 Creating a pipeline state takes valuable processing time,
 so all of the above should be a one-time setup.
 In a real app, you might create several pipeline states to
 call different shading functions or use different vertex layouts.
 */

//Rendering
/*
 From now on, the code should be performed every frame.
 MTKView has a delegate method that runs every frame,
 but as you’re doing a simple render which will simply fill out a static view,
 you don’t need to keep refreshing the screen every frame.
 */

/*
 You create a command buffer.
 This stores all the commands that you’ll ask the GPU to run.
 */
guard let commandBuffer = commandQueue.makeCommandBuffer(),
      /*
        You obtain a reference to the view’s render pass descriptor.
        The descriptor holds data for the render destinations, called attachments.
        Each attachment will need information such as a texture to store to,
        and whether to keep the texture throughout the render pass.
        The render pass descriptor is used to create the render command encoder.
       */
      let renderPassDescriptor = view.currentRenderPassDescriptor,
      /*
        From the command buffer,
        you get a render command encoder using the render pass descriptor.
        The render command encoder holds all the information necessary
        to send to the GPU so that it can draw the vertices.
       */
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
else { fatalError() }

renderEncoder.setRenderPipelineState(pipelineState)

/*
 The sphere mesh that you loaded earlier holds a buffer
 containing a simple list of vertices. Give this buffer to the render encoder
 */
/*
 The offset is the position in the buffer where the vertex information starts.
 The index is how the GPU vertex shader function will locate this buffer.
 */
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer,
                              offset: 0,
                              index: 0)

//This sphere only has one submesh, so you’ll just use one.
guard let submesh = mesh.submeshes.first else {
    fatalError()
}

/*
 You draw in Metal with a draw call
 Here, you’re instructing the GPU to render a vertex buffer
 consisting of triangles with the vertices placed
 in the correct order by the submesh index information.
 This code does not do the actual render
 — that doesn’t happen until the GPU has received all the command buffer’s commands.
 */
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0)

/*
 To complete sending commands to the render command encoder
 and finalize the frame, add this code
 You tell the render encoder that there are no more draw calls
 */
renderEncoder.endEncoding()
/*
 You get the drawable from the MTKView.
 The MTKView is backed by a Core Animation CAMetalLayer
 and the layer owns a drawable texture which Metal can read and write to
 */
guard let drawable = view.currentDrawable else {
    fatalError()
}
//Ask the command buffer to present the MTKView’s drawable and commit to the GPU
commandBuffer.present(drawable)
commandBuffer.commit()

//With that line of code, you’ll be able to see the Metal view in the assistant editor
PlaygroundPage.current.liveView = view
