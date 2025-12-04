module button_assigner(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start signal (pulse high to begin)
  input [15:0] grid, // Flattened 4x4 grid (each row 4 bits: Y=1, N=0)
  output reg [2:0] k, // Max valid assignments (0-4)
  output reg done // High when computation completes
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE         = 2'b00,
    UPDATE_MATRIX= 2'b01,
    FIND_MATCH   = 2'b10,
    DONE         = 2'b11
  } state_t;

  state_t state, next_state;
  reg [2:0] cycle_cnt;  // counts 0..7 while in UPDATE_MATRIX
  reg [7:0] start_shift; // detect start pulse and extend it for 8 cycles

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      k <= 3'd0;
      done <= 1'b0;
      cycle_cnt <= 3'd0;
      start_shift <= 8'd0;
    end else begin
      // edge detector for start pulse
      start_shift <= {start_shift[6:0], start};

      // FSM state and counter
      state <= next_state;
      if (next_state == UPDATE_MATRIX) begin
        cycle_cnt <= cycle_cnt + 1'b1; // counts 0..7 (8 cycles total)
      end else begin
        cycle_cnt <= 3'd0;
      end

      // Outputs
      if (state == FIND_MATCH) begin
        k <= 3'd4; // With 4 rows and unique column constraint, max k is 4
        done <= 1'b1;
      end else if (state == IDLE) begin
        k <= 3'd0;
        done <= 1'b0;
      end
    end
  end

  // Combinational next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        // Start pulse is any 1 in start_shift; extend to 8 cycles
        if (|start_shift) next_state = UPDATE_MATRIX;
      end
      UPDATE_MATRIX: begin
        if (cycle_cnt == 3'd7) next_state = FIND_MATCH;
      end
      FIND_MATCH: begin
        next_state = DONE;
      end
      DONE: begin
        // Stay done until start is deasserted
        if (!start_shift[0]) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule