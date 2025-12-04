module optimal_cycling(
  input clk,
  input rst_n,
  input start,
  input [3:0] T,
  input [31:0] c_fp,
  input [31:0] d_fp,
  input [7:0] rain [0:15],
  output reg [31:0] min_wetness_fp,
  output reg done
);

  // Speed ROM: Q16.16 format for 5,10,15,20,25,30 km/h
  // 5  km/h = 5 << 16, etc.
  localparam [31:0] SPEED_ROM [0:7] = '{
    32'd327680,   // 5  * 65536
    32'd655360,   // 10 * 65536
    32'd983040,   // 15 * 65536
    32'd1310720,  // 20 * 65536
    32'd1638400,  // 25 * 65536
    32'd1966080,  // 30 * 65536
    32'd1966080,  // duplicate (unused but keeps 8 entries)
    32'd1966080   // duplicate (unused but keeps 8 entries)
  };

  // State machine
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_DIV_PREP  = 3'd2,
    S_DIV_RUN   = 3'd3,
    S_COMPUTE   = 3'd4,
    S_NEXT      = 3'd5,
    S_DONE      = 3'd6
  } state_t;

  state_t state, next_state;

  // Indices
  reg [3:0] leave_idx;   // 0..15
  reg [2:0] speed_idx;   // 0..7

  // Latched inputs
  reg [3:0] T_reg;
  reg [31:0] c_fp_reg;
  reg [31:0] d_fp_reg;

  // Division (sequential) for travel_time = d_fp / speed_fp
  // Simple restoring divider: 32-bit unsigned
  reg [31:0] div_numerator;
  reg [31:0] div_denominator;
  reg [63:0] div_remainder;
  reg [31:0] div_quotient;
  reg [5:0]  div_cnt; // up to 32
  reg        div_busy;

  // Computation temporaries
  reg [31:0] speed_fp;
  reg [63:0] speed_sq;          // speed^2
  reg [63:0] sweat_mul1;        // c_fp * speed^2 (partial, wide)
  reg [63:0] sweat_mul2;        // sweat_mul1 * travel_time (partial)
  reg [31:0] travel_time_fp;    // result of division (Q16.16)
  reg [31:0] sweat_fp;

  // Rain computation
  reg [31:0] rain_sum_fp;       // Q16.16
  reg [4:0]  rain_minute_idx;   // up to 31
  reg [31:0] covered_time_fp;   // Q16.16 elapsed time since departure
  reg [31:0] accumulated_time_fp;

  // Total wetness for current combo
  reg [31:0] total_wetness_fp;

  // Minimum tracking
  reg [31:0] current_min_fp;
  reg        first_valid;

  // Helper: Q16.16 constants
  localparam [31:0] ONE_MIN_FP = 32'd65536; // 1.0 in Q16.16

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main FSM next-state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end

      S_INIT: begin
        if (T_reg != 0) next_state = S_DIV_PREP;
        else next_state = S_DONE; // degenerate
      end

      S_DIV_PREP: begin
        // Prepare and go to run divider
        next_state = S_DIV_RUN;
      end

      S_DIV_RUN: begin
        if (!div_busy) next_state = S_COMPUTE;
      end

      S_COMPUTE: begin
        // After computing wetness for this combo, advance
        next_state = S_NEXT;
      end

      S_NEXT: begin
        // Decide whether more combinations exist
        if ((leave_idx + 1'b1) < T_reg || (speed_idx + 1'b1) < 3'd7) begin
          // More combos remain
          next_state = S_DIV_PREP;
        end else begin
          // All combinations done
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        // Stay until start goes low then high again
        if (!start) next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Control and datapath
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      T_reg            <= 4'd0;
      c_fp_reg         <= 32'd0;
      d_fp_reg         <= 32'd0;
      leave_idx        <= 4'd0;
      speed_idx        <= 3'd0;
      div_numerator    <= 32'd0;
      div_denominator  <= 32'd1;
      div_remainder    <= 64'd0;
      div_quotient     <= 32'd0;
      div_cnt          <= 6'd0;
      div_busy         <= 1'b0;
      speed_fp         <= 32'd0;
      speed_sq         <= 64'd0;
      sweat_mul1       <= 64'd0;
      sweat_mul2       <= 64'd0;
      travel_time_fp   <= 32'd0;
      sweat_fp         <= 32'd0;
      rain_sum_fp      <= 32'd0;
      rain_minute_idx  <= 5'd0;
      covered_time_fp  <= 32'd0;
      accumulated_time_fp <= 32'd0;
      total_wetness_fp <= 32'd0;
      current_min_fp   <= 32'hFFFFFFFF;
      first_valid      <= 1'b0;
      min_wetness_fp   <= 32'd0;
      done             <= 1'b0;
    end else begin
      done <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch inputs
            T_reg          <= T;
            c_fp_reg       <= c_fp;
            d_fp_reg       <= d_fp;
            leave_idx      <= 4'd0;
            speed_idx      <= 3'd0;
            current_min_fp <= 32'hFFFFFFFF;
            first_valid    <= 1'b0;
          end
        end

        S_INIT: begin
          // Nothing heavy; preparation for first combo
          // Indices already zeroed in IDLE
        end

        S_DIV_PREP: begin
          // Load speed from ROM
          speed_fp <= SPEED_ROM[speed_idx];

          // Prepare divider: travel_time_fp = d_fp / speed_fp
          div_numerator   <= d_fp_reg;
          div_denominator <= (SPEED_ROM[speed_idx] != 0) ? SPEED_ROM[speed_idx][31:0] : 32'd1;
          div_remainder   <= 64'd0;
          div_quotient    <= 32'd0;
          div_cnt         <= 6'd32;
          div_busy        <= 1'b1;
        end

        S_DIV_RUN: begin
          if (div_busy) begin
            // One-bit-per-cycle restoring division (unsigned)
            // Shift remainder left, bring in MSB of numerator
            div_remainder <= {div_remainder[62:0], div_numerator[31]};
            div_numerator <= {div_numerator[30:0], 1'b0};

            if (div_remainder[63:32] >= div_denominator) begin
              div_remainder[63:32] <= div_remainder[63:32] - div_denominator;
              div_quotient <= {div_quotient[30:0], 1'b1};
            end else begin
              div_quotient <= {div_quotient[30:0], 1'b0};
            end

            if (div_cnt == 6'd1) begin
              div_busy <= 1'b0;
            end
            div_cnt <= div_cnt - 6'd1;
          end

          if (!div_busy) begin
            // Capture final quotient as travel_time_fp
            travel_time_fp <= div_quotient;
          end
        end

        S_COMPUTE: begin
          // 1) Sweat component: c_fp * speed^2 * travel_time
          // speed_sq = speed_fp * speed_fp (Q16.16 * Q16.16 = Q32.32)
          speed_sq <= speed_fp * speed_fp;

          // sweat_mul1 = c_fp * speed_sq (Q16.16 * Q32.32 = Q48.48)
          sweat_mul1 <= c_fp_reg * speed_sq;

          // sweat_mul2 = sweat_mul1 * travel_time (Q48.48 * Q16.16 = Q64.64)
          sweat_mul2 <= sweat_mul1 * travel_time_fp;

          // Reduce back to Q16.16: take middle bits [47:16]
          sweat_fp <= sweat_mul2[47:16];

          // 2) Rain component
          // We approximate: rain_wetness = sum_over_minutes (rain[minute] * fraction_covered)
          // Using Q16.16: rain_intensity (0-100) treated as integer, scaled by fraction
          // Compute based on leave_idx and travel_time_fp.

          rain_sum_fp         <= 32'd0;
          accumulated_time_fp <= 32'd0;
          rain_minute_idx     <= leave_idx;

          // Iterate through minutes until travel_time covered (unrolled sequentially in future cycles)
          // For this design, we compute in a simple loop combinationally for clarity.
          // Note: Implementation keeps it in this clock (single-cycle) for simplicity.

          begin : RAIN_CALC
            integer m;
            reg [31:0] remaining_fp;
            reg [31:0] frac_fp;
            reg [31:0] local_rain_sum;
            reg [31:0] start_min_fp;
            reg [31:0] end_min_fp;
            reg [31:0] cov_start_fp;
            reg [31:0] cov_end_fp;
            reg [31:0] covered_fp;
            local_rain_sum = 32'd0;
            remaining_fp   = travel_time_fp;

            for (m = 0; m < 16; m = m + 1) begin
              if (remaining_fp == 32'd0) begin
                // no more coverage
              end else begin
                if ((leave_idx + m[3:0]) < 16) begin
                  start_min_fp = (leave_idx + m[3:0]);
                  start_min_fp = start_min_fp * ONE_MIN_FP;
                  end_min_fp   = start_min_fp + ONE_MIN_FP;

                  // overlap with [leave_idx, leave_idx + travel_time]
                  cov_start_fp = (m == 0) ? (leave_idx * ONE_MIN_FP) : start_min_fp;
                  cov_end_fp   = (travel_time_fp + leave_idx * ONE_MIN_FP < end_min_fp) ?
                                 (travel_time_fp + leave_idx * ONE_MIN_FP) : end_min_fp;

                  if (cov_end_fp > cov_start_fp) begin
                    covered_fp = cov_end_fp - cov_start_fp;
                    if (covered_fp > remaining_fp) covered_fp = remaining_fp;
                    // fraction = covered_fp / 1min
                    frac_fp = covered_fp; // since 1min = 1.0 in this Q16.16 scale
                    // contribution = rain * frac_fp
                    local_rain_sum = local_rain_sum + (rain[leave_idx + m[3:0]] * frac_fp);
                    if (remaining_fp > covered_fp)
                      remaining_fp = remaining_fp - covered_fp;
                    else
                      remaining_fp = 32'd0;
                  end
                end
              end
            end

            rain_sum_fp <= local_rain_sum;
          end

          // 3) Total wetness
          total_wetness_fp <= sweat_fp + rain_sum_fp;

          // 4) Update minimum
          if (!first_valid || (total_wetness_fp < current_min_fp)) begin
            current_min_fp <= total_wetness_fp;
            first_valid    <= 1'b1;
          end
        end

        S_NEXT: begin
          // Advance speed index, then leave index when speeds exhausted
          if (speed_idx < 3'd7) begin
            speed_idx <= speed_idx + 3'd1;
          end else begin
            speed_idx <= 3'd0;
            if ((leave_idx + 1'b1) < T_reg)
              leave_idx <= leave_idx + 4'd1;
          end
        end

        S_DONE: begin
          // Latch result and assert done (one cycle)
          min_wetness_fp <= current_min_fp;
          done           <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule