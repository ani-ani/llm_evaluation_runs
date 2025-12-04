module canyon_mapper(
  input clk,
  input rst_n,
  input start,
  input signed [15:0] x0, y0, x1, y1, x2, y2, x3, y3,
  output reg [31:0] side_length,
  output reg done
);

  localparam TCQ = 1;
  localparam COUNT_MAX = 10; // pipeline depth: output valid after 10 cycles

  // State
  typedef enum logic {IDLE = 1'b0, RUN = 1'b1} state_t;
  state_t state, state_next;
  integer cycle, cycle_next;

  // Input capture (latched on start)
  reg signed [15:0] x0_r, y0_r, x1_r, y1_r, x2_r, y2_r, x3_r, y3_r;

  // Bounding box results in Q16.16 (convert from Q8.8 by << 8)
  reg signed [31:0] min_x_q16, min_y_q16, max_x_q16, max_y_q16;
  reg signed [31:0] width_q16, height_q16, side_q16;

  // Internal next-state wires
  wire [31:0] side_length_next;
  wire done_next;

  // Register all outputs (required to be 'reg' by spec)
  assign side_length_next = side_q16[31:0];
  assign done_next = (state_next == IDLE) ? 1'b0 : 1'b1; // high when computation complete

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle <= 0;
      // Latch
      x0_r <= 0; y0_r <= 0; x1_r <= 0; y1_r <= 0; x2_r <= 0; y2_r <= 0; x3_r <= 0; y3_r <= 0;
      // Outputs
      side_length <= 32'h0;
      done <= 1'b0;
    end else begin
      state <= state_next;
      cycle <= cycle_next;
      if (state == IDLE && start) begin
        x0_r <= x0; y0_r <= y0;
        x1_r <= x1; y1_r <= y1;
        x2_r <= x2; y2_r <= y2;
        x3_r <= x3; y3_r <= y3;
      end
      side_length <= side_length_next;
      done <= done_next;
    end
  end

  // Compute bounding box on start (single cycle combinational)
  always_comb begin
    // Promote to signed 31-bit and convert to Q16.16 by << 8
    signed [31:0] x0_s = $signed(x0_r) << 8;
    signed [31:0] y0_s = $signed(y0_r) << 8;
    signed [31:0] x1_s = $signed(x1_r) << 8;
    signed [31:0] y1_s = $signed(y1_r) << 8;
    signed [31:0] x2_s = $signed(x2_r) << 8;
    signed [31:0] y2_s = $signed(y2_r) << 8;
    signed [31:0] x3_s = $signed(x3_r) << 8;
    signed [31:0] y3_s = $signed(y3_r) << 8;

    // Reduce for min/max using signed comparison
    signed [31:0] min_x = (((x0_s < x1_s) ? x0_s : x1_s) < x2_s) ? ((x0_s < x1_s) ? x0_s : x1_s) : x2_s;
    min_x = (min_x < x3_s) ? min_x : x3_s;

    signed [31:0] max_x = (((x0_s > x1_s) ? x0_s : x1_s) > x2_s) ? ((x0_s > x1_s) ? x0_s : x1_s) : x2_s;
    max_x = (max_x > x3_s) ? max_x : x3_s;

    signed [31:0] min_y = (((y0_s < y1_s) ? y0_s : y1_s) < y2_s) ? ((y0_s < y1_s) ? y0_s : y1_s) : y2_s;
    min_y = (min_y < y3_s) ? min_y : y3_s;

    signed [31:0] max_y = (((y0_s > y1_s) ? y0_s : y1_s) > y2_s) ? ((y0_s > y1_s) ? y0_s : y1_s) : y2_s;
    max_y = (max_y > y3_s) ? max_y : y3_s;

    // Bounding box
    signed [31:0] width  = max_x - min_x; // Q16.16
    signed [31:0] height = max_y - min_y; // Q16.16

    // Side length is max(width, height) in Q16.16
    signed [31:0] side = (width > height) ? width : height;

    min_x_q16 = min_x;
    min_y_q16 = min_y;
    max_x_q16 = max_x;
    max_y_q16 = max_y;
    width_q16 = width;
    height_q16 = height;
    side_q16 = side;
  end

  // Control logic: pipeline 10 cycles
  always_comb begin
    state_next = state;
    cycle_next = cycle;
    case (state)
      IDLE: begin
        cycle_next = 0;
        if (start) begin
          state_next = RUN;
          cycle_next = 0;
        end
      end
      RUN: begin
        if (cycle == COUNT_MAX) begin
          state_next = IDLE;
          cycle_next = 0;
        end else begin
          cycle_next = cycle + 1;
        end
      end
    endcase
  end

endmodule