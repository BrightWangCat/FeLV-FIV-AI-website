import { useMemo } from "react";
import { MapContainer, TileLayer, GeoJSON } from "react-leaflet";
import { Typography } from "antd";
import "leaflet/dist/leaflet.css";
import columbusGeo from "../data/columbus_zips.json";

const { Text } = Typography;

// Columbus, OH center coordinates
const COLUMBUS_CENTER = [39.96, -82.99];
const DEFAULT_ZOOM = 11;

// Color scale: white (0) to dark red (max positive count)
const COLOR_STOPS = [
  "#f7f7f7", // 0
  "#fdd49e", // low
  "#fdbb84",
  "#fc8d59",
  "#ef6548",
  "#d7301f",
  "#990000", // high
];

function getColor(value, maxValue) {
  if (!value || value === 0) return COLOR_STOPS[0];
  if (maxValue === 0) return COLOR_STOPS[0];
  // Normalize to 0-1, then pick color
  const ratio = Math.min(value / maxValue, 1);
  const idx = Math.round(ratio * (COLOR_STOPS.length - 1));
  return COLOR_STOPS[idx];
}

export default function ZipCodeMap({ zipData }) {
  // zipData format: { "43215": { "Positive L": 2, "Positive I": 1, "Positive L+I": 0 }, ... }

  // Calculate total positives per zip and find max for color scale
  const { zipTotals, maxTotal } = useMemo(() => {
    const totals = {};
    let max = 0;
    Object.entries(zipData || {}).forEach(([zip, cats]) => {
      const total =
        (cats["Positive L"] || 0) +
        (cats["Positive I"] || 0) +
        (cats["Positive L+I"] || 0);
      totals[zip] = total;
      if (total > max) max = total;
    });
    return { zipTotals: totals, maxTotal: max };
  }, [zipData]);

  // Style each zip code polygon based on positive count
  const style = (feature) => {
    const zip = feature.properties.zip;
    const total = zipTotals[zip] || 0;
    return {
      fillColor: getColor(total, maxTotal),
      weight: 1.5,
      opacity: 1,
      color: "#666",
      fillOpacity: 0.7,
    };
  };

  // Highlight on hover, show popup on click
  const onEachFeature = (feature, layer) => {
    const zip = feature.properties.zip;
    const cats = zipData?.[zip] || {};
    const posL = cats["Positive L"] || 0;
    const posI = cats["Positive I"] || 0;
    const posLI = cats["Positive L+I"] || 0;
    const total = posL + posI + posLI;

    // Popup content
    const popupContent = `
      <div style="min-width: 140px; font-family: Inter, sans-serif;">
        <div style="font-weight: 700; font-size: 14px; margin-bottom: 6px; color: #1a365d;">
          Zip Code: ${zip}
        </div>
        <div style="font-size: 13px; line-height: 1.8;">
          <span style="color: #e53e3e; font-weight: 600;">Positive L:</span> ${posL}<br/>
          <span style="color: #dd6b20; font-weight: 600;">Positive I:</span> ${posI}<br/>
          <span style="color: #805ad5; font-weight: 600;">Positive L+I:</span> ${posLI}<br/>
          <div style="border-top: 1px solid #e2e8f0; margin-top: 4px; padding-top: 4px; font-weight: 600;">
            Total Positive: ${total}
          </div>
        </div>
      </div>
    `;

    layer.bindPopup(popupContent);

    // Hover highlight effect
    layer.on({
      mouseover: (e) => {
        const target = e.target;
        target.setStyle({
          weight: 3,
          color: "#1a365d",
          fillOpacity: 0.85,
        });
        target.bringToFront();
      },
      mouseout: (e) => {
        e.target.setStyle(style(feature));
      },
    });
  };

  return (
    <div>
      <div
        style={{
          borderRadius: 8,
          overflow: "hidden",
          border: "1px solid #e2e8f0",
        }}
      >
        <MapContainer
          center={COLUMBUS_CENTER}
          zoom={DEFAULT_ZOOM}
          style={{ height: 500, width: "100%" }}
          scrollWheelZoom={true}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <GeoJSON
            data={columbusGeo}
            style={style}
            onEachFeature={onEachFeature}
          />
        </MapContainer>
      </div>

      {/* Color legend */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          marginTop: 12,
          justifyContent: "center",
        }}
      >
        <Text type="secondary" style={{ fontSize: 12 }}>0</Text>
        <div
          style={{
            display: "flex",
            height: 14,
            borderRadius: 3,
            overflow: "hidden",
            border: "1px solid #e2e8f0",
          }}
        >
          {COLOR_STOPS.map((color, i) => (
            <div
              key={i}
              style={{ width: 30, height: "100%", background: color }}
            />
          ))}
        </div>
        <Text type="secondary" style={{ fontSize: 12 }}>
          {maxTotal > 0 ? maxTotal : "max"}
        </Text>
        <Text type="secondary" style={{ fontSize: 12, marginLeft: 4 }}>
          (total positive cases)
        </Text>
      </div>
    </div>
  );
}
