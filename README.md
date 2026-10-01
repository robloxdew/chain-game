# CHAIN

> 一个基于 **Godot 4.7.2** 的 3D 动作对战手游，玩家对抗 AI 敌人 **CHAIN**。

![Godot](https://img.shields.io/badge/Godot-4.7.2-blue)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-brightgreen)
![Language](https://img.shields.io/badge/Language-GDScript-yellow)

---

## 简介

**CHAIN** 是一款手机端 3D 动作对战游戏。你将扮演一名战士，在开阔地图中与 AI 敌人 **CHAIN** 展开生死对决。  
游戏包含完整的武器系统、弹反机制、体力管理、QTE 掐脖、自爆 AI 等丰富玩法。

---

## 📌 平台说明

本项目支持 **iOS** 与 **Android** 双平台。

- **iOS**：主开发环境
- **Android**：已同步适配，正在编译 / 打包中

---

## 🎮 核心特性

- **武器系统**：砍刀、武士刀，不同攻击时长与弹反窗口
- **弹反系统**：
  - **擦刀**：攻击动作中精准招架，玩家免伤、双方不播动画、无冷却
  - **格挡**：举盾防御，冷却结束后触发特殊弹反（双方动画 + 28s 冷却）
- **躲避系统**：无敌帧 + 冷却转化机制
- **体力系统**：跑步消耗、站立/走路恢复
- **血屏与回血**：受击屏幕变红，定期自动回血
- **震撼弹**：拉环 → 投掷 → 范围眩晕 CHAIN
- **掐脖 QTE**：CHAIN 怒气满后抓取玩家，疯狂点击挣脱
- **自爆 AI**：CHAIN 每损失一定 HP 触发自爆，范围击倒 + 伤害
- **瞬移背刺**：CHAIN 有概率瞬移到玩家背后
- **开发者模式**：主菜单标题连点 5 次开启，含暂停 + 自由视角

---

## 📱 操作说明（触屏）

| 操作 | 位置 |
|------|------|
| 移动 | 屏幕左半区虚拟摇杆 |
| 视角 | 屏幕右半区滑动 |
| 攻击 | 右下角红色指纹按钮 |
| 格挡 | 右下角蓝色指纹按钮 |
| 躲避 | 右侧蓝色圆形按钮 |
| 跑步 | 右侧黄色小人按钮 |
| 拾取 | 靠近武器时屏幕下方按钮 |
| 震撼弹 | 拉环 / 投掷按钮（获得后显示） |

---

## 🛠 技术栈

- **引擎**：Godot 4.7.2 stable
- **语言**：GDScript
- **渲染**：Vulkan Forward Mobile
- **开发环境**：iOS（主） / Android（已适配）

---

## 🚀 快速开始

1. 安装 [Godot 4.7.2](https://godotengine.org/download)
2. 克隆本仓库：
   ```bash
   git clone https://github.com/robloxdew/chain-game.git
