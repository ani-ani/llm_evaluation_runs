module TopModule (
  input clk,
  input load,
  input [511:0] data,
  output [511:0] q
);

  reg [511:0] state;
  wire [511:0] next_state;

  always_comb begin
    for (int i = 511; i >= 0; i--) begin
      logic left, right;
      left = (i == 511) ? 1'b0 : state[i+1];
      right = (i == 0) ? 1'b0 : state[i-1];

      case ({left, state[i], right})
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

  always_ff @(posedge clk) begin
    if (load)
      state <= data;
    else
      state <= next_state;
  end

  assign q = state;

endmodule