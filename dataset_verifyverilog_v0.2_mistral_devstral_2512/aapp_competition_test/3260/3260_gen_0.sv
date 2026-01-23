module perm_run_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [3:0] k,
  input [31:0] p,
  output reg [31:0] result,
  output reg done
);

  // State encoding
  localparam STATE_IDLE = 0;
  localparam STATE_SETUP = 1;
  localparam STATE_PROCESSING = 2;
  localparam STATE_DONE = 3;

  // State registers
  reg [1:0] state;
  reg [15:0] mask;
  reg [3:0] last;
  reg [2:0] run_len;
  reg [31:0] dp [0:65535][0:15][0:3];
  reg [31:0] sum;
  reg [15:0] mask_iter;
  reg [3:0] last_iter;
  reg [2:0] run_len_iter;
  reg [3:0] new_last;
  reg [2:0] new_run_len;
  reg [15:0] new_mask;
  reg [31:0] temp;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      mask <= 0;
      last <= 0;
      run_len <= 0;
      result <= 0;
      done <= 0;
      mask_iter <= 0;
      last_iter <= 0;
      run_len_iter <= 0;
      sum <= 0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (start) begin
            state <= STATE_SETUP;
          end
        end
        STATE_SETUP: begin
          // Initialize DP table
          dp[0][0][0] <= 1;
          mask <= 0;
          last <= 0;
          run_len <= 0;
          mask_iter <= 0;
          last_iter <= 0;
          run_len_iter <= 0;
          sum <= 0;
          state <= STATE_PROCESSING;
        end
        STATE_PROCESSING: begin
          // Iterate through all possible states
          if (mask_iter == (1 << n) - 1) begin
            // Sum all final states
            for (last_iter = 0; last_iter < n; last_iter = last_iter + 1) begin
              for (run_len_iter = 0; run_len_iter <= k; run_len_iter = run_len_iter + 1) begin
                sum = (sum + dp[(1 << n) - 1][last_iter][run_len_iter]) % p;
              end
            end
            result <= sum;
            done <= 1;
            state <= STATE_DONE;
          end else begin
            // Process current state
            if (dp[mask_iter][last_iter][run_len_iter] != 0) begin
              for (new_last = 0; new_last < n; new_last = new_last + 1) begin
                if (!(mask_iter[new_last])) begin
                  // Check if new_last extends the run
                  if (last_iter == 0 || (new_last == last_iter + 1) || (new_last == last_iter - 1)) begin
                    new_run_len = run_len_iter + 1;
                  end else begin
                    new_run_len = 1;
                  end
                  if (new_run_len <= k) begin
                    new_mask = mask_iter | (1 << new_last);
                    temp = (dp[mask_iter][last_iter][run_len_iter] + dp[new_mask][new_last][new_run_len]) % p;
                    dp[new_mask][new_last][new_run_len] <= temp;
                  end
                end
              end
            end
            // Increment iterators
            if (run_len_iter == k) begin
              if (last_iter == n - 1) begin
                mask_iter <= mask_iter + 1;
                last_iter <= 0;
                run_len_iter <= 0;
              end else begin
                last_iter <= last_iter + 1;
                run_len_iter <= 0;
              end
            end else begin
              run_len_iter <= run_len_iter + 1;
            end
          end
        end
        STATE_DONE: begin
          if (!start) begin
            done <= 0;
            state <= STATE_IDLE;
          end
        end
      endcase
    end
  end

endmodule