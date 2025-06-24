module div_64_64_inst #(
    parameter DATA_WIDTH = 64
) (
    input wire [DATA_WIDTH-1:0] numer_sig,
    input wire [DATA_WIDTH-1:0] denom_sig,

    output wire [DATA_WIDTH-1:0] quotient_sig,
    output wire [DATA_WIDTH-1:0] remain_sig
);

  div_64_64 div_64_64_inst (
      .denom(denom_sig),
      .numer(numer_sig),
      .quotient(quotient_sig),
      .remain(remain_sig)
  );

endmodule  //div_64_64_inst


