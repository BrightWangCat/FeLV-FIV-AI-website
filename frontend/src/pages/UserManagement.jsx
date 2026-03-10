import { useState, useEffect } from "react";
import {
  Table,
  Tag,
  Button,
  Space,
  Typography,
  Popconfirm,
  App,
  Spin,
  Alert,
} from "antd";
import {
  CrownOutlined,
  DeleteOutlined,
  UserOutlined,
} from "@ant-design/icons";
import api from "../services/api";
import { useAuth } from "../context/AuthContext";

const { Title } = Typography;

export default function UserManagement() {
  const { user: currentUser } = useAuth();
  const { message } = App.useApp();

  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionLoading, setActionLoading] = useState({});

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      const res = await api.get("/api/users/");
      setUsers(res.data);
    } catch (err) {
      setError(err.response?.data?.detail || "Failed to load users");
    } finally {
      setLoading(false);
    }
  };

  const handleToggleAdmin = async (userId) => {
    setActionLoading((prev) => ({ ...prev, [userId]: true }));
    try {
      const res = await api.put(`/api/users/${userId}/admin`);
      setUsers((prev) =>
        prev.map((u) => (u.id === userId ? res.data : u))
      );
      message.success(
        res.data.is_admin ? "Admin privileges granted" : "Admin privileges revoked"
      );
    } catch (err) {
      message.error(err.response?.data?.detail || "Failed to update user");
    } finally {
      setActionLoading((prev) => ({ ...prev, [userId]: false }));
    }
  };

  const handleDelete = async (userId) => {
    setActionLoading((prev) => ({ ...prev, [`del_${userId}`]: true }));
    try {
      await api.delete(`/api/users/${userId}`);
      setUsers((prev) => prev.filter((u) => u.id !== userId));
      message.success("User deleted");
    } catch (err) {
      message.error(err.response?.data?.detail || "Failed to delete user");
    } finally {
      setActionLoading((prev) => ({ ...prev, [`del_${userId}`]: false }));
    }
  };

  const columns = [
    {
      title: "ID",
      dataIndex: "id",
      key: "id",
      width: 60,
    },
    {
      title: "Username",
      dataIndex: "username",
      key: "username",
    },
    {
      title: "Email",
      dataIndex: "email",
      key: "email",
    },
    {
      title: "Role",
      key: "role",
      width: 100,
      render: (_, record) =>
        record.is_admin ? (
          <Tag icon={<CrownOutlined />} color="gold">Admin</Tag>
        ) : (
          <Tag icon={<UserOutlined />} color="default">User</Tag>
        ),
    },
    {
      title: "Registered",
      dataIndex: "created_at",
      key: "created_at",
      render: (val) => new Date(val).toLocaleDateString(),
    },
    {
      title: "Actions",
      key: "actions",
      width: 220,
      render: (_, record) => {
        const isSelf = record.id === currentUser?.id;
        return (
          <Space>
            <Button
              size="small"
              icon={<CrownOutlined />}
              loading={actionLoading[record.id]}
              disabled={isSelf}
              onClick={() => handleToggleAdmin(record.id)}
            >
              {record.is_admin ? "Remove Admin" : "Set Admin"}
            </Button>
            <Popconfirm
              title="Delete this user?"
              description="All batches and images owned by this user will be permanently deleted."
              onConfirm={() => handleDelete(record.id)}
              okText="Delete"
              okType="danger"
              disabled={isSelf}
            >
              <Button
                size="small"
                danger
                icon={<DeleteOutlined />}
                loading={actionLoading[`del_${record.id}`]}
                disabled={isSelf}
              >
                Delete
              </Button>
            </Popconfirm>
          </Space>
        );
      },
    },
  ];

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
        <Alert type="error" message={error} showIcon style={{ maxWidth: 400, margin: "0 auto" }} />
      </div>
    );
  }

  return (
    <div style={{ maxWidth: 900, margin: "0 auto" }}>
      <Title level={3} style={{ color: "#1a365d", marginBottom: 24 }}>
        User Management
      </Title>
      <Table
        columns={columns}
        dataSource={users}
        rowKey="id"
        pagination={false}
        bordered
        size="middle"
      />
    </div>
  );
}
