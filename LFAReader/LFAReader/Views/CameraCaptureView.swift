import SwiftUI
import AVFoundation

/// Full-screen camera interface for capturing test strip images.
struct CameraCaptureView: View {
    let onCaptured: (UIImage) -> Void

    @State private var cameraService = CameraService()
    @State private var isCapturing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if cameraService.permissionGranted {
                cameraContent
            } else {
                permissionDeniedContent
            }
        }
        .background(.black)
        .task {
            await cameraService.checkPermission()
            if cameraService.permissionGranted {
                cameraService.configureSession()
                cameraService.startSession()
            }
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }

    // MARK: - Camera content

    private var cameraContent: some View {
        ZStack {
            // Live preview
            CameraPreviewView(session: cameraService.captureSession)
                .ignoresSafeArea()

            // Scan guide overlay
            scanGuideOverlay

            // Bottom controls
            VStack {
                Spacer()
                controlBar
            }

            // Error message
            if let error = cameraService.error {
                VStack {
                    Text(error)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
    }

    private var scanGuideOverlay: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * 0.8
            let height = width * 0.4
            let centerY = geometry.size.height / 2 - 40

            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: width, height: height)
                .position(x: geometry.size.width / 2, y: centerY)

            Text("Position test strip here")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .position(x: geometry.size.width / 2, y: centerY + height / 2 + 24)
        }
    }

    private var controlBar: some View {
        HStack {
            // Cancel button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
            }

            Spacer()

            // Capture button
            Button {
                guard !isCapturing else { return }
                isCapturing = true
                Task {
                    do {
                        let image = try await cameraService.capturePhoto()
                        onCaptured(image)
                        dismiss()
                    } catch {
                        cameraService.error = error.localizedDescription
                    }
                    isCapturing = false
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(.white)
                        .frame(width: 58, height: 58)
                        .opacity(isCapturing ? 0.5 : 1)
                }
            }
            .disabled(isCapturing)

            Spacer()

            // Spacer for symmetry
            Color.clear.frame(width: 50, height: 50)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }

    // MARK: - Permission denied

    private var permissionDeniedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("Please allow camera access in Settings to capture test strip images.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.white)
            .padding(.top, 4)
        }
    }
}
