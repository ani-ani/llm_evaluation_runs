module string_interleave_check (
  input clk,
  input rst_n,
  input start,
  input [2:0] len_s,
  input [7:0][4:0] s,
  input [2:0] len_s1,
  input [7:0][4:0] s1,
  input [2:0] len_s2,
  input [7:0][4:0] s2,
  output reg done,
  output reg result
);

  // State encoding
  typedef enum logic [1:0] { IDLE = 2'b00, COMPUTE_ROW = 2'b01, CHECK_COMPLETE = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  // DP row registers (up to 8 chars + 1 boundary per row)
  reg [8:0] dpPrev, dpCurr; // 0..8 bits used (dpPrev[0] and dpCurr[0] always set)

  // Indices and bounds
  reg [3:0] i, j, jMax; // 4-bit to hold 0..8
  reg [3:0] len1_r, len2_r; // Registered lengths

  // Result hold (final result after full DP)
  reg result_next;

  // Next-state logic for state machine
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COMPUTE_ROW;
      end
      COMPUTE_ROW: begin
        if (i == len1_r && j == jMax) next_state = CHECK_COMPLETE;
      end
      CHECK_COMPLETE: begin
        next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Main state machine and datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= '0;
      j <= '0;
      jMax <= '0;
      len1_r <= '0;
      len2_r <= '0;
      dpPrev <= '0;
      dpCurr <= '0;
      done <= 1'b0;
      result <= 1'b0;
      result_next <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            len1_r <= len_s1;
            len2_r <= len_s2;
            jMax <= len2_r + 1; // number of columns in this run
            i <= 4'd0;
            j <= 4'd0;
            // Initialize first cell: empty prefixes interleave to form empty string
            dpPrev[0] <= 1'b1;
            dpCurr[0] <= 1'b1;
          end
          done <= 1'b0;
          result <= result_next; // hold previous result if desired
        end

        COMPUTE_ROW: begin
          // Increment j within current row
          j <= j + 1;

          if (j == 4'd0) begin
            // First column: only s2 can form s[0:i] vs empty s1
            if (s1[0][4:0] == s[i][4:0] && dpPrev[0]) dpCurr[0] <= 1'b1;
            else dpCurr[0] <= 1'b0;
          end else begin
            // dp[i][j] = (dp[i-1][j] && s1[i-1]==s[i+j-1]) || (dp[i][j-1] && s2[j-1]==s[i+j-1])
            // Note: i is the 0-based index being computed this cycle
            dpCurr[j] <= (dpPrev[j] && (s1[i][4:0] == s[i + j][4:0])) |
                         (dpCurr[j-1] && (s2[j-1][4:0] == s[i + j][4:0]));
          end

          // End of current row
          if (j == jMax) begin
            // Next row
            i <= i + 1;
            j <= 4'd0;
            dpPrev <= dpCurr;
            dpCurr[0] <= (i + 1 == 4'd0) ? 1'b1 : 1'b0; // first column of new row
          end
        end

        CHECK_COMPLETE: begin
          // Final cell: dp[len1_r][len2_r]
          result_next <= dpPrev[len2_r];
        end

        DONE: begin
          done <= 1'b1;
          result <= result_next;
        end

        default: ;
      endcase
    end
  end

endmodule
