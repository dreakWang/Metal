//
//  Renderer.swift
//  Pipeline
//
//  Created by Haoran wang on 3/1/21.
//
/*
 you create an initializer and make Renderer conform to MTKViewDelegate
 with the two MTKView delegate methods
 */
import MetalKit

class Renderer: NSObject {
    
    var timer: Float = 0
    
    // MTLDevice: The software reference to the GPU hardware device
    static var device: MTLDevice!
    /*
     MTLCommandQueue: Responsible for creating and
     organizing MTLCommandBuffers each frame.
     */
    static var commandQueue: MTLCommandQueue!
    
    var mesh: MTKMesh!
    /*
     MTLBuffer: Holds data, such as vertex information,
     in a form that you can send to the GPU.
     */
    var vertexBuffer: MTLBuffer!
    /*
     Sets the information for the draw, such as which shader functions to use,
     what depth and color settings to use and how to read the vertex data
     */
    var pipelineState: MTLRenderPipelineState!
    
    init(metalView: MTKView) {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            fatalError("GPU not available")
        }
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        metalView.device = device
        
        let mdlMesh = Primitive.makeCube(device: device, size: 1)
        do {
            mesh = try MTKMesh(mesh: mdlMesh,
                               device: device)
        } catch let error {
            print(error.localizedDescription)
        }
        /*
         set up the MTLBuffer that contains the vertex data
         you’ll send to the GPU. This puts the mesh data in an MTLBuffer.
         */
        vertexBuffer = mesh.vertexBuffers[0].buffer
        
        /*
         Now, you need to set up the pipeline state so that the
         GPU will know how to render the data.
         */
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        
        //Now, create the pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        /*
         You also set the pipeline’s vertex descriptor.
         This is how the GPU will know how to interpret the vertex data
         that you’ll present in the mesh data MTLBuffer
         */
        pipelineDescriptor.vertexDescriptor =
              MTKMetalVertexDescriptorFromModelIO(mdlMesh.vertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        do {
          pipelineState =
            try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
          fatalError(error.localizedDescription)
        }
        
        
        super.init()
        
        metalView.clearColor = MTLClearColor(red: 1.0,
                                             green: 1.0,
                                             blue: 0.8,
                                             alpha: 1.0)
        /*
         It also sets Renderer as the delegate for metalView
         so that the view will call the MTKViewDelegate drawing methods
         */
        metalView.delegate = self
    }
}

//
extension Renderer: MTKViewDelegate {
    /*
     mtkView(_:drawableSizeWillChange:):
     Gets called every time the size of the window changes.
     This allows you to update the render coordinate system.
     */
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    /*
     draw(in:): Gets called every frame.
     */
    func draw(in view: MTKView) {
        //print("draw")
        /*
         This sets up the render command encoder and presents the view’s drawable texture
         to the GPU
         */
        guard
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }
        
        /*
         Every frame you update the timer.
         You want your cube to move up and down the screen,
         so you’ll use a value between -1 and 1.
         Using sin() is a great way to achieve this as sine values are always -1 to 1.
         */
        timer += 0.05
        var currentTime = sin(timer)
        /*
         If you’re only sending a small amount of data (less than 4kb) to the GPU,
         setVertexBytes(_:length:index:) is an alternative to setting up a MTLBuffer.
         Here, you set currentTime to be at index 1 in the buffer argument table.
         */
        renderEncoder.setVertexBytes(&currentTime,
                                     length: MemoryLayout<Float>.stride,
                                     index: 1)
        
        // drawing code goes here
        /*
         You’ve now set up the GPU commands to set the pipeline state,
         the vertex buffer, and perform the draw calls on the mesh’s submeshes.
         When you commit the command buffer at the end of draw(in:),
         this indicates to the GPU that all the data and the pipeline are ready
         and the GPU can take over
         */
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        renderEncoder.endEncoding()
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
