import { Layout as AntLayout } from "antd";
import Navbar from "./Navbar";

const { Content } = AntLayout;

export default function Layout({ children }) {
  return (
    <AntLayout style={{ minHeight: "100vh" }}>
      <Navbar />
      <Content
        style={{
          padding: "2rem",
          maxWidth: 1200,
          width: "100%",
          margin: "0 auto",
        }}
      >
        {children}
      </Content>
    </AntLayout>
  );
}
