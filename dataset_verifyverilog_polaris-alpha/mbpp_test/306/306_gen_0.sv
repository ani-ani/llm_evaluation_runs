module max_inc_subseq(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0]   data [0:7],
  input      [2:0]   index,
  input      [2:0]   k,
  output reg [10:0]  max_sum,
  output reg         done
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam INIT       = 3'd1;
  localparam COMPUTE_I  = 3'd2;
  localparam COMPUTE_J  = 3'd3;
  localparam FINISH     = 3'd4;

  reg [2:0]  state, next_state;
  reg [2:0]  i, j;

  // 8x8 dp table, 11-bit entries
  reg [10:0] dp [0:7][0:7];

  // Internal signals
  reg [10:0] sum_candidate;
  reg [10:0] prev_dp_ii;
  reg [10:0] prev_dp_j;
  reg        cond_valid;

  // Sequential state/registers update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      i       <= 3'd0;
      j       <= 3'd0;
      max_sum <= 11'd0;
      done    <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done    <= 1'b0;
          max_sum <= 11'd0;
          if (start) begin
            i <= 3'd0;
            j <= 3'd0;
          end
        end

        // Initialize dp[0][j]
        INIT: begin
          if (j < 3'd8) begin
            if (data[j] > data[0])
              dp[0][j] <= data[j] + data[0];
            else
              dp[0][j] <= data[j];

            j <= j + 3'd1;
          end
        end

        // Setup for computing row i (i from 1 to 7)
        COMPUTE_I: begin
          if (i < 3'd8) begin
            j <= 3'd0;
          end
        end

        // Compute dp[i][j]
        COMPUTE_J: begin
          if (i < 3'd8 && j < 3'd8) begin
            prev_dp_ii = dp[i-1][i];
            prev_dp_j  = dp[i-1][j];

            cond_valid = (j > i) && (data[j] > data[i]);

            if (cond_valid) begin
              sum_candidate = prev_dp_ii + data[j];
              if (sum_candidate > prev_dp_j)
                dp[i][j] <= sum_candidate;
              else
                dp[i][j] <= prev_dp_j;
            end else begin
              dp[i][j] <= prev_dp_j;
            end

            j <= j + 3'd1;
          end
        end

        FINISH: begin
          // Output dp[index][k] if in range; otherwise 0
          if (index < 3'd8 && k < 3'd8)
            max_sum <= dp[index][k];
          else
            max_sum <= 11'd0;

          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic (simple sequencing to achieve required latency behaviorally)
  // Note: This FSM sequences deterministically through the phases;
  // external timing expectation is 70 cycles from start to done.
  reg [6:0] cycle_cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 7'd0;
    end else begin
      if (state == IDLE) begin
        if (start)
          cycle_cnt <= 7'd0;
      end else if (state != FINISH) begin
        cycle_cnt <= cycle_cnt + 7'd1;
      end
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        // After initializing all 8 entries of row 0, move to COMPUTE_I
        if (j == 3'd8)
          next_state = COMPUTE_I;
      end

      COMPUTE_I: begin
        // If all rows done, go to FINISH; else start COMPUTE_J for this i
        if (i >= 3'd8)
          next_state = FINISH;
        else
          next_state = COMPUTE_J;
      end

      COMPUTE_J: begin
        // When all j for this i computed, move to next i or FINISH
        if (j == 3'd8) begin
          if (i == 3'd7)
            next_state = FINISH;
          else
            next_state = COMPUTE_I;
        end
      end

      FINISH: begin
        // Stay in FINISH until new start (or external reset)
        if (start)
          next_state = INIT;
      end

      default: next_state = IDLE;
    endcase
  end

  // Increment i only when completing a row in COMPUTE_J
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 3'd0;
    end else begin
      if (state == INIT && next_state == COMPUTE_I) begin
        i <= 3'd1;
      end else if (state == COMPUTE_J && j == 3'd8 && i < 3'd7) begin
        i <= i + 3'd1;
      end else if (state == FINISH && next_state == INIT) begin
        i <= 3'd0;
      end
    end
  end

endmodule