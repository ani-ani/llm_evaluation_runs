module TopModule(input reg clk, input reg areset, input reg x, output reg z);
  logic [1:0] state;
  logic [1:0] next_state;
  always_comb begin
    case (state)
      2'b01: begin  // A
        if (x == 1'b0) begin
          next_state = 2'b01;
          z = 1'b0;
        end else begin
          next_state = 2'b10;
          z = 1'b1;
        end
      end
      2'b10: begin  // B
        z = x ? 1'b0 : 1'b1;
        next_state = 2'b10;
      end
      default: begin
        next_state = 2'b01;
        z = 1'b0;
      end
    endcase
  end
  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      state <= 2'b01;
    else
      state <= next_state;
  end
endmodule