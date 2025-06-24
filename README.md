### [fpga-dds](https://github.com/ForestFrame/fpga-dds)

​	两个礼拜前就想写这个文档了，但是一直鸽到现在，主要是人摆了。还有个技术上的原因是，我想用串口屏显示波形，在串口调试助手上返回的数据是对的，但是发到串口屏上啥反应没有，人就很麻，如果这个弄不出来，前面*HMI*串口屏的工程、人机交互界面就白做了。回归正题，下面开始讲*DDS*信号发生器的理论和代码实现。

## 一、理论部分

​	理论部分主要是从野火的*简易DDS信号发生器的设计与验证*课程中学习而来，加入了大量的我的理解，代码部分对野火的代码做了很多扩展，使得其更加完善。

### 1、DDS是啥

​	随便从某个地方摘了一点：

> *DDS* 是直接数字式频率合成器（Direct Digital Synthesizer）的英文缩写，是一项关键的数字化技术。与传统的频率合成器相比，*DDS* 具有低成本、低功耗、高分辨率和快速转换时间等优点，广泛使用在电信与电子仪器领域，是实现设备全数字化的一个关键技术。作为设计人员，我们习惯称它为信号发生器，一般用它产生正弦波、锯齿波、方波等不同波形或不同频率的信号波形，在电子设计和测试中得到广泛应用。

总之*DDS*就是一个信号发生器，能够产生不同种类、不同频率和不同初相的波形。

### 2、总体框图

![alt](https://resource.withpinbox.com/f/913802f70b/image/20221211/47a16c87-6f58-449b-a4fd-05681df5d000.png)

​	上图为*DDS*的基本结构，主要由相位累加器、相位调制器、波形数据表 *ROM* 、*D/A*转换器四大结构组成。*CLK*是系统工作时钟，频率为$f_{CLK}$；频率字输入*F_WORD*，为整数，控制输出信号的频率大小，它可以理解为一个步进值（后面具体说明）；相位字输入*P_WORD*，为整数，控制输出信号的相位偏移；由于我没有*D/A*转换器，所以直接输出8位的数字信号，设其频率为$f_{OUT}$。

​	另外提一句，之前我想用串口屏当作示波器用显示波形，但是串口屏本身仍然还是一个数字器件，不是模拟器件，它也是根据0~255的量化电平值作为电压值，显示出高低不同的像素点从而形成曲线，与示波器接收*D/A*转换器转后后的模拟电压值（像0.2*V*，1.4*V*等等）是不同的。

### 3、模块介绍

1. **输入缓存器**：在将频率字和相位字输入之后，有一个累加寄存器，是在系统时钟同步下做数据寄存，使得数据改变时不会干扰后续相位累加器和相位调制器的正常工作。
2. **相位累加器**：
   - 该部分是*DDS*的核心部分，在这里完成相位累加，生成相位码。为什么叫相位累加器呢，我的想法是，*DDS*产生信号的本质即为从*ROM*中读取一个周期的一个个信号点的值进行循环输出，在这一个周期内，从读一个点的值到读下一个点的值即为相位的累加。总的相位码即对应*ROM*地址中的一个周期的所有数据（事实上只取了相位码的高位部分）。
   - 相位累加器的的输入为频率字输入*F_WORD*，表示相位累加在每个时钟周期的增量，也可以理解为一个步进值，我在代码中用 *fre_step* 表示。当相位码（我在代码中用 *fre_add* 表示）累加溢出之后，表示一个周期的信号输出完毕。
   - 工作时钟信号频率 $f_{CLK}$，输出信号频率与频率字输入*F_WORD*之间的关系式为$f_{OUT} = F_{WORD} * f_{CLK} / 2^N$。其中*N*为频率字输入*F_WORD*和相位码的位宽，我在代码中设置为32，可以通过 *parameter* 进行更改。**上式可以这样理解，从硬件角度理解，当频率字输入*F_WORD*为1时，有关系式$f_{OUT} = f_{CLK} / 2^N$，在$2^N$计数容量内，每个时钟周期增加1，记满$2^N$后正好对应输出全部*ROM*中的信号值，这是一个周期；也可从数学角度理解为输出频率为系统时钟频率除以$2^N$。**此时的$f_{OUT}$为*DDS*的最小分辨率，输出信号频率最低。当频率字输入*F_WORD*增大时，每个时钟周期的累加增量扩大了*F_WORD*倍，因此输出频率是在最小分辨率的基础上乘以了这个倍数。
3. **相位调制器**：相位调制器接收相位累加器输出的相位码，同时加上相位偏移值（相位字输入）*P_WORD*，用于信号的相位偏移控制。和相位字输入*P_WORD*有关的关系式为$\theta = P_{WORD} * 2\pi / 2^M$。其中$\theta$为波形初相位，*M*为*ROM*地址位宽，在代码中相位字输入为 *pha_step*，含义为一步相位偏移。上式可以这样理解，一个周期信号对应角度$2\pi$对应*ROM*中的4096个数据，因此$2\pi / 2^M$则表示了数据表中每个数据所占据的相位值，乘以相位偏移值后得到总的偏移初相。
4. **波形数据表**：
   - 波形数据表为一个*ROM* *IP*核，其中存有一个完整周期的正弦波信号。代码中我设置的*ROM* *IP*核深度为4096，地址位宽即为12，数据存储位宽为8位。用*MATLAB*产生*ROM* *IP*核所需要的 *.mif*文件，将一个周期的正弦波信号（还有方波，锯齿波和三角波信号），沿横轴等间隔采样4096次，每次采集的信号幅度用一字节数据表示，最大值为255，最小值为0。将4096次采样结果按顺序写入*ROM*的4096个存储单元，则一个完整周期的正弦波的数字幅度信号写入了波形数据表*ROM*中。波形数据表*ROM*以相位调制器传入的相位码为*ROM*读地址，将地址对应的存储单元中的电压幅值数字量输出。
   - 关于从相位累加器得到的相位码对*ROM*进行寻址的问题。由上文所说，*N*为相位累加器的位宽，*M*为*ROM*地址位宽，*M*由一个信号周期的采样点数决定，**怎样决定*N*的大小我还不清楚。**对于*N*位的相位累加器，相位码的最大值为$2^N$，如果*ROM*中存储单元的个数也为$2^N$的话，这个问题就很好解决，但是这对*ROM*存储容量的要求就较高。在实际中可以采用相位码的高几位对*ROM*进行寻址，也就是说不是每个系统时钟周期都对*ROM*进行一次数据读取，而是多个时钟读取一次，即读取一个信号点。

### 4、对上述的理论举个栗子

​	设：*ROM*存储单元深度为4096，则*ROM*地址位宽为12位，每个数据存储单元位宽为8位，相位累加器位宽为32位。

​	由上述条件，根据*DDS*原理，相位累加器的32位频率控制字不断累加**；而在相位调制器中与相位控制字进行累加时，应用相位累加器的高12位。**由于采用相位累加器的高12位作为*ROM*寻址，当低20位溢出向高12位加一时，向*ROM*寻址一次输出一个数据表中的数据。

​	以频率控制字*F_WORD*=1为例，相位累加器的低20位会在每一个时钟周期不断加一，直到低20位溢出向高12位进位，在溢出之前，读取*ROM*的地址一直为0，也就是说*ROM*的0地址中的数据被读了$2^{20}$次。继续下去在溢出后地址加一，读向*ROM*地址1，这个数据被再次读$2^{20}$次。接下来的所有点都是如此。最终输出的波形频率应该是工作时钟频率的$1/2^{20}$，周期被扩大了$2^{20}$倍。

​	同样当频率控制字*F_WORD*=100时，相位累加器的低20位会一直加100，那么，相位累加器的低20位溢出的时间比上面会快100倍，则*ROM*中的每个点相比于上面会少读100次，所以最终输出频率是上述的100倍。

## 二、代码部分

### 1、波形控制部分代码

```verilog
module wave_ctrl #(
    parameter DATA_WIDTH_ROM = 8,  //输出数据位宽
    parameter N = 32,  //相位累加器位宽
    parameter M = 12,  //相位调制器位宽
    parameter ADDR = 12  //ROM数据表位宽
) (
    input wire clk,
    input wire rstn,

    input wire [3:0] wave_sel,  //波形选择

    input wire [N-1:0] fre_step,  //频率字输入，相当于一个步进值，每个时钟周期增加的值
    input wire [M-1:0] pha_step,  //相位字输入，相当于一个步进值，每个时钟周期增加的值

    output wire [2*DATA_WIDTH_ROM-1:0] data_out
);

  //四种波形信号选择参数定义
  parameter sin_wave = 4'b0001;  //正弦波
  parameter squ_wave = 4'b0010;  //方波
  parameter tri_wave = 4'b0100;  //三角波
  parameter saw_wave = 4'b1000;  //锯齿波

  //频率字和相位字输入缓存
  reg [N-1:0] fre_step_reg;
  reg [M-1:0] pha_step_reg;

  //相位累加信号和相位调制后信号
  reg [N-1:0] fre_add;  //相位码
  reg [M-1:0] pha_add;

  //四种波形的ROM读使能信号
  reg [0:0] sin_wave_en;
  reg [0:0] squ_wave_en;
  reg [0:0] tri_wave_en;
  reg [0:0] saw_wave_en;

  //ROM读地址
  reg [ADDR-1:0] rom_addr;

  reg [ADDR-1:0] sin_wave_rom_addr;
  reg [ADDR-1:0] squ_wave_rom_addr;
  reg [ADDR-1:0] tri_wave_rom_addr;
  reg [ADDR-1:0] saw_wave_rom_addr;

  //四种波形的ROM输出信号
  wire [DATA_WIDTH_ROM-1:0] sin_wave_data_out;
  wire [DATA_WIDTH_ROM-1:0] squ_wave_data_out;
  wire [DATA_WIDTH_ROM-1:0] tri_wave_data_out;
  wire [DATA_WIDTH_ROM-1:0] saw_wave_data_out;

  //波形选择
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      sin_wave_en <= 1'b0;
      squ_wave_en <= 1'b0;
      tri_wave_en <= 1'b0;
      saw_wave_en <= 1'b0;
      sin_wave_rom_addr <= 0;
      squ_wave_rom_addr <= 0;
      tri_wave_rom_addr <= 0;
      saw_wave_rom_addr <= 0;
    end
    case (wave_sel)
      sin_wave: begin
        sin_wave_en <= 1'b1;
        squ_wave_en <= 1'b0;
        tri_wave_en <= 1'b0;
        saw_wave_en <= 1'b0;
        sin_wave_rom_addr <= rom_addr;
      end
      squ_wave: begin
        sin_wave_en <= 1'b0;
        squ_wave_en <= 1'b1;
        tri_wave_en <= 1'b0;
        saw_wave_en <= 1'b0;
        squ_wave_rom_addr <= rom_addr;
      end
      tri_wave: begin
        sin_wave_en <= 1'b0;
        squ_wave_en <= 1'b0;
        tri_wave_en <= 1'b1;
        saw_wave_en <= 1'b0;
        tri_wave_rom_addr <= rom_addr;
      end
      saw_wave: begin
        sin_wave_en <= 1'b0;
        squ_wave_en <= 1'b0;
        tri_wave_en <= 1'b0;
        saw_wave_en <= 1'b1;
        saw_wave_rom_addr <= rom_addr;
      end
    endcase
  end

  //频率字输入缓存器
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      fre_step_reg <= 0;
    end else begin
      fre_step_reg <= fre_step;
    end
  end

  //相位字输入缓存器
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      pha_step_reg <= 0;
    end else begin
      pha_step_reg <= pha_step;
    end
  end

  //相位累加器
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      fre_add <= 0;
    end else begin
      fre_add <= fre_add + fre_step_reg;
    end
  end

  //相位调制器
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      pha_add <= 0;
    end else begin
      pha_add <= fre_add[N-1:N-M] + pha_step_reg;
    end
  end

  //将相位调制后信号作为ROM读地址输入
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      rom_addr <= 0;
    end else begin
      rom_addr <= pha_add;
    end
  end

  sin_wave_rom_8x4096 sin_wave_rom_8x4096_inst (
      .address(sin_wave_rom_addr),
      .clock  (clk),
      .rden   (sin_wave_en),
      .q      (sin_wave_data_out)
  );

  squ_wave_rom_8x4096 squ_wave_rom_8x4096_inst (
      .address(squ_wave_rom_addr),
      .clock  (clk),
      .rden   (squ_wave_en),
      .q      (squ_wave_data_out)
  );

  tri_wave_rom_8x4096 tri_wave_rom_8x4096_inst (
      .address(tri_wave_rom_addr),
      .clock  (clk),
      .rden   (tri_wave_en),
      .q      (tri_wave_data_out)
  );

  saw_wave_rom_8x4096 saw_wave_rom_8x4096_inst (
      .address(saw_wave_rom_addr),
      .clock  (clk),
      .rden   (saw_wave_en),
      .q      (saw_wave_data_out)
  );

  assign data_out = (sin_wave_en ? sin_wave_data_out : 0) + (squ_wave_en ? squ_wave_data_out : 0) + (tri_wave_en ? tri_wave_data_out : 0) + (saw_wave_en ? saw_wave_data_out : 0);

endmodule  //dds_ctrl

```

### 2、频率、相位字控制代码：

​	以下这份代码的功能是可以分别输入 *fre_x MHz*， *fre_y kHz*和 *fre_z Hz*的频率以及 *pha_x* $\pi$和$(1/pha\_y)*\pi$的初相，并将以上的输入数据通过公式转换成频率和相位字的代码。

```verilog
module fre_pha_data_ctrl #(
    parameter N = 32,  //相位累加器位宽
    parameter M = 12,  //相位调制器位宽
    parameter FRE_WIDTH = 10,  //三路频率输入的位宽，三路频率的单位分别为MHz,kHz,Hz
    parameter PHA_WIDTH = 8,  //两路相位输入的位宽，(x+1/y)pi
    parameter DATA_WIDTH = 64
) (
    input wire clk,
    input wire rstn,

    input wire [FRE_WIDTH-1:0] fre_x,  //MHz
    input wire [FRE_WIDTH-1:0] fre_y,  //kHz
    input wire [FRE_WIDTH-1:0] fre_z,  //Hz

    input wire [PHA_WIDTH-1:0] pha_x,  //x*pi
    input wire [PHA_WIDTH-1:0] pha_y,  //(1/y)*pi

    output wire [N-1:0] fre_step,  //频率字输入，相当于一个步进值，每个时钟周期增加的值
    output wire [M-1:0] pha_step   //相位字输入，相当于一个步进值，每个时钟周期增加的值
);

  /* ----------频率数据处理 fre_step---------- */
  parameter _1MHZ = 1_000_000;
  parameter _1KHZ = 1_000;
  parameter CLK_IN = 64'd50 * _1MHZ;

  wire [DATA_WIDTH-1:0] fre_out;  //实际输出信号频率
  wire [DATA_WIDTH-1:0] temp;  //中间值，fre_out*(2^N)的值

  reg  [DATA_WIDTH-1:0] fre_reg_x;  //频率输入x缓存信号
  reg  [DATA_WIDTH-1:0] fre_reg_y;  //频率输入y缓存信号
  reg  [DATA_WIDTH-1:0] fre_reg_z;  //频率输入z缓存信号

  wire [DATA_WIDTH-1:0] fre_step_temp;

  //单位MHz，化为Hz
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      fre_reg_x <= 64'd0;
    end else begin
      fre_reg_x <= fre_x * _1MHZ;
    end
  end

  //单位kHz，化为Hz
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      fre_reg_y <= 64'd0;
    end else begin
      fre_reg_y <= fre_y * _1KHZ;
    end
  end

  //单位Hz，寄存器缓存
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      fre_reg_z <= 64'd0;
    end else begin
      fre_reg_z <= fre_z;
    end
  end

  //将三者相加得到实际输出频率
  assign fre_out = fre_reg_x + fre_reg_y + fre_reg_z;

  //将实际输出频率乘以2^N次方，即左移N位
  assign temp = fre_out << N;

  //将temp除以时钟频率CLK_IN
  div_64_64_inst #(
      .DATA_WIDTH(DATA_WIDTH)
  ) u_div_64_64_inst1 (
      .numer_sig   (temp),
      .denom_sig   (CLK_IN),
      .quotient_sig(fre_step_temp),
      .remain_sig  ()
  );

  assign fre_step = fre_step_temp[N-1:0];

  /* ----------相位数据处理 pha_step---------- */
  reg  [DATA_WIDTH-1:0] pha_reg_x;  //相位输入x缓存信号
  reg  [DATA_WIDTH-1:0] pha_reg_y;  //相位输入y缓存信号

  wire [DATA_WIDTH-1:0] temp_x;
  wire [DATA_WIDTH-1:0] temp_y;

  wire [DATA_WIDTH-1:0] pha_step_temp;

  //相位输入x缓存器
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      pha_reg_x <= 1'd1;
    end else begin
      pha_reg_x <= pha_x;
    end
  end

  //相位输入y缓存器
  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      pha_reg_y <= 64'd1;
    end else begin
      pha_reg_y <= pha_y;
    end
  end

  //计算X*2^(M-1)
  assign temp_x = pha_reg_x << (M - 1);

  //计算(1/Y)*2^(M-1)
  div_64_64_inst #(
      .DATA_WIDTH(DATA_WIDTH)
  ) u_div_64_64_inst (
      .numer_sig   (64'd2048),
      .denom_sig   (pha_reg_y),
      .quotient_sig(temp_y),
      .remain_sig  ()
  );

  //计算pha_step，总表达式为(X+1/Y)*2^(M-1)
  assign pha_step_temp = temp_x + temp_y;

  assign pha_step = pha_step_temp[M-1:0];

endmodule  //fre_pha_data_ctrl

```

### 3、合并以上两个模块的顶层文件：

```verilog
module wave_ctrl_fre_pha_data_ctrl #(
    parameter N = 32,  //相位累加器位宽
    parameter M = 12,  //相位调制器位宽
    parameter FRE_WIDTH = 10,  //三路频率输入的位宽，三路频率的单位分别为MHz,kHz,Hz
    parameter PHA_WIDTH = 8,  //两路相位输入的位宽，(x+1/y)pi
    parameter DATA_WIDTH = 64,
    parameter DATA_WIDTH_ROM = 8,  //输出数据位宽
    parameter ADDR = 12  //ROM数据表位宽
) (
    input wire [0:0] clk,
    input wire [0:0] rstn,

    input wire [FRE_WIDTH-1:0] fre_x,  //MHz
    input wire [FRE_WIDTH-1:0] fre_y,  //kHz
    input wire [FRE_WIDTH-1:0] fre_z,  //Hz

    input wire [PHA_WIDTH-1:0] pha_x,  //x*pi
    input wire [PHA_WIDTH-1:0] pha_y,  //(1/y)*pi

    input wire [3:0] wave_sel,  //波形选择

    output wire [2*DATA_WIDTH_ROM-1:0] data_out
);

wire [N-1:0] fre_step;
wire [M-1:0] pha_step;

  fre_pha_data_ctrl #(
      .N         (N),
      .M         (M),
      .FRE_WIDTH (FRE_WIDTH),
      .PHA_WIDTH (PHA_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) u_fre_pha_data_ctrl (
      .clk     (clk),
      .rstn    (rstn),
      .fre_x   (fre_x),
      .fre_y   (fre_y),
      .fre_z   (fre_z),
      .pha_x   (pha_x),
      .pha_y   (pha_y),
      .fre_step(fre_step),
      .pha_step(pha_step)
  );

  wave_ctrl #(
      .DATA_WIDTH_ROM(DATA_WIDTH_ROM),
      .N         (N),
      .M         (M),
      .ADDR      (ADDR)
  ) u_wave_ctrl (
      .clk     (clk),
      .rstn    (rstn),
      .wave_sel(wave_sel),
      .fre_step(fre_step),
      .pha_step(pha_step),
      .data_out(data_out)
  );

endmodule  //tb_wave_ctrl_fre_pha_data_ctrl

```

### 4、关于*IP*核：

​	第一份代码中实例化的四个单端口8x4096的*ROM* *IP*核，配置、调用及实例化*IP*核的过程这里不再描述，生成 *.mif*配置数据文件的*MATLAB*代码将放在其他文章中给出，将会放在*MATLAB数字信号处理*专栏中。
​	第二份代码中实例化了除法器，用于数据运算。

### 5、顶层代码的*testbench*代码：

```verilog
`timescale 1ns / 1ns

module tb_wave_ctrl_fre_pha_data_ctrl;

  // wave_ctrl_fre_pha_data_ctrl Parameters
  parameter PERIOD = 10;
  parameter N = 32;
  parameter M = 12;
  parameter FRE_WIDTH = 10;
  parameter PHA_WIDTH = 8;
  parameter DATA_WIDTH = 64;
  parameter DATA_WIDTH_ROM = 8;

  // wave_ctrl_fre_pha_data_ctrl Inputs
  reg  [             0:0] clk = 0;
  reg  [             0:0] rstn = 0;
  reg  [   FRE_WIDTH-1:0] fre_x = 0;
  reg  [   FRE_WIDTH-1:0] fre_y = 0;
  reg  [   FRE_WIDTH-1:0] fre_z = 0;
  reg  [   PHA_WIDTH-1:0] pha_x = 0;
  reg  [   PHA_WIDTH-1:0] pha_y = 0;
  reg  [             3:0] wave_sel = 4'b001;

  // wave_ctrl_fre_pha_data_ctrl Outputs
  wire [2*DATA_WIDTH-1:0] data_out;


  always #PERIOD clk = ~clk;

  initial begin
    #(PERIOD * 2 + PERIOD / 2) rstn = 1;

    #(PERIOD) wave_sel = 4'b0001;
    fre_x = 10;
    pha_x = 0;
    pha_y = 2;

    #(PERIOD * 1000) wave_sel = 4'b0001;
    fre_x = 2;
    pha_x = 0;
    pha_y = 2;

    #(PERIOD * 1000) wave_sel = 4'b0010;
    fre_x = 1;
    pha_x = 1;
    pha_y = 1;

    #(PERIOD * 1000) wave_sel = 4'b0100;
    fre_x = 1;
    pha_x = 1;
    pha_y = 1;

    #(PERIOD * 1000) wave_sel = 4'b1000;
    fre_x = 1;
    pha_x = 1;
    pha_y = 1;
  end

  wave_ctrl_fre_pha_data_ctrl #(
      .N             (N),
      .M             (M),
      .FRE_WIDTH     (FRE_WIDTH),
      .PHA_WIDTH     (PHA_WIDTH),
      .DATA_WIDTH    (DATA_WIDTH),
      .DATA_WIDTH_ROM(DATA_WIDTH_ROM)
  ) u_wave_ctrl_fre_pha_data_ctrl (
      .clk     (clk[0:0]),
      .rstn    (rstn[0:0]),
      .fre_x   (fre_x[FRE_WIDTH-1:0]),
      .fre_y   (fre_y[FRE_WIDTH-1:0]),
      .fre_z   (fre_z[FRE_WIDTH-1:0]),
      .pha_x   (pha_x[PHA_WIDTH-1:0]),
      .pha_y   (pha_y[PHA_WIDTH-1:0]),
      .wave_sel(wave_sel[3:0]),

      .data_out(data_out[2*DATA_WIDTH-1:0])
  );

  initial begin

  end

endmodule

```
