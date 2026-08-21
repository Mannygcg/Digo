import SwiftUI

struct HUDView: View {
    @ObservedObject var viewModel: HUDViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundStyle(.red)
            Text(viewModel.text.isEmpty ? "Listening…" : viewModel.text)
                .font(.system(size: 14))
                .lineLimit(2)
                .frame(maxWidth: 360, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .frame(width: 400, height: 60)
    }
}
