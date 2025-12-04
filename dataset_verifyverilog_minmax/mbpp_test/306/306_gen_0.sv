module max_inc_subseq (
  input clk,
  input rst_n,
  input start,
  input [7:0] data [0:7],
  input [2:0] index,
  input [2:0] k,
  output reg [10:0] max_sum,
  output reg done
);

  typedef enum logic [2:0] {IDLE, INIT, COMPUTE_I, COMPUTE_J, FINISH} state_t;
  state_t state, next_state;

  // DP table: 8x8 of 11-bit values
  reg [10:0] dp [0:7][0:7];

  // Loop counters and control
  reg [2:0] i, j;
  reg [6:0] cycle_cnt; // up to 70
  reg valid_slot;      // 1 when k > index and k < 8

  // Next-step control signals
  wire init_done = (j == 3'd7);
  wire i_row_done = (j == 3'd7);
  wire all_i_done = (i == 3'd7);

  // State register with synchronous reset
  always @(posedge clk) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Combinational state transitions
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:   next_state = start ? INIT : IDLE;
      INIT:   next_state = init_done ? COMPUTE_I : INIT;
      COMPUTE_I: next_state = i_row_done ? (all_i_done ? FINISH : COMPUTE_I) : COMPUTE_I;
      COMPUTE_J: next_state = i_row_done ? (all_i_done ? FINISH : COMPUTE_I) : COMPUTE_J;
      FINISH: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Combinational counters and DP update
  always @(*) begin
    i = 3'd0;
    j = 3'd0;
    valid_slot = (k > index) && (k < 3'd8) && (index < 3'd8);
    // Defaults: keep latches safe; actual update uses blocking assignments below
    dp[0][0] = dp[0][0];
  end

  // Iteration counters and DP update logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Clear DP and control on reset
      for (int r = 0; r < 8; r++) begin
        for (int c = 0; c < 8; c++) begin
          dp[r][c] <= 11'h0;
        end
      end
      i <= 3'd0;
      j <= 3'd0;
      cycle_cnt <= 7'd0;
      done <= 1'b0;
      max_sum <= 11'd0;
    end else begin
      done <= 1'b0;
      case (state)
        IDLE: begin
          i <= 3'd0;
          j <= 3'd0;
          cycle_cnt <= 7'd0;
          if (start) begin
            cycle_cnt <= 7'd1;
            j <= 3'd0;
            i <= 3'd0;
            // Initialize row 0
            if (data[0] < data[j]) dp[0][j] <= {3'b0, data[0]} + {3'b0, data[j]};
            else dp[0][j] <= {3'b0, data[j]};
          end
        end

        INIT: begin
          cycle_cnt <= cycle_cnt + 1;
          j <= j + 1;
          if (data[0] < data[j]) dp[0][j] <= {3'b0, data[0]} + {3'b0, data[j]};
          else dp[0][j] <= {3'b0, data[j]};
        end

        COMPUTE_I: begin
          cycle_cnt <= cycle_cnt + 1;
          i <= i + 1;
          j <= 3'd0;
          if (i > 0 && j > i && data[j] > data[i]) begin
            // dp[i][j] = max(dp[i-1][i] + data[j], dp[i-1][j])
            if (dp[i-1][i] + {3'b0, data[j]} > dp[i-1][j]) dp[i][j] <= dp[i-1][i] + {3'b0, data[j]};
            else dp[i][j] <= dp[i-1][j];
          end else begin
            dp[i][j] <= dp[i-1][j];
          end
        end

        COMPUTE_J: begin
          cycle_cnt <= cycle_cnt + 1;
          j <= j + 1;
          if (j > i && data[j] > data[i]) begin
            if (dp[i-1][i] + {3'b0, data[j]} > dp[i-1][j]) dp[i][j] <= dp[i-1][i] + {3'b0, data[j]};
            else dp[i][j] <= dp[i-1][j];
          end else begin
            dp[i][j] <= dp[i-1][j];
          end
        end

        FINISH: begin
          cycle_cnt <= cycle_cnt + 1;
          done <= 1'b1;
          if (valid_slot) max_sum <= dp[index][k];
          else max_sum <= 11'd0;
        end

        default: begin
          // Should never occur
          cycle_cnt <= cycle_cnt + 1;
        end
      endcase
    end
  end

endmodule
