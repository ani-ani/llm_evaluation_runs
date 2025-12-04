module apple_collector (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] p_2, p_3, p_4, p_5, p_6, p_7, p_8,
  output reg [3:0] result,
  output reg done
);

  // State encoding
  localparam IDLE = 3'b000;
  localparam CALC_DEPTHS = 3'b001;
  localparam COUNT_LEVELS = 3'b010;
  localparam SUM_PARITY = 3'b011;
  localparam DONE = 3'b100;

  // Internal signals
  reg [2:0] state, next_state;
  reg [3:0] depth [7:0]; // depth per node (0..7)
  reg [2:0] cnt;         // depth counter (0..7)
  reg parity_acc;        // parity accumulator

  // Sequential logic: state, results, and done flag
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 4'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;

      // Pipeline for results and done flag (10-cycle shift register)
      result[3:1] <= result[2:0];
      result[0] <= 1'b0;
      done <= 1'b0;
      case (state)
        IDLE: begin
          result <= 4'b0;
          done <= 1'b0;
        end
        CALC_DEPTHS: begin
          result <= 4'b0;
          done <= 1'b0;
        end
        COUNT_LEVELS: begin
          result <= 4'b0;
          done <= 1'b0;
        end
        SUM_PARITY: begin
          result <= {3'b0, parity_acc};
          done <= 1'b0;
        end
        DONE: begin
          result <= result; // hold
          done <= 1'b1;
        end
      endcase
    end
  end

  // Depth initialization
  always @(posedge clk) begin
    if (state == IDLE) begin
      depth[0] <= 4'b0; // root assumed at depth 0
      depth[1] <= 4'b0; // unused (valid n >= 3)
      depth[2] <= 4'b0;
      depth[3] <= 4'b0;
      depth[4] <= 4'b0;
      depth[5] <= 4'b0;
      depth[6] <= 4'b0;
      depth[7] <= 4'b0;
    end
  end

  // Combinational next-state logic with gating on start (avoid retrigger on same start pulse)
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start == 1'b0) begin
          next_state = CALC_DEPTHS;
        end
      end
      CALC_DEPTHS: next_state = COUNT_LEVELS;
      COUNT_LEVELS: next_state = SUM_PARITY;
      SUM_PARITY: next_state = DONE;
      DONE: begin
        if (start == 1'b0) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Compute depths when in CALC_DEPTHS
  always @(posedge clk) begin
    if (state == CALC_DEPTHS) begin
      if (n >= 3) depth[2] <= depth[p_2] + 1;
      if (n >= 4) depth[3] <= depth[p_3] + 1;
      if (n >= 5) depth[4] <= depth[p_4] + 1;
      if (n >= 6) depth[5] <= depth[p_5] + 1;
      if (n >= 7) depth[6] <= depth[p_6] + 1;
      if (n >= 8) depth[7] <= depth[p_7] + 1;
    end
  end

  // Count and parity accumulation during COUNT_LEVELS and SUM_PARITY
  always @(posedge clk) begin
    if (state == IDLE) begin
      cnt <= 3'b0;
      parity_acc <= 1'b0;
    end else if (state == COUNT_LEVELS) begin
      // Shift register to count nodes at each depth level over 8 cycles
      // Works in concert with the 10-cycle pipeline for results/done
      cnt <= cnt + 1;
      case (cnt)
        3'b000: parity_acc <= parity_acc ^ (depth[0][0]);
        3'b001: parity_acc <= parity_acc ^ (depth[1][0]);
        3'b010: parity_acc <= parity_acc ^ (depth[2][0]);
        3'b011: parity_acc <= parity_acc ^ (depth[3][0]);
        3'b100: parity_acc <= parity_acc ^ (depth[4][0]);
        3'b101: parity_acc <= parity_acc ^ (depth[5][0]);
        3'b110: parity_acc <= parity_acc ^ (depth[6][0]);
        3'b111: parity_acc <= parity_acc ^ (depth[7][0]);
      endcase
    end else if (state == SUM_PARITY) begin
      parity_acc <= parity_acc; // hold
      cnt <= 3'b0;              // reset for next run
    end else begin
      cnt <= cnt;               // hold
      parity_acc <= parity_acc; // hold
    end
  end

endmodule
