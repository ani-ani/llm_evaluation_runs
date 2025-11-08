module TopModule (
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);

  wire [511:0] next_q;

  generate
    genvar i;
    for (i=0; i<512; i=i+1) begin : gen_rule110
      wire left = (i < 511) ? q[i+1] : 1'b0;
      wire right = (i > 0) ? q[i-1] : 1'b0;
      assign next_q[i] = q[i] ? ~(left & right) : right;
    end
  endgenerate

  always @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      q <= next_q;
    end
  end

endmodule