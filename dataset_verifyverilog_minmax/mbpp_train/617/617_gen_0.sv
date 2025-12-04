module min_jumps (
  input [7:0] a,
  input [7:0] b,
  input [7:0] d,
  output reg [15:0] jumps
);

  // Q8.8 format: integer part in bits[15:8], fractional part in bits[7:0]
  // All operations are integer math with scaling by 256 (<< 8)
  wire [7:0] a_in = a;
  wire [7:0] b_in = b;

  // 1) tie-step operation:
  //    tp = min(a,b)
  //    b  = max(a,b)
  //    a  = tp
  wire [7:0] tp = (a_in < b_in) ? a_in : b_in;
  wire [7:0] b_adj = (a_in > b_in) ? a_in : b_in;
  wire [7:0] a_adj = tp;

  // 2) Conditional behavior to produce jumps in Q8.8
  always @(*) begin
    if (d == 8'd0) begin
      jumps = 16'd0; // jumps = 0
    end
    else if (d == a_adj) begin
      jumps = 16'd256; // jumps = 1 in Q8.8 (0x0100)
    end
    else if ((d < b_adj) && (d != a_adj) && (d != 8'd0)) begin
      jumps = 16'd512; // jumps = 2 in Q8.8 (0x0200)
    end
    else begin
      // jumps = ((d + b - 1) * 256) / b  [ceil(d / b) in Q8.8]
      // Using integer math; guard against b == 0 even though inputs are expected to be > 0
      if (b_adj == 8'd0) begin
        jumps = 16'd0;
      end else begin
        jumps = ((d + b_adj - 1) << 8) / b_adj;
      end
    end
  end

endmodule
