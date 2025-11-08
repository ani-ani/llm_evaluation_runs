module TopModule (
  input  clk,
  input  resetn,
  input  x,
  input  y,
  output reg f,
  output reg g
);

  localparam STATE_A = 3'd0;
  localparam STATE_B = 3'd1;
  localparam STATE_C = 3'd2;
  localparam STATE_D = 3'd3;
  localparam STATE_E = 3'd4;
  localparam STATE_F = 3'd5;

  reg [2:0] state, next_state;
  reg [2:0] x_history;
  reg counter;

  always @(posedge clk) begin
    if (!resetn) begin
      state <= STATE_A;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      STATE_A: if (resetn) next_state = STATE_B;
      STATE_B: next_state = STATE_C;
      STATE_C: if (x_history == 3'b101) next_state = STATE_D;
      STATE_D: begin
        if (y) next_state = STATE_E;
        else if (!counter) next_state = STATE_F;
      end
      STATE_E: next_state = STATE_E;
      STATE_F: next_state = STATE_F;
      default: next_state = STATE_A;
    endcase
  end

  always @(*) begin
    f = 1'b0;
    g = 1'b0;
    case (state)
      STATE_B: f = 1'b1;
      STATE_D, STATE_E: g = 1'b1;
      STATE_F: g = 1'b0;
    endcase
  end

  always @(posedge clk) begin
    if (!resetn) begin
      x_history <= 3'b0;
    end else begin
      if (state == STATE_C) begin
        x_history <= {x_history[1:0], x};
      end else begin
        x_history <= 3'b0;
      end
    end
  end

  always @(posedge clk) begin
    if (!resetn) begin
      counter <= 1'b0;
    end else begin
      if (state == STATE_C) begin
        counter <= 1'b1;
      end else if (state == STATE_D) begin
        counter <= counter - 1'b1;
      end
    end
  end

endmodule