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
