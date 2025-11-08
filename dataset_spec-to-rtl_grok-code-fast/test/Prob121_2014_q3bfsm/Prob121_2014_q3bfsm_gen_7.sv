module TopModule(
  input clk,
  input reset,
  input x,
  output z
);
  reg [2:0] y;
  reg [2:0] next;

  always_comb begin
    case (y)
      3'd0: next = x ? 3'd1 : 3'd0;
      3'd1: next = x ? 3'd4 : 3'd1;
      3'd2: next = x ? 3'd1 : 3'd2;
      3'd3: next = x ? 3'd2 : 3'd1;
      3'd4: next = x ? 3'd4 : 3'd3;
      default: next = 3'd0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) y <= 3'd0;
    else y <= next;
  end

  assign z = (y == 3'd3) || (y == 3'd4);
endmodule