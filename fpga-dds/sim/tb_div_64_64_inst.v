`timescale 1ns / 1ps

module tb_div_64_64_inst;

  // div_64_64_inst Parameters
  parameter PERIOD = 10;
  parameter DATA_WIDTH = 64;

  // div_64_64_inst Inputs
  reg  [DATA_WIDTH-1:0] numer_sig = 64'd1;
  reg  [DATA_WIDTH-1:0] denom_sig = 64'd1;

  // div_64_64_inst Outputs
  wire [DATA_WIDTH-1:0] quotient_sig;
  wire [DATA_WIDTH-1:0] remain_sig;

  initial begin
    #(PERIOD * 2 + PERIOD / 2) numer_sig = 64'h0000_0000_FFFF_FFFF;
    denom_sig = 64'd50_000_000;
  end

  div_64_64_inst #(
      .DATA_WIDTH(DATA_WIDTH)
  ) u_div_64_64_inst (
      .numer_sig(numer_sig[DATA_WIDTH-1:0]),
      .denom_sig(denom_sig[DATA_WIDTH-1:0]),

      .quotient_sig(quotient_sig[DATA_WIDTH-1:0]),
      .remain_sig  (remain_sig[DATA_WIDTH-1:0])
  );

  initial begin


  end

endmodule
