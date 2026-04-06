# 基于FPGA的DDS数字信号发生器实现

本项目是一个基于 FPGA 的 DDS（Direct Digital Synthesizer，直接数字频率合成）数字信号发生器实现，核心目标是在 FPGA 内部完成波形重建与输出。当前仓库聚焦于 DDS 核本身，包含 RTL 设计、Quartus 工程、ROM 波表、MATLAB 波形生成脚本和基础 testbench，适合作为课程设计、原理学习和后续系统集成的基础工程。

项目当前可生成 4 种典型波形：

- 正弦波
- 方波
- 三角波
- 锯齿波

在实现方式上，项目采用：

- `32bit` 相位累加器，提供很细的频率分辨率
- `12bit` 波表地址，使用 `4096` 点 ROM 进行查表输出
- `50MHz` DDS 工作时钟
- 频率与相位参数分离输入，便于控制与扩展

## 项目介绍

从功能上看，这个工程完成的是 DDS 的数字部分，即：

1. 接收频率参数与相位参数
2. 将参数换算为频率字 `fre_step` 和相位字 `pha_step`
3. 使用相位累加器不断推进当前相位
4. 取相位高位查找波形 ROM
5. 输出当前时刻的数字波形幅值

可以把它理解为一个“用相位累加驱动波表 ROM 的数字波形发生器”。

## 工程结构

当前仓库的主要目录如下：

```text
fpga-dds/
├─ README.md
├─ FPGA_DDS_README.md
├─ MY_UNDERSTANDING.md
└─ fpga-dds/
   ├─ quartus_prj/
   │  ├─ CurriculumDesign.qpf
   │  └─ CurriculumDesign.qsf
   ├─ rtl/
   │  ├─ fre_pha_data_ctrl.v
   │  ├─ wave_ctrl.v
   │  ├─ wave_ctrl_fre_pha_data_ctrl.v
   │  ├─ tb_fre_pha_data_ctrl.v
   │  ├─ tb_wave_ctrl.v
   │  ├─ tb_wave_ctrl_fre_pha_data_ctrl.v
   │  └─ ip_core/
   ├─ sim/
   │  ├─ div_64_64.v
   │  └─ tb_div_64_64_inst.v
   ├─ matlab_prj/
   │  ├─ *.mlx
   │  ├─ *.mif
   │  └─ *.ver
   └─ doc/
      └─ dds.vsdx
```

## DDS 原理简介

DDS 的基本思想不是“直接生成频率”，而是通过“相位累加”的方式间接生成波形。

在本项目中：

- 相位累加器位宽为 `N = 32`
- 波表地址位宽为 `M = 12`
- DDS 工作时钟为 `f_clk = 50MHz`

每个时钟周期执行一次：

```text
fre_add = fre_add + fre_step
```

其中：

- `fre_add` 表示当前相位
- `fre_step` 表示每拍前进的相位步长

随后取相位累加器高 `12bit`，并叠加相位偏移量：

```text
pha_add = fre_add[31:20] + pha_step
```

再用 `pha_add` 去查波形 ROM，得到当前波形点值。

## 频率与相位控制

### 频率控制

当前仓库中的频率输入被拆分为 3 部分：

- `fre_x`：MHz
- `fre_y`：kHz
- `fre_z`：Hz

对应目标输出频率：

```text
f_out = fre_x * 1MHz + fre_y * 1kHz + fre_z * 1Hz
```

随后换算成 DDS 频率字：

```text
fre_step = f_out * 2^N / f_clk
```

在本项目中代入参数：

```text
fre_step = f_out * 2^32 / 50,000,000
```

### 相位控制

相位输入采用：

- `pha_x`
- `pha_y`

其表达含义为：

```text
phase = (pha_x + 1 / pha_y) * π
```

再换算为 ROM 地址空间中的相位字：

```text
pha_step = (pha_x + 1 / pha_y) * 2^(M-1)
```

在当前实现中：

- `M = 12`
- 即相位被映射到 `4096` 点波表地址空间中

## 为什么频率分辨率高

DDS 的理论最小频率步进由相位累加器位宽决定：

```text
Δf = f_clk / 2^N
```

本项目中：

```text
Δf = 50,000,000 / 2^32
   ≈ 0.0116415 Hz
```

这意味着：

- 当 `fre_step` 仅增加 `1`
- 输出频率只变化约 `0.0116Hz`

因此，虽然 ROM 地址只有 `12bit`，但频率精度仍然由 `32bit` 相位累加器决定。二者分工不同：

- `32bit` 相位累加器决定频率分辨率
- `12bit` 波表地址决定波形逼近精度

## 核心模块说明

### 1. `fre_pha_data_ctrl.v`

路径：`fpga-dds/rtl/fre_pha_data_ctrl.v`

作用：

- 接收频率与相位输入参数
- 将工程输入换算为 `fre_step`
- 将相位输入换算为 `pha_step`
- 通过 `64bit` 除法 IP 完成频率字和部分相位字计算

### 2. `wave_ctrl.v`

路径：`fpga-dds/rtl/wave_ctrl.v`

作用：

- 缓存频率字与相位字
- 完成相位累加
- 完成相位偏移叠加
- 选择波形类型
- 驱动不同波形 ROM 输出数字波形

这是本项目 DDS 的核心波形生成模块。

### 3. `wave_ctrl_fre_pha_data_ctrl.v`

路径：`fpga-dds/rtl/wave_ctrl_fre_pha_data_ctrl.v`

作用：

- 对 `fre_pha_data_ctrl` 与 `wave_ctrl` 进行组合封装
- 形成完整的 DDS 顶层模块

Quartus 工程中设置的顶层实体也是该模块。

## 波形 ROM 设计

本项目使用 4 组单端口 ROM IP 作为波形查找表：

- `sin_wave_rom_8x4096`
- `squ_wave_rom_8x4096`
- `tri_wave_rom_8x4096`
- `saw_wave_rom_8x4096`

其共性参数为：

- 数据宽度：`8bit`
- 深度：`4096`
- 地址宽度：`12bit`

波表初始化文件由 MATLAB 生成，位于：

- `fpga-dds/matlab_prj/sin_wave_8x4096.mif`
- `fpga-dds/matlab_prj/squ_wave_8x4096.mif`
- `fpga-dds/matlab_prj/tri_wave_8x4096.mif`
- `fpga-dds/matlab_prj/saw_wave_8x4096.mif`

## 开发环境

从工程文件可知，本项目主要基于以下工具链：

- Intel Quartus Prime Lite 21.1.1
- ModelSim（Verilog）
- MATLAB

目标 FPGA 器件：

- `Cyclone IV E`
- `EP4CE10F17C8`

Quartus 顶层实体：

- `wave_ctrl_fre_pha_data_ctrl`

## 如何使用

### 1. 打开工程

使用 Quartus 打开：

```text
fpga-dds/quartus_prj/CurriculumDesign.qpf
```

### 2. 检查波表文件

确保 `matlab_prj` 目录下的 `.mif` 文件存在，因为 ROM IP 依赖这些初始化文件。

### 3. 运行综合

工程会自动包含：

- 3 个核心 RTL 文件
- 4 个 ROM QIP 文件
- 1 个除法器 QIP 文件

### 4. 运行仿真

当前仓库中提供了以下 testbench：

- `fpga-dds/rtl/tb_fre_pha_data_ctrl.v`
- `fpga-dds/rtl/tb_wave_ctrl.v`
- `fpga-dds/rtl/tb_wave_ctrl_fre_pha_data_ctrl.v`
- `fpga-dds/sim/tb_div_64_64_inst.v`

推荐优先从顶层 testbench 开始观察整体波形输出流程。

## 当前项目边界

需要注意，这个仓库目前主要是 DDS 核与验证工程，并不是完整的最终产品。当前边界包括：

- 输出仍是数字波形数据，不包含 DAC 模拟输出链路
- 工程重点是 DDS 本体，不包含更大系统中的识别与控制流程
- 强依赖 Intel FPGA IP，适合在 Quartus/ModelSim 环境下使用

因此，它更适合作为：

- FPGA DDS 原理学习工程
- 课程设计基础工程
- 后续系统集成的波形发生器内核
