module TopModule(
  input clk,
  input resetn,
  input x,
  input y,
  output logic f,
  output logic g
);

  typedef enum logic [3:0] {
    A,
    F_OUTPUT,
    MONITOR_X,
    X1_DETECTED,
    X0_DETECTED,
    G_SET_FIRST,
    G_SET_SECOND,
    G_PERM,
    G_OFF
  } state_t;

  state_t current_state, next_state;

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      current_state <= A;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      A: if (resetn) next_state = F_OUTPUT;
      F_OUTPUT: next_state = MONITOR_X;
      MONITOR_X: if (x) next_state = X1_DETECTED;
      X1_DETECTED: begin
        if (!x) next_state = X0_DETECTED;
        else next_state = X1_DETECTED;
      end
      X0_DETECTED: begin
        if (x) next_state = G_SET_FIRST;
        else next_state = MONITOR_X;
      end
      G_SET_FIRST: begin
        if (y) next_state = G_PERM;
        else next_state = G_SET_SECOND;
      end
      G_SET_SECOND: begin
        if (y) next_state = G_PERM;
        else next_state = G_OFF;
      end
      default: ; // Handles G_PERM & G_OFF
    endcase
  end

  assign f = (current_state == F_OUTPUT);
  assign g = (current_state == G_SET_FIRST || current_state == G_SET_SECOND || current_state == G_PERM);

endmodule