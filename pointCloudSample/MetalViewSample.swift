/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A parent view class that displays the sample app's other views.
*/

import Foundation
import SwiftUI
import MetalKit
import ARKit

// Add a title to a view that enlarges the view to full screen on tap.
struct Texture<T: View>: ViewModifier {
    let height: CGFloat
    let width: CGFloat
    let title: String
    let view: T
    func body(content: Content) -> some View {
        VStack {
            Text(title).foregroundColor(Color.red)
            // To display the same view in the navigation, reference the view
            // directly versus using the view's `content` property.
            NavigationLink(destination: view.aspectRatio(CGSize(width: width, height: height), contentMode: .fill)) {
                view.frame(maxWidth: width, maxHeight: height, alignment: .center)
                    .aspectRatio(CGSize(width: width, height: height), contentMode: .fill)
            }
        }
    }
}

extension View {
    // Apply `zoomOnTapModifier` with a `self` reference to show the same view
    // on tap.
    func zoomOnTapModifier(height: CGFloat, width: CGFloat, title: String) -> some View {
        modifier(Texture(height: height, width: width, title: title, view: self))
    }
}
extension Image {
    init(_ texture: MTLTexture, ciContext: CIContext, scale: CGFloat, orientation: Image.Orientation, label: Text) {
        let ciimage = CIImage(mtlTexture: texture)!
        let cgimage = ciContext.createCGImage(ciimage, from: ciimage.extent)
        self.init(cgimage!, scale: 1.0, orientation: orientation, label: label)
    }
}
//- Tag: MetalDepthView
struct MetalDepthView: View {
    
    // Set the default sizes for the texture views.
    let sizeH: CGFloat = 256
    let sizeW: CGFloat = 192
    
    // Manage the AR session and AR data processing.
    //- Tag: ARProvider
    var arProvider: ARProvider = ARProvider()
    let ciContext: CIContext = CIContext()
    
    // Save the user's confidence selection.
    @State private var selectedConfidence = 0
    // Set the depth view's state data.
    @State var isToUpsampleDepth = false
    @State var isShowSmoothDepth = false
    @State var isArPaused = false
    @State private var scaleMovement: Float = 1.5
    
    var confLevels = ["🔵🟢🔴", "🔵🟢", "🔵"]
    
    var body: some View {
        if !ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
            Text("Unsupported Device: This app requires the LiDAR Scanner to access the scene's depth.")
        } else {
            NavigationView {
                GeometryReader { geometry in
                    VStack() {
                        // Size the point cloud view relative to the underlying
                        // 3D geometry by matching the textures' aspect ratio.
                        //                        HStack() {
                        //                            Spacer()
                        //                            MetalPointCloud(arData: arProvider,
                        //                                            confSelection: $selectedConfidence,
                        //                                            scaleMovement: $scaleMovement).zoomOnTapModifier(
                        //                                                height: geometry.size.width / 2 / sizeW * sizeH,
                        //                                                width: geometry.size.width / 2, title: "")
                        //                            Spacer()
                        //                        }
                        //                        HStack {
                        //                            Text("Confidence Select:")
                        //                            Picker(selection: $selectedConfidence, label: Text("Confidence Select")) {
                        //                                ForEach(0..<confLevels.count, id: \.self) { index in
                        //                                    Text(self.confLevels[index]).tag(index)
                        //                                }
                        //
                        //                            }.pickerStyle(SegmentedPickerStyle())
                        //                        }.padding(.horizontal)
                        //                        HStack {
                        //                            Text("Scale Movement: ")
                        //                            Slider(value: $scaleMovement, in: -3...10, step: 0.5)
                        //                            Text(String(format: "%.1f", scaleMovement))
                        //                        }.padding(.horizontal)
                        //                        HStack {
                        //                            Toggle("Guided Filter", isOn: $isToUpsampleDepth).onChange(of: isToUpsampleDepth) { _ in
                        //                                isToUpsampleDepth.toggle()
                        //                                arProvider.isToUpsampleDepth = isToUpsampleDepth
                        //                            }.frame(width: 160, height: 30)
                        //                            Toggle("Smooth", isOn: $isShowSmoothDepth).onChange(of: isShowSmoothDepth) { _ in
                        //                                isShowSmoothDepth.toggle()
                        //                                arProvider.isUseSmoothedDepthForUpsampling = isShowSmoothDepth
                        //                            }.frame(width: 160, height: 30)
                        //                            Spacer()
                        //                            Button(action: {
                        //                                isArPaused.toggle()
                        //                                isArPaused ? arProvider.pause() : arProvider.start()
                        //                            }) {
                        //                                Image(systemName: isArPaused ? "play.circle" : "pause.circle").resizable().frame(width: 30, height: 30)
                        //                            }
                        //                        }.padding(.horizontal)
                        
                        ScrollView(.horizontal) {
                            VStack() {
                                MetalTextureViewDepth(content: arProvider.depthContent, confSelection: $selectedConfidence)
                                    .zoomOnTapModifier(height: sizeH, width: sizeW, title: isToUpsampleDepth ? "Upscaled Depth" : "Depth")
                                MetalTextureViewColor(colorYContent: arProvider.colorYContent, colorCbCrContent: arProvider.colorCbCrContent).zoomOnTapModifier(height: sizeH, width: sizeW, title: "RGB")
                                //                                MetalTextureViewConfidence(content: arProvider.confidenceContent)
                                //                                    .zoomOnTapModifier(height: sizeH, width: sizeW, title: "Confidence")
                                //                                if isToUpsampleDepth {
                                //                                    VStack {
                                //                                        Text("Upscale Coefficients").foregroundColor(Color.red)
                                //                                        MetalTextureViewCoefs(content: arProvider.upscaledCoef).frame(maxWidth: sizeW,
                                //                                                                                                      maxHeight: sizeH,
                                //                                                                                                      alignment: .center)
                                //                                    }
                                //
                                //                                }
                                
                            }
                        }
                        Spacer()
                        Button("Save") {
                            UIImageWriteToSavedPhotosAlbum(arProvider.uiImageDepth, nil, nil, nil)
                            UIImageWriteToSavedPhotosAlbum(arProvider.uiImageColor, nil, nil, nil)
                            CVPixelBufferLockBaseAddress(arProvider.depthImage!, CVPixelBufferLockFlags(rawValue: 0))
                            let addr = CVPixelBufferGetBaseAddress(arProvider.depthImage!)
                            let height = CVPixelBufferGetHeight(arProvider.depthImage!)
                            let bpr = CVPixelBufferGetBytesPerRow(arProvider.depthImage!)
                            let depthBuffer = Data(bytes: addr!, count: (bpr*height))
//                            let timeStamp = Date(timeIntervalSince1970: (arProvider.timeStamp / 1000.0))
//                            let dateFormater = DateFormatter()
//                            dateFormater.dateFormat = "dd-MM-YY:HH:mm:ss"
//                            let fileName = dateFormater.string(from: timeStamp)
//                            print("time stamp")
//                            print(arProvider.timeStamp)
                            let fileName = "" + arProvider.timeStamp.description
                            let cameraIntrinsics = (0..<3).flatMap { x in (0..<3).map { y in arProvider.cameraIntrinsics[x][y] } }
                            //                            print("camera Intri")
                            //                            print(cameraIntrinsics)
                            let cameraTransform = (0..<4).flatMap { x in (0..<4).map { y in arProvider.cameraTransform[x][y] } }
//                            dateFormater.dateFormat = "HH:mm:ss"
//                            let exposureDuration = dateFormater.string(from: Date(timeIntervalSince1970: (arProvider.exposureDuration / 1000.0)))
                            let exposureDuration = "" + arProvider.exposureDuration.description
                            let exposureOffset = "" + arProvider.exposureOffset.description
                            //                            print("exposureOffset")
                            //                            print(exposureOffset)
                            //
                            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                
                                let intriURL = dir.appendingPathComponent(fileName+"_intri.txt")
                                let transURL = dir.appendingPathComponent(fileName+"_trans.txt")
                                //                                let RGBAURL = dir.appendingPathComponent(fileName+"_RGBA.txt")
                                //                                let depthURL = dir.appendingPathComponent(fileName+"_depth.txt")
                                let duraURL = dir.appendingPathComponent(fileName+"_dura.txt")
                                let offsetURL = dir.appendingPathComponent(fileName+"_offset.txt")
                                let depthBufferURL = dir.appendingPathComponent(fileName+"_depthBuffer.bin")
                                
                                //writing
                                do {
                                    try depthBuffer.write(to: depthBufferURL)
                                    try (cameraIntrinsics as NSArray).write(to: intriURL, atomically: false)
                                    try (cameraTransform as NSArray).write(to: transURL, atomically: false)
                                    //                                    try (arProvider.RGBAValues as NSArray).write(to: RGBAURL, atomically: false)
                                    //                                    try (arProvider.depthValues as NSArray).write(to: depthURL, atomically: false)
                                    try exposureDuration.write(to: duraURL, atomically: false, encoding: .utf8)
                                    try exposureOffset.write(to: offsetURL, atomically: false, encoding: .utf8)
                                }
                                catch {/* error handling here */}
                            }
                        }
                    }
                }.navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }
    struct MtkView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                MetalDepthView().previewDevice("iPad Pro (12.9-inch) (4th generation)")
                MetalDepthView().previewDevice("iPhone 11 Pro")
            }
        }
    }
}
