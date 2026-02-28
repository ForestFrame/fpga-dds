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
