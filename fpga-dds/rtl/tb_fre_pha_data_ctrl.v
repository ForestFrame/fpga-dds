`timescale 1ps / 1ps

module tb_fre_pha_data_ctrl;

  // fre_pha_data_ctrl Parameters       
  parameter PERIOD = 10;
  parameter N = 32;
  parameter M = 12;
  parameter FRE_WIDTH = 10;
  parameter PHA_WIDTH = 8;
  parameter DATA_WIDTH = 64;

  // fre_pha_data_ctrl Inputs
  reg                  clk = 0;
  reg                  rstn = 0;
  reg  [FRE_WIDTH-1:0] fre_x = 0;
  reg  [FRE_WIDTH-1:0] fre_y = 0;
  reg  [FRE_WIDTH-1:0] fre_z = 0;
  reg  [PHA_WIDTH-1:0] pha_x = 0;
  reg  [PHA_WIDTH-1:0] pha_y = 2;

  // fre_pha_data_ctrl Outputs
  wire [        N-1:0] fre_step;
  wire [        M-1:0] pha_step;


  always #(PERIOD / 2) clk = ~clk;

  initial begin
    #(PERIOD * 2 + PERIOD / 2) rstn = 1;
    fre_x = 10'd1000;
  end

  fre_pha_data_ctrl u_fre_pha_data_ctrl (
      .clk  (clk),
      .rstn (rstn),
      .fre_x(fre_x[FRE_WIDTH-1:0]),
      .fre_y(fre_y[FRE_WIDTH-1:0]),
      .fre_z(fre_z[FRE_WIDTH-1:0]),
      .pha_x(pha_x[PHA_WIDTH-1:0]),
      .pha_y(pha_y[PHA_WIDTH-1:0]),

      .fre_step(fre_step[N-1:0]),
      .pha_step(pha_step[M-1:0])
  );

  initial begin


  end

endmodule
