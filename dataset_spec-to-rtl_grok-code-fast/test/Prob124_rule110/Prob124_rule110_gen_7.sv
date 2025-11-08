module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);
  wire [511:0] next_q;
  always_comb begin
    for (int i = 0; i < 512; i++) begin
      logic [2:0] neighbors;
      neighbors[2] = (i < 511) ? q[i+1] : 1'b0;
      neighbors[1] = q[i];
      neighbors[0] = (i > 0) ? q[i-1] : 1'b0;
      case (neighbors)
        3'b111: next_q[i] = 1'b0;
        3'b110: next_q[i] = 1'b1;
        3'b101: next_q[i] = 1'b1;
        3'b100: next_q[i] = 1'b0;
        3'b011: next_q[i] = 1'b1;
        3'b010: next_q[i] = 1'b1;
        3'b001: next_q[i] = 1'b1;
        3'b000: next_q[i] = 1'b0;
      endcase
    end
  end
  always @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      q <= next_q;
    end
  end
endmodule