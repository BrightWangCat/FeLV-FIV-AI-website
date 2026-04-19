# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Claude Code Behavioral Guidelines

When working with this repository, Claude Code must adhere to the following principles:

1. It is strictly forbidden to provide answers based solely on speculation; you must ask the user or search online for accurate information.

2. You must not make decisions for the user without explicit instructions.
   - 2.1. When the user requests modifications to a specific part, it is strictly forbidden to modify other parts without authorization.
   - 2.2. In multi-turn conversations, any content previously confirmed by the user or content that the user has not objected to must be retained verbatim. You must not arbitrarily refine or change it based on your own inferences.
   - 2.3. If the modifications made when fixing bugs conflict with the original design requirements, you need to confirm with the user.

3. When the user requests the inclusion of case studies and literature, you must search online for the latest information; you must not use outdated knowledge bases.

4. Requirements confirmation protocol:
   - 4.1. It is strictly forbidden to generate any solutions before the requirements are confirmed.
   - 4.2. After confirming the requirements, you must address the requirements step by step, section by section; providing a one-time solution is strictly forbidden.
   - 4.3. You must not proceed to the next stage unless the user has explicitly stated that "This part is confirmed."

5. Blind obedience is strictly forbidden; maintain professional integrity; flattery is strictly forbidden; maintain a serious and objective demeanor.

6. Formatting: the use of emojis is strictly forbidden; minimize the use of dashes and parentheses. Do not include any mention of "Claude" in any code comments or documentation, and avoid any written evidence that the code was written by AI.

7. Important code must include clear notes and comments explaining the logic and purpose.

8. Use English to write code and对外公开文档 (如 README)。Use Chinese (excluding proper nouns) to answer the user and write internal docs (如 CLAUDE.md, tasks/, 注释外的解释文字)。

## Project Layout

```
lfa-reader/
├── apps/
│   ├── backend/      # FastAPI + SQLAlchemy + OpenCV,Python 3.12
│   ├── web/          # React 19 + Vite + Ant Design
│   └── ios/          # SwiftUI,iOS 17+,Xcode 工程位于 apps/ios/LFAReader.xcodeproj
├── shared/data/      # 跨端共享资源,web 通过 Vite alias @shared 引用
└── tasks/            # 本地任务跟踪,不入库
```

入口文件: 后端 `apps/backend/app/main.py`,Web `apps/web/src/main.jsx`,iOS `apps/ios/LFAReader/LFAReaderApp.swift`。

## Workflow Orchestration

### Plan Mode
- For any non-trivial task (3+ steps or architectural decisions), enter plan mode first.
- Write detailed specs upfront to reduce ambiguity.
- If execution deviates from the plan, stop immediately and re-plan. Do not force progress on a failing path.
- Plan mode also applies to verification steps, not just building.
- Plan mode does NOT override rule 4: plans must be confirmed by the user before execution.

### Self-Improvement Loop
- After any correction from the user, append the pattern and prevention rule to `tasks/lessons.md`. 此文件本地保存,不入库,如不存在则创建。
- Review `tasks/lessons.md` at session start if it exists.
- Ruthlessly iterate on these lessons until the same mistake no longer recurs.

### Verification Before Done
- Never mark a task complete without proving it works.
- Run available checks, inspect logs, demonstrate correctness.
- Ask yourself: "Would a senior engineer approve this?"

### Bug Investigation
- When given a bug report, deeply investigate root cause first: read logs, trace errors, identify failing points.
- Present findings and proposed fix to user for confirmation before modifying code (per rule 2 and rule 4).
- No temporary or hacky workarounds. Find and fix root causes.

### Demand Elegance (Balanced)
- For non-trivial changes, pause and consider if there is a more elegant approach.
- If a fix feels hacky, reconsider and propose the cleaner solution.
- Skip this for simple, obvious fixes. Do not over-engineer.

## Task Management

1. **Plan First**: 计划写入 `tasks/todo.md`,使用复选框格式。新任务开始前,把上一个任务的 `todo.md` 重命名为 `todo-YYYYMMDD-<task-slug>.md` 归档。
2. **Verify Plan**: Check in with user before starting implementation (per rule 4).
3. **Track Progress**: Mark items complete as you go.
4. **Explain Changes**: Provide high-level summary at each step.
5. **Document Results**: Add review section to `tasks/todo.md` upon completion.
6. **Capture Lessons**: Update `tasks/lessons.md` after any correction from user.

Note: `tasks/todo.md` and `tasks/lessons.md` are project-level tracking files. Create them if they do not exist.

### Service Restart After Code Changes
- After modifying backend Python code (routers, services, models, etc.), automatically restart the backend server so changes take effect immediately.
- After modifying frontend code, restart the frontend dev server if it is running.
- 后端重启,在仓库根目录执行: `kill $(pgrep -f "uvicorn app.main:app") 2>/dev/null; cd apps/backend && nohup venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1 > uvicorn.log 2>&1 & disown`
- 前端重启,在仓库根目录执行: `kill $(pgrep -f "vite") 2>/dev/null; cd apps/web && nohup npm run dev > vite.log 2>&1 & disown`
- 查看运行中的进程: `ps aux | grep -E "uvicorn|vite" | grep -v grep`

### iOS 端注意事项
- 当前主开发环境为 Linux,无 Xcode,无法编译或运行 iOS 端
- 修改 iOS Swift 代码后只能做静态检查,语法和类型推断需用户在 macOS 端验证
- 涉及 Xcode 工程文件 `apps/ios/LFAReader.xcodeproj/project.pbxproj` 的资源引用、Build Phase、Target 配置变更,必须在 Xcode GUI 中完成,不要手工编辑 pbxproj

### Git Commit Discipline
- After completing a major feature update, create a git commit immediately.
- Before committing, verify that .gitignore properly excludes sensitive data (database files, .env, uploads, credentials). Never commit these files.
- Write concise, meaningful commit messages describing the feature change.

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what is necessary. Avoid introducing bugs.
