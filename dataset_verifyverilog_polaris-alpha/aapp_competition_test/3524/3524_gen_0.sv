module string_interleave_check(
  input              clk,
  input              rst_n,
  input              start,
  input       [2:0]  len_s,
  input  [7:0][4:0]  s,
  input       [2:0]  len_s1,
  input  [7:0][4:0]  s1,
  input       [2:0]  len_s2,
  input  [7:0][4:0]  s2,
  output reg         done,
  output reg         result
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE           = 2'b00,
    COMPUTE_ROW    = 2'b01,
    CHECK_COMPLETE = 2'b10,
    DONE_STATE     = 2'b11
  } state_t;

  state_t state, next_state;

  // DP storage: single row (len_s2 up to 7 -> indices 0..7)
  reg [7:0] dp_row;       // dp_row[j]
  reg [7:0] next_dp_row;  // next row

  // Indices
  reg [2:0] i;  // current row index for s1 (0..len_s1)
  reg [2:0] j;  // current column index for s2 (0..len_s2)

  // Internal signals
  reg use_s1;
  reg use_s2;
  reg char_match_s1;
  reg char_match_s2;
  reg dp_val_from_left;
  reg dp_val_from_up;
  reg dp_current_bit;
  reg [2:0] len_s1_reg;
  reg [2:0] len_s2_reg;
  reg [2:0] len_s_reg;

  // Latch lengths at start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      len_s1_reg <= 3'd0;
      len_s2_reg <= 3'd0;
      len_s_reg  <= 3'd0;
    end else if (state == IDLE && start) begin
      len_s1_reg <= len_s1;
      len_s2_reg <= len_s2;
      len_s_reg  <= len_s;
    end
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE_ROW;
      end

      COMPUTE_ROW: begin
        // When we have processed dp[i][0..len_s2_reg] (j just finished len_s2_reg)
        if (j == len_s2_reg) begin
          next_state = CHECK_COMPLETE;
        end
      end

      CHECK_COMPLETE: begin
        // After checking completion / preparing next row, move either to DONE or COMPUTE_ROW
        if ((i == len_s1_reg) && (j == len_s2_reg)) begin
          next_state = DONE_STATE;
        end else begin
          next_state = COMPUTE_ROW;
        end
      end

      DONE_STATE: begin
        // done is 1 for one cycle, then go back to IDLE
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // DP and index update logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dp_row    <= 8'b0;
      next_dp_row <= 8'b0;
      i         <= 3'd0;
      j         <= 3'd0;
      done      <= 1'b0;
      result    <= 1'b0;
    end else begin
      done <= 1'b0; // default, one-cycle pulse in DONE_STATE

      case (state)
        IDLE: begin
          // Initialize when start
          if (start) begin
            // Quick length check: if len_s != len_s1 + len_s2, impossible
            if (len_s != (len_s1 + len_s2)) begin
              // Directly go to DONE with result=0 in sequence via state machine
              dp_row    <= 8'b0;
              next_dp_row <= 8'b0;
              i         <= 3'd0;
              j         <= 3'd0;
              result    <= 1'b0;
            end else begin
              // Initialize dp[0][0] = 1
              // Also compute first row for i=0 (using only s2)
              dp_row        <= 8'b0;
              dp_row[0]     <= 1'b1; // dp[0][0]

              // Prepare for computing row 0 columns sequentially in COMPUTE_ROW
              i             <= 3'd0;
              j             <= 3'd0;
              next_dp_row   <= 8'b0;
              result        <= 1'b0;
            end
          end else begin
            // stay idle
            dp_row      <= dp_row;
            next_dp_row <= next_dp_row;
            i           <= i;
            j           <= j;
            result      <= result;
          end
        end

        COMPUTE_ROW: begin
          // We compute dp[i][j] for current i,j.
          // dp_row holds previous row when i>0, or current row for i=0.
          // next_dp_row accumulates row i when i>0; for i=0 we update dp_row directly.

          // Determine matches for choosing from s1/s2
          // s index is i+j
          use_s1 = (i > 0);
          use_s2 = (j > 0);

          char_match_s1 = 1'b0;
          char_match_s2 = 1'b0;

          if (use_s1 && ((i + j) <= 3'd7)) begin
            char_match_s1 = (s[i + j] == s1[i - 1]);
          end

          if (use_s2 && ((i + j) <= 3'd7)) begin
            char_match_s2 = (s[i + j] == s2[j - 1]);
          end

          // dp[i][j-1] is from same row being built
          dp_val_from_left = 1'b0;
          if (use_s2) begin
            if (i == 0)
              dp_val_from_left = dp_row[j - 1];
            else
              dp_val_from_left = next_dp_row[j - 1];
          end

          // dp[i-1][j] is from previous row (dp_row) when i>0
          dp_val_from_up = 1'b0;
          if (use_s1) begin
            dp_val_from_up = dp_row[j];
          end

          // Compute current dp bit
          dp_current_bit = 1'b0;
          if (i == 0 && j == 0) begin
            dp_current_bit = 1'b1; // already set at init, but keep definition consistent
          end else begin
            if (char_match_s1 && dp_val_from_up)
              dp_current_bit = 1'b1;
            if (char_match_s2 && dp_val_from_left)
              dp_current_bit = 1'b1;
          end

          // Store dp[i][j]
          if (i == 0) begin
            // First row uses only s2, store directly into dp_row
            dp_row[j] <= dp_current_bit;
          end else begin
            // For i>0, build in next_dp_row
            next_dp_row[j] <= dp_current_bit;
          end

          // Advance column index j
          if (j < len_s2_reg) begin
            j <= j + 3'd1;
          end else begin
            // j will be len_s2_reg at end of this cycle; transition handled in CHECK_COMPLETE
            j <= j;
          end
        end

        CHECK_COMPLETE: begin
          // At entry: dp for row i and all j (0..len_s2_reg) computed.
          // For i>0, move next_dp_row into dp_row.
          if (i > 0) begin
            dp_row <= next_dp_row;
          end

          // If we are at final cell (i==len_s1_reg, j==len_s2_reg), capture result.
          if ((i == len_s1_reg) && (j == len_s2_reg)) begin
            result <= dp_row[len_s2_reg];
          end

          // Prepare next indices
          if (i < len_s1_reg) begin
            i <= i + 3'd1;
            j <= 3'd0;
          end else begin
            // Stay as is when final row reached; DONE_STATE will follow
            i <= i;
            j <= j;
          end
        end

        DONE_STATE: begin
          done   <= 1'b1; // one-cycle pulse
          // Hold result as latched in CHECK_COMPLETE
          // Prepare for IDLE on next cycle
        end

        default: begin
          // Safety defaults
          dp_row      <= 8'b0;
          next_dp_row <= 8'b0;
          i           <= 3'd0;
          j           <= 3'd0;
          done        <= 1'b0;
          result      <= 1'b0;
        end
      endcase
    end
  end

endmodule