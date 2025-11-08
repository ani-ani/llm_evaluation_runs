module TopModule(
  input clk,
  input reset,
  input x,
  output reg z
);
  reg [2:0] state, next_state;

  parameter [2:0] S0 = 3'b000,
                  S1 = 3'b001,
                  S2 = 3'b010,
                  S3 = 3'b011,
                  S4 = 3'b100;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= S0;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    case (state)
      S0: begin
        next_state = x ? S1 : S0;
        z = 1'b0;
      end
      S1: begin
        next_state = x ? S4 : S1;
        z = 1'b0;
      end
      S2: begin
        next_state = x ? S1 : S2;
        z = 1'b0;
      end
      S3: begin
        next_state = x ? S2 : S1;
        z = 1'b1;
      end
      S4: begin
        next_state = x ? S4 : S3;
        z = 1'b1;
      end
    endcase
  end
endmodule