module TopModule(input clk, input resetn, input x, input y, output f, output g);
  typedef enum logic [2:0] { S_A, S_B, S_C, S_D, S_E1, S_E2, S_F, S_G } state_t;
  state_t current_state, next_state;
  reg f_reg;

  always_ff @(posedge clk) begin
    if (!resetn) current_state <= S_A;
    else current_state <= next_state;
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      S_A: next_state = resetn ? S_B : S_A;
      S_B: if (x) next_state = S_C;
      S_C: begin
        if (!x) next_state = S_D;
        else next_state = S_B;
      end
      S_D: begin
        if (x) next_state = S_E1;
        else next_state = S_B;
      end
      S_E1: next_state = y ? S_F : S_E2;
      S_E2: next_state = y ? S_F : S_G;
      S_F: next_state = S_F;
      S_G: next_state = S_G;
      default: next_state = S_A;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!resetn) f_reg <= 1'b0;
    else f_reg <= (current_state == S_A) && (next_state == S_B);
  end

  assign f = f_reg;
  assign g = (current_state == S_E1) || (current_state == S_E2) || (current_state == S_F);
endmodule