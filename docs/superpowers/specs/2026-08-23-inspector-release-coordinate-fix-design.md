# Inspector 松开连接坐标修复设计

## 问题

连接手势已经改为在 `_input()` 阶段接收松开事件，但代码仍把 `InputEventMouse.position` 的 Viewport 坐标直接用于 UI Canvas 矩形判断和世界 Canvas 命中判断。在窗口拉伸、编辑器嵌入或 DPI 缩放产生非单位变换时，Inspector 内的松开位置可能被换算成建筑输入端口，进而错误返回“连接已存在”。

## 设计

- `InputHandler` 保持以 Viewport 坐标接收输入。
- UI 命中测试由 `FactoryWorkspaceUI` 将 Viewport 点转换到各个 UI Control 的本地坐标，再用 `Rect2(Vector2.ZERO, size)` 判断。
- 世界命中由 `InputHandler` 将 Viewport 点转换到世界 Canvas 本地坐标，不再手写只覆盖 Camera2D 的转换链。
- 连接创建、取消提示、画布边界和现有 UI 布局规则保持不变。

## 验收

- 在非单位 Canvas 变换下，Inspector 内松开连接必须只产生一次取消提示，不能进入重复连接分支。
- 在同一变换下，真实输入端口仍能完成连接。
- 固定 1152×648 布局、暂停按钮和现有工厂工作区测试继续通过。

