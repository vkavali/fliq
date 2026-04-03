import AVFoundation
import SwiftUI

struct QRScannerSheet: View {
    let onCode: (String) -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            QRScannerCameraView(onCode: onCode, onError: onError)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                Text("Scan QR")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Point the camera at a Fliq QR code or payment link QR.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 24)
            .padding(.horizontal, 20)

            Button(action: onCancel) {
                Text("Close")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .background(Color.black)
    }
}

private struct QRScannerCameraView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCode = onCode
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.onCode = onCode
        uiViewController.onError = onError
    }
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.fliq.ios.qrscanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var didFinishScanning = false
    private var hasReportedError = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestCameraAccessIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didFinishScanning,
              let metadataObject = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              metadataObject.type == .qr,
              let value = metadataObject.stringValue,
              !value.isEmpty else {
            return
        }

        didFinishScanning = true
        stopSession()
        onCode?(value)
    }

    private func requestCameraAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureAndStartSessionIfNeeded()
                    } else {
                        self.reportError("Camera access is required to scan QR codes.")
                    }
                }
            }
        case .denied, .restricted:
            reportError("Camera access is required to scan QR codes. Enable it in Settings.")
        @unknown default:
            reportError("Camera access is not available on this device.")
        }
    }

    private func configureAndStartSessionIfNeeded() {
        if isConfigured {
            startSession()
            return
        }

        do {
            try configureSession()
            startSession()
        } catch {
            reportError(error.localizedDescription)
        }
    }

    private func configureSession() throws {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            throw ScannerError.unavailable
        }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard captureSession.canAddInput(videoInput) else {
            throw ScannerError.configurationFailed
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            throw ScannerError.configurationFailed
        }
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
        isConfigured = true
    }

    private func startSession() {
        guard !captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    private func stopSession() {
        guard captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    private func reportError(_ message: String) {
        guard !hasReportedError else { return }
        hasReportedError = true
        onError?(message)
    }
}

private enum ScannerError: LocalizedError {
    case unavailable
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Camera capture is not available on this device."
        case .configurationFailed:
            return "Unable to configure the camera for QR scanning."
        }
    }
}
