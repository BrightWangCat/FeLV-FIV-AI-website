import { useState, useEffect, useMemo } from "react";
import { Row, Col, Card, Statistic, Typography, Spin, Alert, Empty } from "antd";
import { Pie } from "@ant-design/charts";
import api from "../services/api";
import ZipCodeMap from "../components/ZipCodeMap";

const { Title, Text } = Typography;

// 4 种有效分类及其对应颜色
const CATEGORIES = ["Negative", "Positive L", "Positive I", "Positive L+I"];
const CATEGORY_COLORS = {
  "Negative": "#38a169",
  "Positive L": "#e53e3e",
  "Positive I": "#dd6b20",
  "Positive L+I": "#805ad5",
};

// 5 个维度的显示名称
const DIMENSION_LABELS = {
  species: "Species",
  age: "Age",
  sex: "Sex",
  breed: "Breed",
  zip_code: "Zip Code",
};

// 饼图配色方案，用于区分同一维度下不同值
const PIE_PALETTE = [
  "#2b6cb0", "#38a169", "#e53e3e", "#dd6b20", "#805ad5",
  "#d69e2e", "#319795", "#b83280", "#5a67d8", "#ed8936",
  "#4fd1c5", "#fc8181", "#90cdf4", "#fbd38d", "#c6f6d5",
];

export default function Statistics() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    fetchGlobalStats();
  }, []);

  const fetchGlobalStats = async () => {
    try {
      const res = await api.get("/api/stats/global");
      setData(res.data);
    } catch (err) {
      setError(err.response?.data?.detail || "Failed to load statistics");
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div style={{ textAlign: "center", padding: "4rem" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ textAlign: "center", padding: "4rem" }}>
        <Alert
          type="error"
          message={error}
          showIcon
          style={{ maxWidth: 400, margin: "0 auto" }}
        />
      </div>
    );
  }

  if (!data || data.total === 0) {
    return (
      <div style={{ maxWidth: 1200, margin: "0 auto" }}>
        <Title level={3} style={{ color: "#1a365d", marginBottom: 24 }}>
          Global Test Statistics
        </Title>
        <Empty description="No test results with patient information available." />
      </div>
    );
  }

  return (
    <div style={{ maxWidth: 1200, margin: "0 auto" }}>
      {/* Page Header */}
      <Title level={3} style={{ color: "#1a365d", marginBottom: 8 }}>
        Global Test Statistics
      </Title>
      <Text type="secondary" style={{ display: "block", marginBottom: 24 }}>
        Aggregated results from all users' tests with patient information
      </Text>

      {/* Overview Cards */}
      <Row gutter={[16, 16]} style={{ marginBottom: 32 }}>
        <Col xs={12} sm={8} md={4}>
          <Card>
            <Statistic title="Total Samples" value={data.total} />
          </Card>
        </Col>
        {CATEGORIES.map((cat) => (
          <Col xs={12} sm={8} md={5} key={cat}>
            <Card>
              <Statistic
                title={cat}
                value={data.category_totals[cat] || 0}
                valueStyle={{ color: CATEGORY_COLORS[cat] }}
              />
            </Card>
          </Col>
        ))}
      </Row>

      {/* Per-dimension sections: each with pie charts */}
      {Object.entries(DIMENSION_LABELS).map(([dimKey, dimLabel]) => (
        <DimensionSection
          key={dimKey}
          dimensionKey={dimKey}
          dimensionLabel={dimLabel}
          dimensionData={data.dimensions[dimKey]}
        />
      ))}

      {/* Zip Code Map */}
      <ZipCodeMapSection zipDimensionData={data.dimensions.zip_code} />
    </div>
  );
}

// Map section: aggregate zip_code data into { zip: { "Positive L": n, ... } } format
function ZipCodeMapSection({ zipDimensionData }) {
  const zipData = useMemo(() => {
    if (!zipDimensionData) return {};
    const result = {};
    // zipDimensionData format: { "Positive L": { "43215": 2, ... }, "Positive I": {...}, ... }
    for (const cat of ["Positive L", "Positive I", "Positive L+I"]) {
      const dist = zipDimensionData[cat] || {};
      for (const [zip, count] of Object.entries(dist)) {
        if (!result[zip]) {
          result[zip] = { "Positive L": 0, "Positive I": 0, "Positive L+I": 0 };
        }
        result[zip][cat] = count;
      }
    }
    return result;
  }, [zipDimensionData]);

  return (
    <div style={{ marginBottom: 32 }}>
      <Title level={4} style={{ color: "#1a365d", marginBottom: 16 }}>
        Geographic Distribution (Columbus, OH)
      </Title>
      <Text type="secondary" style={{ display: "block", marginBottom: 16 }}>
        Click on a zip code area to view positive case details
      </Text>
      <ZipCodeMap zipData={zipData} />
    </div>
  );
}

// Pie charts only show positive categories (exclude Negative)
const PIE_CATEGORIES = CATEGORIES.filter((cat) => cat !== "Negative");

// A section for one dimension, containing 3 pie charts
function DimensionSection({ dimensionKey, dimensionLabel, dimensionData }) {
  if (!dimensionData) return null;

  // Check if this dimension has any data at all
  const hasData = PIE_CATEGORIES.some(
    (cat) => dimensionData[cat] && Object.keys(dimensionData[cat]).length > 0
  );

  if (!hasData) {
    return (
      <div style={{ marginBottom: 32 }}>
        <Title level={4} style={{ color: "#1a365d", marginBottom: 16 }}>
          {dimensionLabel}
        </Title>
        <Empty
          description={`No ${dimensionLabel.toLowerCase()} data available`}
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        />
      </div>
    );
  }

  return (
    <div style={{ marginBottom: 32 }}>
      <Title level={4} style={{ color: "#1a365d", marginBottom: 16 }}>
        {dimensionLabel}
      </Title>
      <Row gutter={[16, 16]}>
        {PIE_CATEGORIES.map((cat) => {
          const dist = dimensionData[cat] || {};
          const entries = Object.entries(dist).sort((a, b) => b[1] - a[1]);
          const total = entries.reduce((sum, [, count]) => sum + count, 0);

          return (
            <Col xs={24} sm={12} md={8} key={cat}>
              <Card
                title={
                  <span style={{ color: CATEGORY_COLORS[cat], fontWeight: 600 }}>
                    {cat}
                    <span style={{ color: "#718096", fontWeight: 400, marginLeft: 8, fontSize: 13 }}>
                      (n={total})
                    </span>
                  </span>
                }
                size="small"
                styles={{ body: { padding: "12px 16px" } }}
              >
                {entries.length === 0 ? (
                  <div style={{ textAlign: "center", padding: "20px 0", color: "#a0aec0" }}>
                    No data
                  </div>
                ) : (
                  <CategoryPieChart entries={entries} total={total} />
                )}
              </Card>
            </Col>
          );
        })}
      </Row>
    </div>
  );
}

// Single pie chart for one category within one dimension
function CategoryPieChart({ entries, total }) {
  const chartData = entries.map(([label, count]) => ({
    type: label,
    value: count,
  }));

  const config = {
    data: chartData,
    angleField: "value",
    colorField: "type",
    color: PIE_PALETTE,
    radius: 0.85,
    innerRadius: 0.55,
    height: 240,
    label: {
      text: (d) => {
        const pct = ((d.value / total) * 100).toFixed(1);
        // Only show label if percentage is large enough to be readable
        return pct >= 5 ? `${pct}%` : "";
      },
      style: { fontSize: 11, fontWeight: 500 },
    },
    legend: {
      color: {
        position: "bottom",
        layout: { justifyContent: "center" },
        itemLabelFontSize: 11,
        maxRows: 3,
      },
    },
    tooltip: {
      title: "type",
      items: [
        {
          field: "value",
          name: "Count",
        },
      ],
    },
    // Disable animation for faster rendering
    animate: false,
  };

  return <Pie {...config} />;
}
