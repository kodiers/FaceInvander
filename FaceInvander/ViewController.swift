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
    var targets = [UIImageView]()
    var currentTarget = 0
    var gunshot: AVAudioPlayer?
    var startTime = CACurrentMediaTime()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.scene.rootNode.addChildNode(face)
        face.addChildNode(leftEye)
        face.addChildNode(rightEye)
        sceneView.session.delegate = self
        sceneView.scene.rootNode.addChildNode(phone)
        // create master stack view to handle the over stack views
        let rowStackView = UIStackView()
        rowStackView.translatesAutoresizingMaskIntoConstraints = false
        // force the inner stack views to space themselves equally
        rowStackView.axis = .vertical
        // and apply 20 points between them
        rowStackView.spacing = 20
        for _ in 1...6 {
            // create six columns of stack views
            let colStackView = UIStackView()
            colStackView.translatesAutoresizingMaskIntoConstraints = false
            // also equally filling and 20 points of space
            colStackView.distribution = .fillEqually
            colStackView.spacing = 20
            // horizontal layout
            colStackView.axis = .horizontal
            // add col stack views to master row stack view
            rowStackView.addArrangedSubview(colStackView)
            for _ in 1...4 {
                // inside each column add four images
                let imageView = UIImageView(image: UIImage(named: "target"))
                // make it fit inside
                imageView.contentMode = .scaleAspectFit
                imageView.alpha = 0
                targets.append(imageView)
                // add it to current column
                colStackView.addArrangedSubview(imageView)
            }
        }
        
        view.addSubview(rowStackView)
        NSLayoutConstraint.activate([
            rowStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            rowStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            rowStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            rowStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        view.bringSubviewToFront(reticule)
        targets.shuffle()
        perform(#selector(createTarget), with: nil, afterDelay: 2)
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
        if let leftBlink = anchor.blendShapes[.eyeBlinkLeft] as? Float, let rightBlink = anchor.blendShapes[.eyeBlinkRight] as? Float {
            // if both eyes simlatenously blinking more than 10% - fire and exit
            if leftBlink > 0.1 && rightBlink > 0.1 {
                fire()
                return
            }
        }
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
    
    @objc func createTarget() {
        guard currentTarget < targets.count else {
            endGame()
            return
        }
        // pick target
        let target = targets[currentTarget]
        // scale it
        target.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
        // animate it back with 0.3 seconds and make it visible
        UIView.animate(withDuration: 0.3) {
            target.transform = .identity
            target.alpha = 1
        }
        // move to next target
        currentTarget += 1
    }
    
    func fire() {
        let reticuleFrame = reticule.superview?.convert(reticule.frame, to: nil)
        // create new array by filtering our targets
        let hitTargets = targets.filter { (imageView) -> Bool in
            if imageView.alpha == 0 {
                return false
            }
            // convert image view frame to absolute coordinates
            let ourFrame = imageView.superview?.convert(imageView.frame, to: nil)
            // add this if overlap the reticule
            return (ourFrame?.intersects(reticuleFrame!))!
        }
        // pull out the first target if we have one
        guard let selected = hitTargets.first else {
            return
        }
        // hide that target
        selected.alpha = 0
        // play gun sound
        if let url = Bundle.main.url(forResource: "shot", withExtension: "wav") {
            gunshot = try? AVAudioPlayer(contentsOf: url)
            gunshot?.play()
        }
        // create another target
        perform(#selector(createTarget), with: nil, afterDelay: 1)
    }
    
    func endGame() {
        let timeTaken = Int(CACurrentMediaTime() - startTime)
        let ac = UIAlertController(title: "Game over!", message: "You took \(timeTaken) seconds.", preferredStyle: .alert)
        present(ac, animated: true, completion: nil)
        // automatically finish the score showing after three seconds
        perform(#selector(finish), with: nil, afterDelay: 3)
    }
    
    @objc func finish() {
        dismiss(animated: true) {
            self.navigationController?.popToRootViewController(animated: true)
        }
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
