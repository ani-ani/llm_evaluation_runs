module TopModule(
  input clk,
  input resetn,
  input x,
  input y,
  output reg f,
  output reg g
);

  typedef enum reg [2:0] {
    RESET      = 3'b000,
    SET_F      = 3'b001,
    MONITOR_X0 = 3'b010,
    MONITOR_X1 = 3'b011,
    MONITOR_X2 = 3'b100,
    MONITOR_X3 = 3'b101,
    MONITOR_Y  = 3'b110,
    DONE_G1    = 3'b111,
    DONE_G0    = 3'b001 // reusing, but since 2'b000 not used, actually DONE_G0 = 3'b000, but reset is 
  } state_t;

  state_t state, next_state;
  reg [1:0] y_counter;

  always @(posedge clk) begin
    if (~resetn) begin
      state <= RESET;
      y_counter <= 2'b00;
    end else begin
      state <= next_state;
      if (state == MONITOR_Y) begin
        if (y) begin
          y_counter <= 2'b00; // reset if y=1, but since we're moving, optional
        end else if (y_counter < 2'b10) begin
          y_counter <= y_counter + 1;
        end
      end else begin
        y_counter <= 2'b00;
      end
    end
  end

  always @* begin
    next_state = state;
    case (state)
      RESET: begin
        if (resetn) next_state = SET_F;
      end
      SET_F: next_state = MONITOR_X0;
      MONITOR_X0: begin
        if (x == 1'b1) next_state = MONITOR_X1;
        // else stay
      end
      MONITOR_X1: begin
        if (x == 1'b0) next_state = MONITOR_X2;
        else next_state = MONITOR_X0;
      end
      MONITOR_X2: begin
        if (x == 1'b1) next_state = MONITOR_X3;
        else next_state = MONITOR_X0;
      end
      MONITOR_X3: next_state = MONITOR_Y;
      MONITOR_Y: begin
        if (y == 1'b1) next_state = DONE_G1;
        else if (y_counter == 2'b10) next_state = DONE_G0;
        // else stay
      end
      DONE_G1: begin
        // stay forever
      end
      DONE_G0: begin
        // stay forever
      end
    endcase
  end

  always @* begin
    f = 1'b0;
    g = 1'b0;
    case (state)
      SET_F: f = 1'b1;
      MONITOR_Y: g = 1'b1;
      DONE_G1: g = 1'b1;
      // default g=0, f=0
    endcase
  end

endmodule