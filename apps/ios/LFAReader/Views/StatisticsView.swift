import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var viewModel = StatisticsViewModel()

    /// Only positive categories get pie charts (matching web app)
    private let pieCategories = ["Positive L", "Positive I", "Positive L+I"]

    /// Dimensions that get pie charts (zip_code uses map instead)
    private let pieDimensions = ["species", "age", "sex", "breed"]

    /// Palette for pie slices within a single chart
    private let slicePalette: [Color] = [
        .blue, .orange, .green, .red, .purple,
        .cyan, .pink, .yellow, .mint, .indigo,
        .brown, .teal, .gray, Color(.systemRed), Color(.systemTeal),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.stats == nil {
                    ProgressView("Loading statistics...")
                } else if let stats = viewModel.stats {
                    statsContent(stats)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ContentUnavailableView("No Data", systemImage: "chart.pie", description: Text("No statistics available yet"))
                }
            }
            .navigationTitle("Statistics")
            .task {
                await viewModel.loadStats()
            }
            .refreshable {
                await viewModel.loadStats()
            }
        }
    }

    // MARK: - Main content

    private func statsContent(_ stats: GlobalStats) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                overviewSection(stats)
                distributionChart(stats)
                dimensionSections(stats)
                zipCodeSection(stats)
            }
            .padding()
        }
    }

    // MARK: - Overview cards

    private func overviewSection(_ stats: GlobalStats) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flask")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("Total Samples")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(stats.total)")
                    .font(.title2.weight(.bold))
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(GlobalStats.displayCategories, id: \.self) { category in
                    let count = stats.categoryTotals[category] ?? 0
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("\(count)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(categoryColor(category))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Overall distribution donut

    private func distributionChart(_ stats: GlobalStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Result Distribution")
                .font(.headline)

            Chart(GlobalStats.displayCategories, id: \.self) { category in
                let count = stats.categoryTotals[category] ?? 0
                SectorMark(
                    angle: .value("Count", count),
                    innerRadius: .ratio(0.55),
                    angularInset: 1.5
                )
                .foregroundStyle(categoryColor(category))
                .annotation(position: .overlay) {
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 220)

            // Legend
            HStack(spacing: 16) {
                ForEach(GlobalStats.displayCategories, id: \.self) { category in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(categoryColor(category))
                            .frame(width: 8, height: 8)
                        Text(category)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Dimension sections (per-category pie charts)

    private func dimensionSections(_ stats: GlobalStats) -> some View {
        ForEach(pieDimensions, id: \.self) { key in
            if let dimData = stats.dimensions[key], !isDimensionEmpty(dimData) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(GlobalStats.dimensionTitles[key] ?? key)
                        .font(.headline)

                    ForEach(pieCategories, id: \.self) { category in
                        if let valueCounts = dimData[category], !valueCounts.isEmpty {
                            categoryPieCard(category: category, data: valueCounts)
                        }
                    }
                }
            }
        }
    }

    private func categoryPieCard(category: String, data: [String: Int]) -> some View {
        let total = data.values.reduce(0, +)
        let sorted = data.sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(categoryColor(category))
                Text("(n=\(total))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(Array(sorted.enumerated()), id: \.element.key) { index, item in
                SectorMark(
                    angle: .value("Count", item.value),
                    innerRadius: .ratio(0.55),
                    angularInset: 0.5
                )
                .foregroundStyle(slicePalette[index % slicePalette.count])
                .annotation(position: .overlay) {
                    let pct = Double(item.value) / Double(max(total, 1)) * 100
                    if pct >= 5 {
                        Text(String(format: "%.0f%%", pct))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 200)

            // Legend
            FlowLayout(spacing: 8) {
                ForEach(Array(sorted.enumerated()), id: \.element.key) { index, item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(slicePalette[index % slicePalette.count])
                            .frame(width: 8, height: 8)
                        Text(item.key)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Zip Code section

    @ViewBuilder
    private func zipCodeSection(_ stats: GlobalStats) -> some View {
        if let zipData = stats.dimensions["zip_code"], !isDimensionEmpty(zipData) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Zip Code")
                    .font(.headline)

                let mapData = transformZipData(zipData)
                ZipCodeMapView(zipData: mapData)
                    .frame(height: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    /// Transform dimension data into per-zip-code format for the map.
    /// Input:  { "Positive L": { "43215": 2 }, "Positive I": { "43215": 1 } }
    /// Output: { "43215": { "Positive L": 2, "Positive I": 1, "Positive L+I": 0 } }
    private func transformZipData(_ data: [String: [String: Int]]) -> [String: [String: Int]] {
        var result: [String: [String: Int]] = [:]
        for category in pieCategories {
            if let valueCounts = data[category] {
                for (zip, count) in valueCounts {
                    result[zip, default: [:]][category] = count
                }
            }
        }
        // Ensure all categories present per zip
        for zip in result.keys {
            for category in pieCategories {
                if result[zip]?[category] == nil {
                    result[zip]?[category] = 0
                }
            }
        }
        return result
    }

    // MARK: - Helpers

    private func isDimensionEmpty(_ data: [String: [String: Int]]) -> Bool {
        data.values.allSatisfy { $0.isEmpty }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "Negative": .green
        case "Positive L": .red
        case "Positive I": .orange
        case "Positive L+I": .purple
        default: .gray
        }
    }
}

// MARK: - Flow Layout for legends

/// Simple wrapping layout for legend items.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    StatisticsView()
}
