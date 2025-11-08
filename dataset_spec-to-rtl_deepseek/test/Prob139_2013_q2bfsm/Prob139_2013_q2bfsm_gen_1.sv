module TopModule(input clk, input resetn, input x, input y, output logic f, output logic g);
  localparam STATE_A = 3'd0;
  localparam STATE_B = 3'd1;
  localparam STATE_C = 3'd2;
  localparam STATE_D = 3'd3;
  localparam STATE_E = 3'd4;
  localparam STATE_G_HOLD = 3'd5;
  localparam STATE_G_LOW = 3'd6;
  
  reg [2:0] state, next_state;
  reg [2:0] x_history;
  
  always @(posedge clk) begin
    if (!resetn) begin
      state <= STATE_A;
    end else begin
      state <= next_state;
    end
  end
  
  always @(posedge clk) begin
    if (!resetn) begin
      x_history <= 3'b0;
    end else if (state == STATE_C) begin
      x_history <= {x_history[1:0], x};
    end else begin
      x_history <= 3'b0;
    end
  end
  
  always_comb begin
    next_state = state;
    case (state)
      STATE_A: next_state = resetn ? STATE_B : STATE_A;
      STATE_B: next_state = STATE_C;
      STATE_C: if (x_history == 3'b101) next_state = STATE_D;
      STATE_D: next_state = y ? STATE_G_HOLD : STATE_E;
      STATE_E: next_state = y ? STATE_G_HOLD : STATE_G_LOW;
      default: next_state = state;
    endcase
  end
  
  assign f = (state == STATE_B);
  assign g = (state == STATE_D || state == STATE_E || state == STATE_G_HOLD);
endmodule