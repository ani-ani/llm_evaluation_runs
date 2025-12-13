module monstermind_score_calculator(
  input clk,
  input rst_n,
  input start,
  input [3:0] t,
  input [1:0] n,
  input [4:0] wcnt0,
  input [4:0] wcnt1,
  input [4:0] wcnt2,
  input [4:0] wcnt3,
  output reg [31:0] expected_score,
  output reg done
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam CALC_UNIQUE = 3'd1;
  localparam FIND_MAX    = 3'd2;
  localparam COMPUTE     = 3'd3;
  localparam DONE_STATE  = 3'd4;

  reg [2:0] state, next_state;

  // Internal registers
  reg [3:0] t_reg;
  reg [1:0] n_reg;
  reg [4:0] wcnt [0:3];

  // Loop / computation variables
  reg [3:0] s;                   // current interrupt time (1..t)
  reg [2:0] unique_count;        // up to 4
  reg [31:0] inv_n;              // Q16.16 reciprocal of n
  reg [31:0] best_value;         // Q16.16 best objective value
  reg [3:0]  best_s;

  // COMPTUE stage accum
  reg [31:0] tmp1;
  reg [31:0] tmp2;

  // control flags
  reg start_d;

  // Precompute reciprocal of n in Q16.16
  // n is 1..4 (2-bit). Use combinational logic.
  always @(*) begin
    case (n_reg)
      2'd1: inv_n = 32'h00010000; // 1.0
      2'd2: inv_n = 32'h00008000; // 0.5
      2'd3: inv_n = 32'h00005555; // 1/3 approx 0.333333
      2'd4: inv_n = 32'h00004000; // 0.25
      default: inv_n = 32'h00000000;
    endcase
  end

  // Sequential state / registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      t_reg           <= 4'd0;
      n_reg           <= 2'd0;
      wcnt[0]         <= 5'd0;
      wcnt[1]         <= 5'd0;
      wcnt[2]         <= 5'd0;
      wcnt[3]         <= 5'd0;
      s               <= 4'd0;
      unique_count    <= 3'd0;
      best_value      <= 32'd0;
      best_s          <= 4'd0;
      expected_score  <= 32'd0;
      done            <= 1'b0;
      tmp1            <= 32'd0;
      tmp2            <= 32'd0;
      start_d         <= 1'b0;
    end else begin
      state   <= next_state;
      start_d <= start;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && !start_d) begin
            // Latch inputs on start pulse
            t_reg    <= t;
            n_reg    <= (n == 2'd0) ? 2'd1 : n; // guard against zero
            wcnt[0]  <= wcnt0;
            wcnt[1]  <= wcnt1;
            wcnt[2]  <= wcnt2;
            wcnt[3]  <= wcnt3;
            s        <= 4'd1;
            best_value <= 32'd0;
            best_s     <= 4'd1;
          end
        end

        CALC_UNIQUE: begin
          // Compute unique_count for current s (combinational later)
          // Nothing sequential besides potential capture if needed
        end

        FIND_MAX: begin
          // Compare current objective to best and update
          // tmp1 and tmp2 captured here based on CALC_UNIQUE results
          if (tmp2 > best_value) begin
            best_value <= tmp2;
            best_s     <= s;
          end
          // Increment s
          s <= s + 4'd1;
        end

        COMPUTE: begin
          // Final expected_score = best_value (already Q16.16)
          expected_score <= best_value;
        end

        DONE_STATE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Combinational next_state logic and combinational math
  always @(*) begin
    next_state = state;

    // default temps
    tmp1 = 32'd0;
    tmp2 = 32'd0;
    unique_count = 3'd0;

    case (state)
      IDLE: begin
        if (start && !start_d) begin
          // If t < 1 then no valid interrupt; score = 0, go DONE
          if (t == 4'd0)
            next_state = COMPUTE;
          else
            next_state = CALC_UNIQUE;
        end
      end

      CALC_UNIQUE: begin
        // Compute unique_count for current s
        // Count how many questions have word_count <= s
        // (treat as having a unique prefix at time s)
        if (wcnt[0] <= s) unique_count = unique_count + 3'd1;
        if (wcnt[1] <= s) unique_count = unique_count + 3'd1;
        if (wcnt[2] <= s) unique_count = unique_count + 3'd1;
        if (wcnt[3] <= s) unique_count = unique_count + 3'd1;

        // Compute objective(s) = (unique_count / n) * (1 + remaining_time)
        // remaining_time = t_reg - s - 1 (1s answer time)
        // If negative, clamp to 0.
        // Implement in Q16.16:
        // score_frac = unique_count * inv_n (Q16.16)
        // time_factor = (1 + rem) as integer => shift left 16
        // objective = (score_frac * time_factor) >> 16

        // time_factor
        if (t_reg > s + 4'd1) begin
          // remaining_time = t_reg - s - 1
          tmp1 = {16'd0, (16'd1 + (t_reg - s - 4'd1))};
        end else begin
          tmp1 = {16'd0, 16'd1}; // 1.0 if no remaining positive time
        end

        // score_frac = unique_count * inv_n
        tmp2 = unique_count * inv_n; // Q16.16

        // objective = (score_frac * time_factor) >> 16
        tmp2 = (tmp2 * tmp1) >> 16;

        next_state = FIND_MAX;
      end

      FIND_MAX: begin
        // Decide whether to continue or move to COMPUTE
        if (s >= t_reg) begin
          next_state = COMPUTE;
        end else begin
          next_state = CALC_UNIQUE;
        end
      end

      COMPUTE: begin
        next_state = DONE_STATE;
      end

      DONE_STATE: begin
        // Stay in DONE until next start pulse
        if (start && !start_d) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule