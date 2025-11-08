module TopModule(input clk, input resetn, input x, input y, output f, output g);
  typedef enum logic [3:0] {S_A, S_B, S_B0, S_B1, S_B2, S_C, S_C1, S_G_ON, S_G_OFF} state_t;
  state_t state;

  always_ff @(posedge clk) begin
    if (!resetn) begin
      state <= S_A;
    end else begin
      case (state)
        S_A    : state <= S_B;
        S_B    : state <= S_B0;
        S_B0   : state <= (x) ? S_B1 : S_B0;
        S_B1   : state <= (x) ? S_B1 : S_B2;
        S_B2   : state <= (x) ? S_C : S_B0;
        S_C    : state <= (y) ? S_G_ON : S_C1;
        S_C1   : state <= (y) ? S_G_ON : S_G_OFF;
        S_G_ON : state <= S_G_ON;
        S_G_OFF: state <= S_G_OFF;
        default: state <= S_A;
      endcase
    end
  end

  assign f = (state == S_B);
  assign g = (state == S_C) || (state == S_C1) || (state == S_G_ON);
endmodule