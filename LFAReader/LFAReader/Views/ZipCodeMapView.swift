import SwiftUI
import MapKit

/// Displays Columbus OH zip code areas colored by positive case density.
struct ZipCodeMapView: UIViewRepresentable {
    /// Per-zip data: { "43215": { "Positive L": 2, "Positive I": 1, "Positive L+I": 0 } }
    let zipData: [String: [String: Int]]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // Center on Columbus, OH
        let center = CLLocationCoordinate2D(latitude: 39.96, longitude: -82.99)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35))
        mapView.setRegion(region, animated: false)

        // Load and render polygons
        if let polygons = loadGeoJSON() {
            mapView.addOverlays(polygons)
        }

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(zipData: zipData)
    }

    // MARK: - GeoJSON Loading

    private func loadGeoJSON() -> [MKPolygon]? {
        guard let url = Bundle.main.url(forResource: "columbus_zips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            return nil
        }

        var polygons: [MKPolygon] = []

        for feature in features {
            guard let properties = feature["properties"] as? [String: Any],
                  let zip = properties["zip"] as? String,
                  let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String,
                  let coords = geometry["coordinates"] as? [Any] else {
                continue
            }

            let mkPolygons: [MKPolygon]
            if type == "Polygon", let rings = coords as? [[[Double]]] {
                mkPolygons = [polygonFromRings(rings, title: zip)]
            } else if type == "MultiPolygon", let multiRings = coords as? [[[[Double]]]] {
                mkPolygons = multiRings.map { polygonFromRings($0, title: zip) }
            } else {
                continue
            }

            polygons.append(contentsOf: mkPolygons)
        }

        return polygons
    }

    private func polygonFromRings(_ rings: [[[Double]]], title: String) -> MKPolygon {
        let outerRing = rings[0]
        var coordinates = outerRing.map {
            CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
        }

        let polygon: MKPolygon
        if rings.count > 1 {
            let interiors = rings[1...].map { ring -> MKPolygon in
                var interiorCoords = ring.map {
                    CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                }
                return MKPolygon(coordinates: &interiorCoords, count: interiorCoords.count)
            }
            polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count, interiorPolygons: interiors)
        } else {
            polygon = MKPolygon(coordinates: &coordinates, count: coordinates.count)
        }

        polygon.title = title
        return polygon
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        let zipData: [String: [String: Int]]

        /// 7-stop color scale from light gray to dark red
        private let colorScale: [UIColor] = [
            UIColor(red: 0.969, green: 0.969, blue: 0.969, alpha: 1), // #f7f7f7
            UIColor(red: 0.992, green: 0.839, blue: 0.808, alpha: 1), // #fdd6ce
            UIColor(red: 0.988, green: 0.682, blue: 0.624, alpha: 1), // #fcae9f
            UIColor(red: 0.984, green: 0.502, blue: 0.447, alpha: 1), // #fb8072
            UIColor(red: 0.878, green: 0.322, blue: 0.278, alpha: 1), // #e05247
            UIColor(red: 0.722, green: 0.161, blue: 0.161, alpha: 1), // #b82929
            UIColor(red: 0.600, green: 0.000, blue: 0.000, alpha: 1), // #990000
        ]

        private var maxTotal: Int = 1

        init(zipData: [String: [String: Int]]) {
            self.zipData = zipData
            self.maxTotal = max(1, zipData.values.map { $0.values.reduce(0, +) }.max() ?? 1)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolygonRenderer(polygon: polygon)
            let zip = polygon.title ?? ""
            let total = zipData[zip]?.values.reduce(0, +) ?? 0

            let ratio = Double(total) / Double(maxTotal)
            let idx = min(Int(round(ratio * 6)), 6)
            renderer.fillColor = colorScale[idx].withAlphaComponent(0.7)
            renderer.strokeColor = UIColor.darkGray.withAlphaComponent(0.5)
            renderer.lineWidth = 1

            return renderer
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {}
    }
}

/// Popup detail view for a selected zip code.
struct ZipCodeDetailView: View {
    let zip: String
    let data: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Zip: \(zip)")
                .font(.headline)

            ForEach(["Positive L", "Positive I", "Positive L+I"], id: \.self) { cat in
                HStack {
                    Circle()
                        .fill(catColor(cat))
                        .frame(width: 8, height: 8)
                    Text(cat)
                        .font(.caption)
                    Spacer()
                    Text("\(data[cat] ?? 0)")
                        .font(.caption.weight(.semibold))
                }
            }

            Divider()

            HStack {
                Text("Total Positive")
                    .font(.caption.weight(.bold))
                Spacer()
                Text("\(data.values.reduce(0, +))")
                    .font(.caption.weight(.bold))
            }
        }
        .padding()
        .frame(width: 180)
    }

    private func catColor(_ cat: String) -> Color {
        switch cat {
        case "Positive L": .red
        case "Positive I": .orange
        case "Positive L+I": .purple
        default: .gray
        }
    }
}
