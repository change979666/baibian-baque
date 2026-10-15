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

`tests/` 目录下为一批**独立的无头 GDScript 脚本**（均 `extends SceneTree`，不依赖 GUT 等第三方测试框架），覆盖脚本编译检查、牌型/评分规则、玩法流程、AI 行为与音频资源加载等。需本机已安装对应 Godot 引擎后，在工程根目录运行，例如：

```bash
godot --headless -s tests/test_compile_all.gd
godot --headless -s tests/test_evaluator.gd
```

部分脚本（如 `guard_ab_experiment.gd`、`probe_livelock.gd`）为 livelock 终止保护参数校准用的实验脚本。

## 音频资源说明

- 实际使用的音频位于 `assets/audio/`（`bgm.ogg` 与各 `sfx_*.wav`），均随仓库提供。
- `SoundManager` 在加载任一音频前都会用 `ResourceLoader.exists()` 判断；缺失时会在运行时程序化合成等效音效与背景音乐，因此即使个别音频缺失游戏仍可出声。
- 根目录下的 `gold_reveal.wav.import`、`lobby_bgm.wav.import`、`table_bgm.wav.import`、`reference_audio_deal.wav.import` 是历史遗留的 Godot 导入记录，其对应的源 `.wav` 文件未随仓库发布，且当前代码未引用它们，仅为编辑器重新导入时的残留提示，不影响运行。

## 辅助脚本

根目录提供若干 Python 辅助脚本（`analyze_video.py`、`patch_*.py`、`rewrite_*.py`、`fix_*.py`），用于视频比对分析、源码批量修改与编码修复等开发工作流。

## 许可证

MIT License
