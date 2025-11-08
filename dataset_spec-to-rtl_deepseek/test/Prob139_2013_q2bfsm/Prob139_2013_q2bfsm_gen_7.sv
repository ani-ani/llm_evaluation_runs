module TopModule(input clk, input resetn, input x, input y, output logic f, output logic g);
  typedef enum logic [3:0] {STATE_A, STATE_B, STATE_C, STATE_D, STATE_E, STATE_F, STATE_G_WAIT_1, STATE_G_ON_PERM, STATE_G_OFF} state_t;
  state_t current_state, next_state;

  always_ff @(posedge clk) begin
    if (!resetn) current_state <= STATE_A;
    else current_state <= next_state;
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      STATE_A: if (resetn) next_state = STATE_B;
      STATE_B: next_state = STATE_C;
      STATE_C: next_state = x ? STATE_D : STATE_C;
      STATE_D: next_state = x ? STATE_D : STATE_E;
      STATE_E: next_state = x ? STATE_F : STATE_C;
      STATE_F: next_state = y ? STATE_G_ON_PERM : STATE_G_WAIT_1;
      STATE_G_WAIT_1: next_state = y ? STATE_G_ON_PERM : STATE_G_OFF;
      STATE_G_ON_PERM, STATE_G_OFF: ;
      default: next_state = STATE_A;
    endcase
  end

  assign f = (current_state == STATE_B);
  assign g = (current_state == STATE_F || current_state == STATE_G_WAIT_1 || current_state == STATE_G_ON_PERM);
endmodule