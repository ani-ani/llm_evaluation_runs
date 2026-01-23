module max_priority_subset(
  input clk,
  input rst_n,
  input start,
  input [7:0] s_i, d_i, p_i,
  input valid_in,
  output reg [11:0] result,
  output reg done
);

  // Parameters
  parameter N = 8;
  parameter IDLE = 3'b000;
  parameter LOAD = 3'b001;
  parameter SORT = 3'b010;
  parameter DP_COMPUTE = 3'b011;
  parameter FINISH = 3'b100;

  // Registers
  reg [2:0] state;
  reg [2:0] next_state;
  reg [2:0] load_count;
  reg [2:0] i_idx; // Outer loop index for DP
  reg [2:0] k_idx; // Inner loop index for DP
  reg [2:0] sort_idx;
  reg [2:0] sort_limit;
  
  // Storage for streams: 0 to 7
  reg [7:0] s_mem [0:7];
  reg [8:0] e_mem [0:7]; // End time (s+d, max 510)
  reg [7:0] p_mem [0:7];
  
  // DP table: dp[i] is max priority subset of first i streams
  reg [11:0] dp [0:8];
  reg [11:0] max_prev;
  reg [11:0] p_val;
  reg [11:0] candidate;
  
  // Flags
  reg computing_max;

  // State Transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next State Logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
        else next_state = IDLE;
      end
      LOAD: begin
        if (load_count == N && valid_in) next_state = SORT;
        else next_state = LOAD;
      end
      SORT: begin
        // Bubble sort logic handled in sequential block
        // Transition when sorted (limit reaches 1)
        if (sort_limit == 1) next_state = DP_COMPUTE;
        else next_state = SORT;
      end
      DP_COMPUTE: begin
        // i_idx goes 1 to 8. After i=8 done.
        if (i_idx == N + 1) next_state = FINISH;
        else next_state = DP_COMPUTE;
      end
      FINISH: begin
        // Stay here until reset or start again
        next_state = FINISH;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_count <= 0;
      i_idx <= 0;
      k_idx <= 0;
      sort_idx <= 0;
      sort_limit <= N;
      done <= 0;
      result <= 0;
      computing_max <= 0;
      dp[0] <= 0;
    end else begin
      case (state)
        IDLE: begin
          load_count <= 0;
          done <= 0;
        end

        LOAD: begin
          if (valid_in && load_count < N) begin
            s_mem[load_count] <= s_i;
            e_mem[load_count] <= s_i + d_i; // Calculate end time
            p_mem[load_count] <= p_i;
            load_count <= load_count + 1;
          end
        end

        SORT: begin
          // Bubble sort (sinking) based on end times (e_mem)
          // Iterates from 0 to sort_limit-2
          if (sort_limit > 1) begin
            if (sort_idx < sort_limit - 1) begin
              // Compare e_mem[sort_idx] and e_mem[sort_idx+1]
              if (e_mem[sort_idx] > e_mem[sort_idx + 1]) begin
                // Swap e
                e_mem[sort_idx] <= e_mem[sort_idx + 1];
                e_mem[sort_idx + 1] <= e_mem[sort_idx];
                // Swap s
                s_mem[sort_idx] <= s_mem[sort_idx + 1];
                s_mem[sort_idx + 1] <= s_mem[sort_idx];
                // Swap p
                p_mem[sort_idx] <= p_mem[sort_idx + 1];
                p_mem[sort_idx + 1] <= p_mem[sort_idx];
              end
              sort_idx <= sort_idx + 1;
            end else begin
              // Pass complete
              sort_limit <= sort_limit - 1;
              sort_idx <= 0;
            end
          end
        end

        DP_COMPUTE: begin
          if (i_idx < N + 1) begin
            // Option 1: Exclude stream i_idx
            // dp[i_idx] = dp[i_idx-1]; (dp is indexed 0..8, so dp[i_idx-1] is prev)
            // We perform Option 1 in parallel or as base state
            // Let's's logic: Check max(dp[k] for valid k) + p[i_idx]
            
            // We need to find max_dp_k. 
            // Let's use a flag 'computing_max' to handle the inner loop k_idx.
            // But since we want to stay in DP_COMPUTE state for the whole process, 
            // we need a sub-state or just sequential logic inside this block.
            // To keep it simple and within one state: we check one k per cycle, 
            // update a temporary max, then update dp.
            
            if (!computing_max) begin
              // Start finding max DP[k] for streams ending before S[i]
              computing_max <= 1;
              k_idx <= 0;
              max_prev <= 0; // Clear max accumulator
            end else begin
              // Inner loop: checking k from 0 to i_idx-1
              if (k_idx < i_idx) begin
                // Check condition: e[k] <= s[i_idx]
                // Note: s_mem and e_mem are sorted. Indices match.
                // i_idx is 1-based for DP, but memory is 0-based. 
                // So stream 'i' is s_mem[i-1].
                // Stream 'k' is s_mem[k_idx].
                if (e_mem[k_idx] <= s_mem[i_idx - 1]) begin
                  if (dp[k_idx] > max_prev) begin
                    max_prev <= dp[k_idx];
                  end
                end
                k_idx <= k_idx + 1;
              end else begin
                // Inner loop finished. Calculate candidate.
                // candidate = max_prev + p[i_idx - 1]
                candidate <= max_prev + p_mem[i_idx - 1];
                
                // Now perform the max(dp[i-1], candidate) logic
                // dp[i_idx] = dp[i_idx - 1]; // This is Option 1
                // But wait, dp[i_idx-1] is already valid from previous cycle.
                // We update dp[i_idx] now.
                
                if (dp[i_idx - 1] > (max_prev + p_mem[i_idx - 1])) begin
                  dp[i_idx] <= dp[i_idx - 1];
                end else begin
                  dp[i_idx] <= max_prev + p_mem[i_idx - 1];
                end
                
                // Reset for next i
                computing_max <= 0;
                i_idx <= i_idx + 1;
              end
            end
          end
        end

        FINISH: begin
          result <= dp[N]; // dp[8]
          done <= 1;
        end
      endcase
    end
  end

endmodule
