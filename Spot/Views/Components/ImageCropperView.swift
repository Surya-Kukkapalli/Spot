import SwiftUI
import UIKit

struct ImageCropperView: View {
    let sourceImage: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let cropSize: CGFloat = 300
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Move and Scale")
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    ZStack {
                        // Image container
                        Image(uiImage: sourceImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { value in
                                            lastOffset = offset
                                        },
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                        }
                                        .onEnded { value in
                                            lastScale = scale
                                        }
                                )
                            )
                        
                        // Circular mask
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: cropSize, height: cropSize)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
                    
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundColor(.white)
                        .padding()
                        
                        Spacer()
                        
                        Button("Choose") {
                            let croppedImage = cropImage(sourceImage: sourceImage,
                                                       scale: scale,
                                                       offset: offset,
                                                       size: geometry.size,
                                                       cropSize: cropSize)
                            onCrop(croppedImage)
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                }
            }
        }
    }
    
    private func cropImage(sourceImage: UIImage, scale: CGFloat, offset: CGSize, size: CGSize, cropSize: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize, height: cropSize))
        
        let croppedImage = renderer.image { context in
            let drawRect = CGRect(x: 0, y: 0, width: cropSize, height: cropSize)
            context.cgContext.addEllipse(in: drawRect)
            context.cgContext.clip()
            
            // Calculate the scaled image size
            let aspectRatio = sourceImage.size.width / sourceImage.size.height
            let scaledWidth = size.width * scale
            let scaledHeight = scaledWidth / aspectRatio
            
            // Calculate drawing coordinates
            let drawX = (cropSize - scaledWidth) / 2 + offset.width
            let drawY = (cropSize - scaledHeight) / 2 + offset.height
            
            sourceImage.draw(in: CGRect(x: drawX, y: drawY, width: scaledWidth, height: scaledHeight))
        }
        
        return croppedImage
    }
} 