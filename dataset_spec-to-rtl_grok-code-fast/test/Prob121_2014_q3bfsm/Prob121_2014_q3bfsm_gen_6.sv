module TopModule(
  input clk,
  input reset,
  input x,
  output z
);
  reg [2:0] current_state, next_state;

  always @(*) begin
    case (current_state)
      3'b000: next_state = x ? 3'b001 : 3'b000;
      3'b001: next_state = x ? 3'b100 : 3'b001;
      3'b010: next_state = x ? 3'b001 : 3'b010;
      3'b011: next_state = x ? 3'b010 : 3'b001;
      3'b100: next_state = x ? 3'b100 : 3'b011;
      default: next_state = 3'b000;
    endcase
  end

  always @(posedge clk) begin
    if (reset)
      current_state <= 3'b000;
    else
      current_state <= next_state;
  end

  assign z = (current_state == 3'b011) || (current_state == 3'b100);
endmodule