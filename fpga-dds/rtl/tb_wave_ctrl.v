`timescale 1ps / 1ps

module tb_wave_ctrl;

  // wave_ctrl Parameters
  parameter PERIOD = 10;
  parameter DATA_WIDTH = 8;
  parameter N = 32;
  parameter M = 12;
  parameter ADDR = 12;
  parameter sin_wave = 4'b0001;
  parameter squ_wave = 4'b0010;
  parameter tri_wave = 4'b0100;
  parameter saw_wave = 4'b1000;

  // wave_ctrl Inputs
  reg                     clk = 0;
  reg                     rstn = 0;
  reg  [             3:0] wave_sel = 0;
  reg  [           N-1:0] fre_step = 0;
  reg  [           M-1:0] pha_step = 0;

  // wave_ctrl Outputs
  wire [2*DATA_WIDTH-1:0] data_out;

  always #5 clk = ~clk;

  initial begin
    #(PERIOD * 2) rstn = 1;
    wave_sel = tri_wave;
    fre_step = 32'd42949672;
  end

  wave_ctrl #(
      .DATA_WIDTH(DATA_WIDTH),
      .N         (N),
      .M         (M),
      .ADDR      (ADDR)
  ) u_wave_ctrl (
      .clk     (clk),
      .rstn    (rstn),
      .wave_sel(wave_sel[3:0]),
      .fre_step(fre_step[N-1:0]),
      .pha_step(pha_step[M-1:0]),

      .data_out(data_out[2*DATA_WIDTH-1:0])
  );

  initial begin


  end

endmodule
