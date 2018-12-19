//
//  Eye.swift
//  FaceInvander
//
//  Created by Viktor Yamchinov on 19/12/2018.
//  Copyright © 2018 Viktor Yamchinov. All rights reserved.
//

import UIKit
import SceneKit

class Eye: SCNNode {
    let target = SCNNode()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented.")
    }
    
    init(color: UIColor) {
        super.init()
        // create cylinder with 0.5cm radius that is 20cm long
        let geometry = SCNCylinder(radius: 0.005, height: 0.2)
        // color it
        geometry.firstMaterial?.diffuse.contents = color
        // wrap it in SCeneKit Node
        let node = SCNNode(geometry: geometry)
        // rotate it 90 degrees so it faces away from user
        node.eulerAngles.x = -.pi / 2
        // move it over their eyes
        node.position.z = 0.1
        // make it transparent
        node.opacity = 0.5
        // add cylinder to eye node
        addChildNode(node)
        // add to target node
        addChildNode(target)
        // move target one meter away
        target.position.z = 1
    }
}
