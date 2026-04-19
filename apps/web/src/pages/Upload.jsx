import { useState, useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import {
  Typography,
  Upload,
  Steps,
  Progress,
  Alert,
  Radio,
  Select,
  Form,
  Input,
  Result,
  Button,
  App,
} from "antd";
import {
  InboxOutlined,
  CameraOutlined,
} from "@ant-design/icons";
import { uploadSingle } from "../services/api";

const { Title, Text } = Typography;
const { Dragger } = Upload;

const ALLOWED_TYPES = ["image/jpeg", "image/png"];
const MAX_SIZE = 20 * 1024 * 1024; // 20MB

export default function UploadPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { message } = App.useApp();

  const [step, setStep] = useState(0);

  // Step 1: file
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState(null);

  // Step 2: patient info
  const [shareInfo, setShareInfo] = useState(null);
  const [species, setSpecies] = useState("");
  const [age, setAge] = useState("");
  const [sex, setSex] = useState("");
  const [breed, setBreed] = useState("");
  const [zipCode, setZipCode] = useState("");

  // Submission
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);

  // 从相机页面返回时,读取 sessionStorage 中的拍摄图片
  useEffect(() => {
    if (location.state?.fromCamera) {
      const dataUrl = sessionStorage.getItem("capturedImage");
      if (dataUrl) {
        sessionStorage.removeItem("capturedImage");
        fetch(dataUrl)
          .then((res) => res.blob())
          .then((blob) => {
            const capturedFile = new File([blob], `capture_${Date.now()}.jpg`, {
              type: "image/jpeg",
            });
            setFile(capturedFile);
            setPreview(URL.createObjectURL(capturedFile));
            setStep(1);
          });
      }
      window.history.replaceState({}, "");
    }
  }, [location.state]);

  const selectFile = (f) => {
    if (!ALLOWED_TYPES.includes(f.type)) {
      message.error(`${f.name}: unsupported format. Only JPG/PNG allowed.`);
      return;
    }
    if (f.size > MAX_SIZE) {
      message.error(`${f.name}: exceeds 20MB limit.`);
      return;
    }
    setError("");
    setFile(f);
    setPreview(URL.createObjectURL(f));
  };

  const handleSubmit = async () => {
    if (!file) return;
    setError("");
    setUploading(true);
    setProgress(0);

    const formData = new FormData();
    formData.append("file", file);
    formData.append("share_info", shareInfo ? "true" : "false");

    if (shareInfo) {
      if (species) formData.append("species", species);
      if (age) formData.append("age", age);
      if (sex) formData.append("sex", sex);
      if (breed) formData.append("breed", breed);
      if (zipCode) formData.append("zip_code", zipCode);
    }

    try {
      const res = await uploadSingle(formData, (e) => {
        if (e.total) {
          setProgress(Math.round((e.loaded / e.total) * 100));
        }
      });
      setResult(res.data);
    } catch (err) {
      setError(err.response?.data?.detail || "Upload failed");
    } finally {
      setUploading(false);
    }
  };

  if (result) {
    return (
      <div style={{ maxWidth: 720, margin: "0 auto" }}>
        <Result
          status="success"
          title="Upload Successful"
          subTitle={
            <>
              <div>Image ID: {result.id}</div>
              {result.patient_info && <div>Patient info saved.</div>}
            </>
          }
          extra={[
            <Button
              type="primary"
              key="view"
              onClick={() => navigate(`/results?image=${result.id}`)}
            >
              View Result
            </Button>,
          ]}
        />
      </div>
    );
  }

  return (
    <div style={{ maxWidth: 720, margin: "0 auto" }}>
      <Title level={3} style={{ color: "#1a365d", marginBottom: 8 }}>
        New Test
      </Title>
      <Text
        type="secondary"
        style={{ display: "block", marginBottom: 24, lineHeight: 1.5 }}
      >
        Upload a single FeLV/FIV lateral flow assay cassette image.
        Supported formats: JPG, PNG. Maximum 20MB.
      </Text>

      <Steps
        current={step}
        items={[
          { title: "Image" },
          { title: "Patient Info" },
          { title: "GPS & Submit" },
        ]}
        style={{ marginBottom: 32 }}
      />

      {error && (
        <Alert
          type="error"
          message={error}
          showIcon
          closable
          onClose={() => setError("")}
          style={{ marginBottom: 16 }}
        />
      )}

      {/* Step 1: Select Image */}
      {step === 0 && (
        <>
          <Dragger
            accept=".jpg,.jpeg,.png"
            maxCount={1}
            showUploadList={false}
            beforeUpload={(f) => {
              selectFile(f);
              return false;
            }}
            style={{ marginBottom: 16 }}
          >
            <p className="ant-upload-drag-icon">
              <InboxOutlined />
            </p>
            <p className="ant-upload-text">
              Drag and drop an image here, or click to select
            </p>
            <p className="ant-upload-hint">
              Supported: JPG, PNG. Max 20MB.
            </p>
          </Dragger>

          <div
            onClick={() => navigate("/camera")}
            style={{ position: "relative", marginBottom: 16, cursor: "pointer" }}
          >
            <Dragger
              showUploadList={false}
              beforeUpload={() => false}
              openFileDialogOnClick={false}
              style={{ pointerEvents: "none" }}
            >
              <p className="ant-upload-drag-icon">
                <CameraOutlined />
              </p>
              <p className="ant-upload-text">Tap to capture with camera</p>
              <p className="ant-upload-hint">
                Use your device camera to take a photo
              </p>
            </Dragger>
          </div>

          {preview && (
            <div style={{ textAlign: "center", marginBottom: 16 }}>
              <img
                src={preview}
                alt="Preview"
                style={{
                  maxWidth: "100%",
                  maxHeight: 300,
                  borderRadius: 8,
                  border: "1px solid #e2e8f0",
                  objectFit: "contain",
                }}
              />
              <Text
                type="secondary"
                style={{ display: "block", marginTop: 8, fontSize: 13 }}
              >
                {file.name}
              </Text>
            </div>
          )}

          <div style={{ display: "flex", justifyContent: "flex-end", marginTop: 24 }}>
            <Button
              type="primary"
              size="large"
              disabled={!file}
              onClick={() => setStep(1)}
            >
              Next
            </Button>
          </div>
        </>
      )}

      {/* Step 2: Patient Information */}
      {step === 1 && (
        <>
          <Title level={5} style={{ color: "#1a365d", marginBottom: 16 }}>
            Would you like to share some confidential information regarding the
            patient?
          </Title>

          <Radio.Group
            value={shareInfo}
            onChange={(e) => setShareInfo(e.target.value)}
            optionType="button"
            buttonStyle="solid"
            size="large"
            style={{ marginBottom: 20 }}
          >
            <Radio.Button value={true}>Yes</Radio.Button>
            <Radio.Button value={false}>No</Radio.Button>
          </Radio.Group>

          {shareInfo && (
            <Form layout="vertical" style={{ marginBottom: 8 }}>
              <Form.Item label="Species">
                <Select
                  value={species || undefined}
                  onChange={setSpecies}
                  placeholder="Select species"
                  options={[
                    { value: "Dog", label: "Dog" },
                    { value: "Cat", label: "Cat" },
                  ]}
                  allowClear
                />
              </Form.Item>
              <Form.Item label="Age (years)">
                <Input
                  type="number"
                  min={0}
                  value={age}
                  onChange={(e) => setAge(e.target.value.replace(/[^0-9]/g, ""))}
                  placeholder="e.g. 3"
                  suffix="years"
                />
              </Form.Item>
              <Form.Item label="Sex">
                <Select
                  value={sex || undefined}
                  onChange={setSex}
                  placeholder="Select sex"
                  options={[
                    { value: "M", label: "M" },
                    { value: "F", label: "F" },
                    { value: "CM", label: "CM" },
                    { value: "SF", label: "SF" },
                  ]}
                  allowClear
                />
              </Form.Item>
              <Form.Item label="Breed">
                <Input
                  value={breed}
                  onChange={(e) => setBreed(e.target.value)}
                  placeholder="Breed"
                />
              </Form.Item>
              <Form.Item label="Zip Code">
                <Input
                  value={zipCode}
                  onChange={(e) => setZipCode(e.target.value)}
                  placeholder="Zip code"
                />
              </Form.Item>
            </Form>
          )}

          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 24 }}>
            <Button size="large" onClick={() => setStep(0)}>
              Back
            </Button>
            <Button
              type="primary"
              size="large"
              disabled={shareInfo === null}
              onClick={() => setStep(2)}
            >
              Next
            </Button>
          </div>
        </>
      )}

      {/* Step 3: GPS Consent (placeholder) + Submit */}
      {step === 2 && (
        <>
          <Title level={5} style={{ color: "#1a365d", marginBottom: 16 }}>
            Would you like to share your GPS location?
          </Title>

          <Alert
            type="info"
            message="This feature is coming soon."
            showIcon
            style={{ marginBottom: 24 }}
          />

          {uploading && (
            <Progress
              percent={progress}
              status="active"
              style={{ marginBottom: 16 }}
            />
          )}

          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 24 }}>
            <Button size="large" onClick={() => setStep(1)} disabled={uploading}>
              Back
            </Button>
            <Button
              type="primary"
              size="large"
              loading={uploading}
              onClick={handleSubmit}
            >
              {uploading ? "Uploading..." : "Submit"}
            </Button>
          </div>
        </>
      )}
    </div>
  );
}
