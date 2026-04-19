# CLAUDE.md

本仓库为 LFA Reader 项目,围绕 FeLV/FIV 试纸图像识别提供后端、Web、iOS 三端。本文件指导所有 Claude Code 会话在本仓库内的行为。

## 项目结构

```
lfa-reader/
├── apps/
│   ├── backend/      FastAPI + SQLAlchemy + OpenCV,Python 3.12
│   ├── web/          React 19 + Vite + Ant Design
│   └── ios/          SwiftUI,iOS 17+,Xcode 工程位于 apps/ios/LFAReader.xcodeproj
├── shared/data/      跨端共享资源,web 通过 Vite alias @shared 引用
└── tasks/            本地任务跟踪,不入库
```

入口:后端 `apps/backend/app/main.py`,Web `apps/web/src/main.jsx`,iOS `apps/ios/LFAReader/LFAReaderApp.swift`。

## 行为准则

1. 不基于猜测回答。信息不足时主动询问用户或联网查证。
2. 未经明确指示不替用户做决策。
   - 2.1 用户要求修改 A 时,严禁顺手改 B。
   - 2.2 多轮对话中用户已确认或未反对的内容必须逐字保留,不得自行精修。
   - 2.3 修 bug 若与原设计冲突,先与用户确认再改。
3. 引用案例与文献必须联网获取最新信息,严禁依赖陈旧知识库。
4. 需求确认协议
   - 4.1 需求未确认前严禁给方案。
   - 4.2 确认后分阶段推进,严禁一次性甩完整方案。
   - 4.3 用户未明确说"该部分确认"前不进入下一阶段。
5. 保持专业客观,严禁盲从与奉承。
6. 排版:严禁 emoji,避免破折号与括号;代码注释和文档不得提及 "Claude",不留 AI 撰写痕迹。
7. 关键代码必须有清晰注释,说明逻辑与目的。
8. 代码与对外文档(如 README)用英文,内部文档(CLAUDE.md、tasks/、解释性文字)用中文。专有名词保留原语言。

## 工作流

### 计划与执行
- 3 步以上或涉及架构决策的任务先出计划,写入 `tasks/todo.md`,使用复选框格式。
- 用户确认前严禁执行;执行偏离计划立即停下重做计划。
- 新任务开始前,把上一份 `tasks/todo.md` 重命名为 `tasks/todo-YYYYMMDD-<task-slug>.md` 归档。

### 完成验证
- 通过运行检查、查看日志、演示功能证明可用,再标记完成。
- 自问:资深工程师是否会签字通过?

### 改动哲学
- 简单优先:每次改动尽可能小,只触动必要部分。
- 不糊弄:找根因,严禁临时绕过和 hack。简单明显的修复不必过度设计。
- 用户每次纠正后,把模式与预防规则追加到 `tasks/lessons.md`(本地保存,不入库,不存在则创建);会话开始若文件存在则先阅读。

## 开发约定

### 服务重启
修改后端 Python 代码(router、service、model 等)后立即重启后端;修改前端代码后重启前端 dev server(若运行中)。在仓库根目录执行:

- 后端:`kill $(pgrep -f "uvicorn app.main:app") 2>/dev/null; cd apps/backend && nohup venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1 > uvicorn.log 2>&1 & disown`
- 前端:`kill $(pgrep -f "vite") 2>/dev/null; cd apps/web && nohup npm run dev > vite.log 2>&1 & disown`
- 查进程:`ps aux | grep -E "uvicorn|vite" | grep -v grep`

### iOS 端
- 主开发环境为 Linux 无 Xcode,iOS 端无法编译运行。
- iOS Swift 代码改动只能做静态检查,语法与类型推断需用户在 macOS 端验证。
- Xcode 工程文件 `apps/ios/LFAReader.xcodeproj/project.pbxproj` 的资源引用、Build Phase、Target 配置必须在 Xcode GUI 中改,严禁手工编辑 pbxproj。

### Git 提交
- 完成主要功能后立即提交。
- 提交前确认 `.gitignore` 已排除敏感文件:数据库、.env、上传目录、凭证。
- commit message 简洁,聚焦"为什么"。
