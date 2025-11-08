module TopModule(input clk, input resetn, input x, input y, output f, output g);
  typedef enum logic [2:0] { A, B, C, D, D1, E, F } state_t;
  state_t current_state, next_state;
  reg [2:0] x_history;
  
  always_ff @(posedge clk) begin
    if (!resetn) begin
      current_state <= A;
      x_history <= 3'b000;
    end else begin
      current_state <= next_state;
      if (current_state == C)
        x_history <= {x_history[1:0], x};
      else
        x_history <= 3'b000;
    end
  end
  
  always_comb begin
    case (current_state)
      A: next_state = B;
      B: next_state = C;
      C: next_state = (x_history == 3'b101) ? D : C;
      D: next_state = y ? E : D1;
      D1: next_state = y ? E : F;
      E: next_state = E;
      F: next_state = F;
      default: next_state = A;
    endcase
  end
  
  assign f = (current_state == B);
  assign g = (current_state == D || current_state == D1 || current_state == E);
endmodule