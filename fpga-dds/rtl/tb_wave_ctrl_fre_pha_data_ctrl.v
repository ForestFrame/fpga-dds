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
