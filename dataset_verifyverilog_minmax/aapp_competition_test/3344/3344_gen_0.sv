module luggage_speed_calculator (
  input clk,
  input rst_n,
  input start,
  input [31:0] L_fixed,
  input [31:0] positions [0:7],
  input [2:0] num_items,
  output reg [31:0] speed_fixed,
  output reg done,
  output reg valid
);

  // Internal state
  typedef enum logic [2:0] {
    IDLE     = 3'd0,
    SORT     = 3'd1,
    GAP1     = 3'd2,
    DIV1     = 3'd3,
    GAP2     = 3'd4,
    DIV2     = 3'd5,
    FINALIZE = 3'd6
  } state_t;

  state_t state;

  // Sorting workspace (bubble sort, 8 elements, 7 passes max)
  reg [31:0] sort_positions [0:7];
  reg [2:0] sort_pass;  // 0..6 (0-based passes)
  reg [2:0] sort_j;     // comparison index 0..6
  reg [31:0] L_q;       // saved L_fixed
  reg [2:0] n_q;        // saved num_items
  reg [7:0] cycle_cnt;  // up to 128 cycles (7 bits)

  // Gap computation
  reg [2:0] gap_idx;    // 0..(n-2) for adjacent gaps, n-1 for wrap-around
  reg [31:0] g_q;       // current gap (Q16.16)
  reg [31:0] L_div_g_q; // L/g
  reg [31:0] min_speed_q;
  reg [2:0] n_minus_1;
  reg any_valid;
  reg wrap_valid;
  reg [2:0] compare_cnt;

  // Constants (Q16.16)
  localparam [31:0] C_ONE        = 32'h00010000; // 1.0
  localparam [31:0] C_SAFETY     = 32'h00010000; // 1.0
  localparam [31:0] C_MIN_SPEED  = 32'h00019999; // 0.1  (0x00019999)
  localparam [31:0] C_MAX_SPEED  = 32'h00A00000; // 10.0 (0x00A00000)
  localparam [31:0] C_INVALID    = 32'hFFFFFFFF; // "no fika" indicator

  // Main FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      sort_pass   <= 3'd0;
      sort_j      <= 3'd0;
      L_q         <= 32'd0;
      n_q         <= 3'd0;
      gap_idx     <= 3'd0;
      g_q         <= 32'd0;
      L_div_g_q   <= 32'd0;
      min_speed_q <= 32'd0;
      n_minus_1   <= 3'd0;
      any_valid   <= 1'b0;
      wrap_valid  <= 1'b0;
      compare_cnt <= 3'd0;
      cycle_cnt   <= 8'd0;
      speed_fixed <= C_INVALID;
      done        <= 1'b0;
      valid       <= 1'b0;
      sort_positions[0] <= 32'd0;
      sort_positions[1] <= 32'd0;
      sort_positions[2] <= 32'd0;
      sort_positions[3] <= 32'd0;
      sort_positions[4] <= 32'd0;
      sort_positions[5] <= 32'd0;
      sort_positions[6] <= 32'd0;
      sort_positions[7] <= 32'd0;
    end else begin
      // Default: keep outputs low during computation
      done  <= 1'b0;
      valid <= 1'b0;

      case (state)
        IDLE: begin
          cycle_cnt <= 8'd0;
          if (start) begin
            // Capture inputs
            L_q     <= L_fixed;
            n_q     <= (num_items == 3'd0) ? 3'd1 : (num_items > 3'd8 ? 3'd8 : num_items);
            // Initialize sorting workspace with the first n_q values from positions
            sort_positions[0] <= positions[0];
            sort_positions[1] <= positions[1];
            sort_positions[2] <= positions[2];
            sort_positions[3] <= positions[3];
            sort_positions[4] <= positions[4];
            sort_positions[5] <= positions[5];
            sort_positions[6] <= positions[6];
            sort_positions[7] <= positions[7];
            sort_pass <= 3'd0;
            sort_j    <= 3'd0;
            state     <= SORT;
          end
        end

        // Bubble sort: 7 passes, up to 7 comparisons per pass -> at most 49 cycles
        SORT: begin
          cycle_cnt <= cycle_cnt + 1;
          if (sort_pass < 3'd7) begin
            if (sort_j < 3'd6) begin
              // Compare positions[sort_j] and positions[sort_j+1]
              if ($signed(sort_positions[sort_j]) > $signed(sort_positions[sort_j + 1])) begin
                // Swap if out of order
                L_div_g_q <= sort_positions[sort_j];
                sort_positions[sort_j]     <= sort_positions[sort_j + 1];
                sort_positions[sort_j + 1] <= L_div_g_q;
              end
              sort_j <= sort_j + 1;
            end else begin
              // End of current pass
              sort_j    <= 3'd0;
              sort_pass <= sort_pass + 1;
            end
          end else begin
            // Sorting complete, begin gap/speed computation
            n_minus_1   <= n_q - 3'd1;
            gap_idx     <= 3'd0;
            min_speed_q <= C_MAX_SPEED; // Start with max allowed as worst-case
            any_valid   <= 1'b0;
            wrap_valid  <= 1'b0;
            compare_cnt <= 3'd0;
            state       <= GAP1;
          end
        end

        // Gap calculation - 2 states (compute gap, then divide)
        GAP1: begin
          cycle_cnt <= cycle_cnt + 1;
          // Compute gap between sorted[i] and sorted[i+1]
          if (gap_idx < n_minus_1) begin
            g_q <= $signed(sort_positions[gap_idx + 1]) - $signed(sort_positions[gap_idx]);
          end else begin
            // Wrap-around gap: L + sorted[0] - sorted[n-1]
            g_q <= $signed(L_q) + $signed(sort_positions[0]) - $signed(sort_positions[n_q - 1]);
          end
          state <= DIV1;
        end

        DIV1: begin
          cycle_cnt <= cycle_cnt + 1;
          // Check gap validity: must exceed safety margin (1.0 m)
          if ($signed(g_q) > $signed(C_SAFETY)) begin
            // Compute L / g (Q16.16 / Q16.16 => Q16.16)
            L_div_g_q <= L_q / g_q;
            any_valid <= 1'b1;
          end else begin
            L_div_g_q <= C_MAX_SPEED; // Not valid; use a high value to exclude
          end
          state <= GAP2;
        end

        GAP2: begin
          cycle_cnt <= cycle_cnt + 1;
          // Update minimum speed
          if (L_div_g_q < min_speed_q) begin
            min_speed_q <= L_div_g_q;
          end
          // If current gap is wrap-around, set flag
          if (gap_idx == n_minus_1) begin
            wrap_valid <= ($signed(g_q) > $signed(C_SAFETY));
          end
          // Progress to next gap or finalize
          if (gap_idx < n_minus_1) begin
            gap_idx <= gap_idx + 1;
            state   <= GAP1;
          end else begin
            // Finished all gaps; finalize
            state <= FINALIZE;
          end
        end

        FINALIZE: begin
          cycle_cnt <= cycle_cnt + 1;
          if (any_valid) begin
            // Clamp speed between MIN and MAX
            if ($signed(min_speed_q) < $signed(C_MIN_SPEED)) begin
              speed_fixed <= C_MIN_SPEED;
            end else if ($signed(min_speed_q) > $signed(C_MAX_SPEED)) begin
              speed_fixed <= C_MAX_SPEED;
            end else begin
              speed_fixed <= min_speed_q;
            end
            valid <= 1'b1;
          end else begin
            speed_fixed <= C_INVALID;
            valid       <= 1'b0;
          end
          done  <= 1'b1;
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
