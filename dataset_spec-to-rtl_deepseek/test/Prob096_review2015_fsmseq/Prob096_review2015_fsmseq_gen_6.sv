module TopModule(input clk, input reset, input data, output reg start_shifting);
  typedef enum logic [2:0] { S0 = 3'b000, S1 = 3'b001, S2 = 3'b010, S3 = 3'b011, S4 = 3'b100 } state_t;
  state_t state;
  always_ff @(posedge clk) begin
    if (reset) begin
      state <= S0;
      start_shifting <= 1'b0;
    end else begin
      case (state)
        S0: state <= (data) ? S1 : S0;
        S1: state <= (data) ? S2 : S0;
        S2: state <= (data) ? S2 : S3;
        S3: begin
          if (data) begin
            state <= S4;
            start_shifting <= 1'b1;
          end else begin
            state <= S0;
          end
        end
        S4: state <= S4;
        default: state <= S0;
      endcase
    end
  end
endmodule