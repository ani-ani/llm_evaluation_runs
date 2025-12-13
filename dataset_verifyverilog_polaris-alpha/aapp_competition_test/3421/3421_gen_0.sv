module optimal_subsequence(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] k, // min subsequence length (1-8)
  input [15:0] data, // 16-bit input string (0=wrong, 1=correct)
  output reg [3:0] first_idx, // 1-based start index (4-bit: 1-16)
  output reg [3:0] length, // subsequence length (4-bit: 1-16)
  output reg done // high when computation completes
);

  // Internal registers
  reg [4:0] prefix [0:16]; // prefix sums, 5 bits enough for 0-16
  reg [3:0] cur_len;
  reg [3:0] cur_start;

  // best tracking
  reg [4:0] best_sum;
  reg [3:0] best_len;
  reg [3:0] best_start;

  // control
  reg [4:0] i_pref;       // prefix index builder (0-16)
  reg [1:0] state;
  reg [4:0] iter_cnt;     // up to 16 for scheduling

  localparam S_IDLE  = 2'd0;
  localparam S_PREF  = 2'd1;
  localparam S_SCAN  = 2'd2;
  localparam S_DONE  = 2'd3;

  // Combinational wires for ratio comparison
  reg        better_ratio;
  reg        equal_ratio;
  reg        better_length;
  reg        earlier_start;

  reg [4:0] cur_sum;

  // Sequential FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      done       <= 1'b0;
      first_idx  <= 4'd0;
      length     <= 4'd0;
      best_sum   <= 5'd0;
      best_len   <= 4'd0;
      best_start <= 4'd0;
      cur_len    <= 4'd0;
      cur_start  <= 4'd0;
      i_pref     <= 5'd0;
      iter_cnt   <= 5'd0;
      prefix[0]  <= 5'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // initialize prefix build
            prefix[0]  <= 5'd0;
            i_pref     <= 5'd0;
            // init best trackers so first candidate always wins
            best_sum   <= 5'd0;
            best_len   <= 4'd0;
            best_start <= 4'd0;
            // schedule: we'll finish within 16 cycles
            iter_cnt   <= 5'd0;
            state      <= S_PREF;
          end
        end

        // Build prefix sums sequentially over 16 cycles
        S_PREF: begin
          // i_pref points to prefix index being filled+1 effectively
          if (i_pref < 5'd16) begin
            // next index is i_pref+1
            // data bit index = i_pref
            prefix[i_pref + 1] <= prefix[i_pref] + data[i_pref];
            i_pref <= i_pref + 5'd1;
          end
          if (i_pref == 5'd16) begin
            // finished prefix sums this cycle
            // initialize scan parameters next
            cur_len   <= k;
            cur_start <= 4'd1;
            // reset iter counter to bound total latency
            iter_cnt  <= 5'd0;
            state     <= S_SCAN;
          end
        end

        // Scan all subsequences with length >= k using prefix sums
        S_SCAN: begin
          // default done low here
          done <= 1'b0;

          // Only process while within 16-cycle budget
          if (iter_cnt < 5'd16) begin
            // Ensure valid length range
            if (cur_len >= k && cur_len <= 4'd16 && cur_start >= 4'd1 && (cur_start + cur_len - 1) <= 4'd16) begin
              // compute current sum via prefix
              cur_sum <= prefix[cur_start + cur_len - 1] - prefix[cur_start - 1];

              // Ratio comparison (cross-multiply to avoid divide):
              // cur_sum/cur_len ? best_sum/best_len
              // If best_len==0, always better.
              if (best_len == 4'd0) begin
                better_ratio  <= 1'b1;
                equal_ratio   <= 1'b0;
              end else begin
                if (cur_sum * best_len > best_sum * cur_len) begin
                  better_ratio <= 1'b1;
                  equal_ratio  <= 1'b0;
                end else if (cur_sum * best_len == best_sum * cur_len) begin
                  better_ratio <= 1'b0;
                  equal_ratio  <= 1'b1;
                end else begin
                  better_ratio <= 1'b0;
                  equal_ratio  <= 1'b0;
                end
              end

              // Length preference when equal ratio
              if (cur_len > best_len)
                better_length <= 1'b1;
              else
                better_length <= 1'b0;

              // Earlier start preference when equal ratio and equal length
              if (cur_start < best_start)
                earlier_start <= 1'b1;
              else
                earlier_start <= 1'b0;

              // Update best based on preferences
              if (better_ratio || (equal_ratio && (better_length || (cur_len == best_len && earlier_start)))) begin
                best_sum   <= cur_sum;
                best_len   <= cur_len;
                best_start <= cur_start;
              end
            end

            // Advance to next subsequence candidate
            if ((cur_start + cur_len) <= 4'd16) begin
              // move start within same length
              cur_start <= cur_start + 4'd1;
            end else begin
              // move to next length
              if (cur_len < 4'd16) begin
                cur_len   <= cur_len + 4'd1;
                cur_start <= 4'd1;
              end else begin
                // all lengths done; go to done
                state <= S_DONE;
              end
            end

            iter_cnt <= iter_cnt + 5'd1;
          end else begin
            // safety: if exceeded 16 cycles, force done
            state <= S_DONE;
          end
        end

        S_DONE: begin
          done      <= 1'b1;
          first_idx <= best_start;
          length    <= best_len;
          // stay in DONE until next start
          if (start) begin
            // restart computation
            done       <= 1'b0;
            prefix[0]  <= 5'd0;
            i_pref     <= 5'd0;
            best_sum   <= 5'd0;
            best_len   <= 4'd0;
            best_start <= 4'd0;
            iter_cnt   <= 5'd0;
            state      <= S_PREF;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule