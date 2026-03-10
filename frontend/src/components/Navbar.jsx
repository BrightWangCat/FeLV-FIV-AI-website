import { Link, useNavigate, useLocation } from "react-router-dom";
import { Layout, Menu, Dropdown, Typography } from "antd";
import {
  PlusCircleOutlined,
  HistoryOutlined,
  UserOutlined,
  LogoutOutlined,
  TeamOutlined,
} from "@ant-design/icons";
import { useAuth } from "../context/AuthContext";

const { Header } = Layout;
const { Text } = Typography;

// Map pathname to menu key
const pathToKey = {
  "/upload": "upload",
  "/history": "history",
  "/results": "results",
  "/stats": "stats",
  "/users": "users",
};

export default function Navbar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  if (!user) return null;

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  // Determine active menu key from current path
  const currentKey = pathToKey[location.pathname] || "";

  const menuItems = [
    {
      key: "upload",
      icon: <PlusCircleOutlined />,
      label: <Link to="/upload">New Test</Link>,
    },
    {
      key: "history",
      icon: <HistoryOutlined />,
      label: <Link to="/history">Results</Link>,
    },
    ...(user.is_admin
      ? [
          {
            key: "users",
            icon: <TeamOutlined />,
            label: <Link to="/users">Users</Link>,
          },
        ]
      : []),
  ];

  const userMenuItems = [
    {
      key: "logout",
      icon: <LogoutOutlined />,
      label: "Log out",
      onClick: handleLogout,
    },
  ];

  return (
    <Header
      style={{
        background: "#1a365d",
        display: "flex",
        alignItems: "center",
        padding: "0 24px",
        height: 56,
        lineHeight: "56px",
      }}
    >
      <Link
        to="/upload"
        style={{
          color: "#fff",
          fontSize: "1.125rem",
          fontWeight: 700,
          marginRight: 40,
          whiteSpace: "nowrap",
          textDecoration: "none",
        }}
      >
        FeLV/FIV LFA Reader
      </Link>

      <Menu
        mode="horizontal"
        selectedKeys={[currentKey]}
        items={menuItems}
        style={{
          background: "transparent",
          borderBottom: "none",
          flex: 1,
          minWidth: 0,
          lineHeight: "56px",
        }}
        theme="dark"
      />

      <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            cursor: "pointer",
            color: "#bee3f8",
            whiteSpace: "nowrap",
          }}
        >
          <UserOutlined />
          <Text style={{ color: "#bee3f8", fontSize: "0.875rem" }}>
            {user.username}
          </Text>
        </div>
      </Dropdown>
    </Header>
  );
}
