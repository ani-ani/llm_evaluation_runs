module TopModule (input clk, input load, input [511:0] data, output reg [511:0] q);
  logic [511:0] next_state;
  always_ff @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_state;
  end
  always_comb begin
    for (int i = 0; i < 512; i++) begin
      logic left, right;
      left = (i == 511) ? 1'b0 : q[i+1];
      right = (i == 0) ? 1'b0 : q[i-1];
      case ({left, q[i], right})
        3'b111: next_state[i] = 1'b0;
        3'b110: next_state[i] = 1'b1;
        3'b101: next_state[i] = 1'b1;
        3'b100: next_state[i] = 1'b0;
        3'b011: next_state[i] = 1'b1;
        3'b010: next_state[i] = 1'b1;
        3'b001: next_state[i] = 1'b1;
        3'b000: next_state[i] = 1'b0;
        default: next_state[i] = 1'b0;
      endcase
    end
  end
endmodule