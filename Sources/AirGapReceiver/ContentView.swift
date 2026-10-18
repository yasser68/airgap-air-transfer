import SwiftUI

public struct ContentView: View {
    @StateObject private var engine = ReconstructionEngine()
    @State private var showingShareSheet = false

    public init() {}

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.09, blue: 0.14) // Dark Navy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header Bar
                headerView

                if engine.isComplete {
                    successView
                } else {
                    scannerView
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let fileUrl = engine.savedFileURL {
                ShareSheet(items: [fileUrl])
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: {
                engine.reset()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("مستقبل البيانات البصري")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("AirGap Optical Receiver")
                    .font(.caption2)
                    .foregroundColor(Color.gray)
            }

            Spacer()

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .padding(10)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color(red: 0.11, green: 0.14, blue: 0.22))
    }

    // MARK: - Scanner View
    private var scannerView: some View {
        VStack(spacing: 16) {
            // Camera Viewfinder Box
            ZStack {
                CameraScannerView { code in
                    engine.processScannedCode(code)
                }
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(engine.totalChunks > 0 ? Color.green : Color.cyan, lineWidth: 2)
                )

                // Reticle corners & prompt
                VStack {
                    Spacer()
                    Text(engine.totalChunks > 0 ? "جاري التقاط الإطارات المتتابعة..." : "وجه الكاميرا نحو شاشة الحاسوب")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .padding(.bottom, 20)
                }

                if engine.isVerifying {
                    Color.black.opacity(0.8)
                        .cornerRadius(20)
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            .scaleEffect(1.6)
                        Text("جاري فك الضغط والتحقق من التجزئة...")
                            .foregroundColor(.white)
                            .font(.callout)
                            .fontWeight(.bold)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.0, contentMode: .fit)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Live Dashboard & Progress
            dashboardCard
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Spacer()
        }
    }

    // MARK: - Dashboard Card
    private var dashboardCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(engine.totalChunks > 0 ? "\(engine.receivedChunks.count) / \(engine.totalChunks) إطار" : "--")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)

                Spacer()

                Text(engine.totalChunks > 0 ? engine.fileName : "في انتظار أول إطار...")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(gradient: Gradient(colors: [.cyan, .green]), startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(engine.progress), height: 12)
                        .animation(.easeInOut(duration: 0.2), value: engine.progress)
                }
            }
            .frame(height: 12)

            // Visual Chunk Matrix (up to 60 blocks)
            if engine.totalChunks > 0 && engine.totalChunks <= 80 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 12), spacing: 4) {
                    ForEach(1...engine.totalChunks, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(engine.isChunkReceived(idx) ? Color.green : Color.white.opacity(0.15))
                            .frame(height: 14)
                    }
                }
                .padding(.top, 4)
            }

            if let err = engine.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(red: 0.11, green: 0.14, blue: 0.22))
        .cornerRadius(16)
    }

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }

            VStack(spacing: 6) {
                Text("تم استلام قاعدة البيانات بنجاح!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("تم فك الضغط والتحقق من سلامة التجزئة (SHA-256)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            VStack(spacing: 12) {
                infoRow(label: "اسم الملف:", value: engine.fileName)
                infoRow(label: "الحجم النهائي:", value: formatBytes(engine.origSize))
                infoRow(label: "عدد الإطارات:", value: "\(engine.totalChunks) إطار")
                infoRow(label: "حالة الأمان:", value: "مطابق وموثوق 100% ✅")
            }
            .padding()
            .background(Color(red: 0.11, green: 0.14, blue: 0.22))
            .cornerRadius(16)
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("مشاركة أو حفظ الملف")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.blue)
                    .cornerRadius(14)
                }

                Button(action: {
                    engine.reset()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.cyan)
            Spacer()
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.2f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}

// MARK: - ShareSheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
