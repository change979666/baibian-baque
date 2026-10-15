# 百变八雀 · 点字成金

A Godot 4 desktop mahjong-inspired card game with hand and combo rules, AI opponent behavior, audio assets, and automated tests.

使用 **Godot 4.7.2** 开发的桌面麻将牌类游戏工程，包含完整源码、场景与自动化测试套件。

## 游戏简介

"百变八雀 · 点字成金"是一款桌面麻将玩法的休闲游戏（1280×720 横屏），核心机制围绕手牌管理、吃碰组合与破产流程展开，并包含 **AI 对手行为模拟**（AI livelock 修复等）。

## 项目结构

```
├── project.godot           # Godot 工程配置
├── export_presets.cfg      # 导出预设
├── scenes/main.tscn        # 主场景
├── src/                    # GDScript 源码（core / system / ai / ui / main，22 个 .gd 文件）
├── assets/                 # 游戏资源（图片 / 音频）
├── tests/                  # Godot GUT 测试套件（含终止保护实验脚本）
└── 各分析报告.md            # 规则梳理 / 审计 / 实现报告
```

## 运行方式

1. 从 [Godot 官网](https://godotengine.org/download/) 下载 **Godot 4.7.2**（Windows 64 位）
2. 用 Godot 打开 `project.godot`
3. 按 F5 运行主场景

> 引擎目录（`Godot_v4.7.2/`）与构建产物（`bin/`）不随仓库提交，请自行下载引擎。

## 测试

`tests/` 内含基于 GUT 的自动化测试（编译检查、玩法流程、AI 行为、音频加载等），部分实验脚本（如 `guard_ab_experiment.gd`）用于 livelock 终止保护参数校准。

## 辅助脚本

根目录提供若干 Python 辅助脚本（`analyze_video.py`、`patch_*.py`、`rewrite_*.py`、`fix_*.py`），用于视频比对分析、源码批量修改与编码修复等开发工作流。

## 许可证

MIT License
