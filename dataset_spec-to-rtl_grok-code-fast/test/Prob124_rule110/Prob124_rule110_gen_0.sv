module TopModule (
  input  clk,
  input  load,
  input  [511:0] data,
  output reg [511:0] q
);

  logic [511:0] next_q;

  always_comb begin
    for (int i = 0; i < 512; i++) begin
      logic [2:0] key = {(i > 0 ? q[i-1] : 1'b0), q[i], (i < 511 ? q[i+1] : 1'b0)};
      case (key)
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