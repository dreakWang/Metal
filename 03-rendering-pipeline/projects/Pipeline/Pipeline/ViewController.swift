//
//  ViewController.swift
//  Pipeline
//
//  Created by Haoran wang on 3/1/21.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    var renderer: Renderer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        // subclass MTKView anzd use this view in the storyboard
        guard let metalView = view as? MTKView else {
            fatalError("metal view not set up in storyboard")
        }
        renderer = Renderer(metalView: metalView)
    }
    
}
