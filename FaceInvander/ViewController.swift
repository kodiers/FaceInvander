//
//  ViewController.swift
//  FaceInvander
//
//  Created by Viktor Yamchinov on 19/12/2018.
//  Copyright © 2018 Viktor Yamchinov. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var reticule: UIImageView!
    
    let face = SCNNode()
    let leftEye = Eye(color: .red)
    let rightEye = Eye(color: .blue)
    let phone = SCNNode(geometry: SCNPlane(width: 1, height: 1))
    let smoothingAmount = 20
    var eyeLookHistory = ArraySlice<CGPoint>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.scene.rootNode.addChildNode(face)
        face.addChildNode(leftEye)
        face.addChildNode(rightEye)
        sceneView.session.delegate = self
        sceneView.scene.rootNode.addChildNode(phone)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard ARFaceTrackingConfiguration.isSupported else {
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func update(using anchor: ARFaceAnchor) {
        leftEye.simdTransform = anchor.leftEyeTransform
        rightEye.simdTransform = anchor.rightEyeTransform
        let points = [leftEye, rightEye].compactMap {eye -> CGPoint? in
            // find where first eye hit the plane
            let hitTest = phone.hitTestWithSegment(from: eye.target.worldPosition, to: eye.worldPosition)
            // convert to a screen position and send it back
            return hitTest.first?.screenPosition
        }
        guard let leftPoint = points.first, let rightPoint = points.last else { return }
        let centerPoint = CGPoint(x: (leftPoint.x + rightPoint.x) / 2, y: -(leftPoint.y + rightPoint.y) / 2)
        reticule.transform = CGAffineTransform(translationX: centerPoint.x, y: centerPoint.y)
        eyeLookHistory.append(centerPoint)
        eyeLookHistory = eyeLookHistory.suffix(smoothingAmount)
        reticule.transform = eyeLookHistory.averageTransform
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else {
            return
        }
        DispatchQueue.main.async {
            // move and rotate the main face node
            self.face.simdTransform = node.simdTransform
            // update eyes position and directions
            self.update(using: faceAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pov = sceneView.pointOfView?.simdTransform else {
            return
        }
        phone.simdTransform = pov
    }
    
}

extension SCNHitTestResult {
    var screenPosition: CGPoint {
        // size of iPhoneX screen in meters
        let physicalScale = CGSize(width: 0.062 / 2, height: 0.135 / 2)
        // size of iPhoneX screen in points
        let screenResolution = UIScreen.main.bounds.size
        let screenX = CGFloat(localCoordinates.x) / physicalScale.width
        let screenY = CGFloat(localCoordinates.y) / physicalScale.height * screenResolution.height
        return CGPoint(x: screenX, y: screenY)
    }
}

extension Collection where Element == CGPoint {
    var averageTransform: CGAffineTransform {
        // start with 0 for X and Y
        var x: CGFloat = 0
        var y: CGFloat = 0
        // add all values to the running totals
        for item in self {
            x += item.x
            y += item.y
        }
        let floatCount = CGFloat(count)
        return CGAffineTransform(translationX: x / floatCount, y: y / floatCount)
    }
}
