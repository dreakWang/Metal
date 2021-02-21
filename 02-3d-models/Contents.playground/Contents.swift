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

//create a command queue
guard let commandQueue = device.makeCommandQueue() else {
    fatalError("Could not create a command queue")
}

//The allocator manages the memory for the mesh data.
let allocator = MTKMeshBufferAllocator(device: device)
/*
 Model I/O creates a sphere with the specified size and returns an MDLMesh
 with all the vertex information in data buffers.
 */
/*
let mdlMesh = MDLMesh(coneWithExtent: [0.75, 0.75, 0.75],
                      segments: [10, 10],
                      inwardNormals: false,
                      cap: true,
                      geometryType: .triangles,
                      allocator: allocator)
 */
guard let assetURL = Bundle.main.url(forResource: "train",
                                     withExtension: "obj") else {
                                      fatalError("assetURL fail")
}

/*
 You create a vertex descriptor that you’ll use to configure all the properties
 that an object will need to know about.
 You can reuse this vertex descriptor with either the same values or reconfigured values
 to instantiate a different object.
 */
let vertexDescriptor = MTLVertexDescriptor()
/*
 The .obj file holds normal and texture coordinate data as well as vertex position data.
 For the moment, you don’t need the surface normals or texture coordinates, just the position.
 You tell the descriptor that the xyz position data should load as a float3,
 which is a simd data type consisting of three Float values.
 An MTLVertexDescriptor has an array of 31 attributes where you can configure the data format,
 and in future chapters you’ll load up the normal and texture coordinate attributes.
 */
vertexDescriptor.attributes[0].format = .float3
//The offset specifies where in the buffer this particular data will start
vertexDescriptor.attributes[0].offset = 0
/*
 When you send your vertex data to the GPU via the render encoder,
 you send it in an MTLBuffer and identify the buffer by an index.
 There are 31 buffers available and Metal keeps track of them in a buffer argument table.
 Use buffer 0 here so that the vertex shader function will be able to match the incoming vertex data
 in buffer 0 with this vertex layout.
 */
vertexDescriptor.attributes[0].bufferIndex = 0

/*
 Here, you specify the stride for buffer 0.
 The stride is the number of bytes between each set of vertex information.
 Referring back to the previous diagram which described position,
 normal and texture coordinate information,
 the stride between each vertex would be float3 + float3 + float2.
 However, here you’re only loading position data, so to get to the next position,
 you jump by a stride of float3. Using this buffer layout index and stride format,
 you can set up complex vertex descriptors referencing multiple MTLBuffers with different layouts.
 You have the option of interleaving position, normal and texture coordinates,
 or you can lay out a buffer containing all position data first, followed by other data.
 The SIMD3<Float> type is Swift’s equivalent to float3. Later you’ll set up a typealias for float3
 */
vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
/*
 Model I/O needs a slightly different format vertex descriptor,
 so you create a new Model I/O descriptor from the Metal vertex descriptor
 */
let meshDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
/*
 Assign a string name “position” to the attribute.
 This tells Model I/O that this is positional data.
 The normal and texture coordinate data is also available, but with this vertex descriptor,
 you told Model I/O that you’re not interested in those attributes
 as!向下转型
 */
(meshDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition

/*
 This reads the asset using the URL, vertex descriptor and memory allocator.
 You then read in the first Model I/O mesh buffer in the asset.
 Some more complex objects will have multiple meshes, but you’ll deal with that later
 */
let asset = MDLAsset(url: assetURL,
                     vertexDescriptor: meshDescriptor,
                     bufferAllocator: allocator)
let mdlMesh = asset.childObjects(of: MDLMesh.self).first as! MDLMesh


let mesh = try MTKMesh(mesh: mdlMesh,
                       device: device)
 

// begin export code
/*
 The top level of a scene in Model I/O is an MDLAsset.
 You can add child objects such as meshes,
 cameras and lights to the asset and build up a complete scene hierarchy.
//let asset = MDLAsset()
asset.add(mdlMesh)

//Check that Model I/O can export a .obj file type
let fileExtension = "obj"
guard MDLAsset.canExportFileExtension(fileExtension) else {
    fatalError("can't export a .\(fileExtension) format")
}
//Export the cone to the directory stored in Shared Playground Data.
do {
    let url = playgroundSharedDataDirectory.appendingPathComponent(
        "primitive.\(fileExtension)")
    try asset.export(to: url)
} catch {
    fatalError("Error \(error.localizedDescription)")
}
// end export code
 */

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
//guard let submesh = mesh.submeshes.first else {
//    fatalError()
//}

/*
 You draw in Metal with a draw call
 Here, you’re instructing the GPU to render a vertex buffer
 consisting of triangles with the vertices placed
 in the correct order by the submesh index information.
 This code does not do the actual render
 — that doesn’t happen until the GPU has received all the command buffer’s commands.
 */
/*
 Rendering a model in wireframe allows you to see
 the edges of each individual triangle.
 To render in wireframe, add the following line of code
 just before the draw call
 */
renderEncoder.setTriangleFillMode(.lines)
/*
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0)
 */
/*
 This loops through the submeshes and issues a draw call for each one.
 The mesh and submeshes are in MTLBuffers,
 and the submesh holds the index listing of the vertices in the mesh.
 */
for submesh in mesh.submeshes {
    renderEncoder.drawIndexedPrimitives(
        type: .triangle,
        indexCount: submesh.indexCount,
        indexType: submesh.indexType,
        indexBuffer: submesh.indexBuffer.buffer,
        indexBufferOffset: submesh.indexBuffer.offset)
}

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
