module max_profit_calculator (
  input clk, rst_n, start,
  input [2:0] num_candidates,
  input [3:0] l_i [0:7],
  input [15:0] s_i [0:7],
  input [15:0] c_v [0:15],
  output reg [31:0] max_profit,
  output reg done
);

const int MIN = -1 << 31;  // Minimum 32-bit signed value

// State machine: 0=IDLE, 1=CALC, 2=DONE
reg [1:0] state;
// Counter for candidate processing (3-bit for up to 8 candidates)
reg [2:0] counter;
// Current DP table (16 entries, 32-bit each)
reg [31:0] curr [0:15];
// Next DP table (combinational output)
reg [31:0] next_table [0:15];
// Start pulse detection
reg start_r;

// Combinational block for DP table update
always_comb begin
  if (state == CALC) begin
    // Get current candidate data
    int L_i_cur = l_i[counter];
    int s_i_cur = s_i[counter];
    
    // Process all k levels (0-15)
    for (int k = 0; k < 16; k++) begin
      // Initialize with skip case (not taking candidate)
      next_table[k] = curr[k];
      
      // Calculate new level when taking candidate
      int new_k = (L_i_cur > k) ? L_i_cur : k;
      int temp = curr[k] - s_i_cur;
      
      // Adjust profit if level changes
      if (L_i_cur > k) begin
        temp = temp + c_v[L_i_cur] - c_v[k];
      end
      
      // Update new state if better
      if (temp > next_table[new_k]) 
        next_table[new_k] = temp;
    end
  end
end

// Sequential state machine
always_ff @(posedge clk) begin
  if (!rst_n) begin
    // Reset to initial state
    state <= 0;  // IDLE
    counter <= 0;
    done <= 0;
    max_profit <= 0;
    
    // Initialize DP table
    for (int i = 0; i < 16; i++) begin
      if (i == 0)
        curr[i] <= 0;        // Level 0 with no profit
      else
        curr[i] <= MIN;      // Other levels initialized to minimum
    end
  end
  else begin
    // Detect start pulse
    start_r <= start;
    
    case (state)
      0: begin  // IDLE
        if (!start_r && start) begin
          state <= 1;  // Start calculation
          counter <= num_candidates - 1;  // Start from last candidate
          
          // Reset DP table
          for (int i = 0; i < 16; i++) begin
            if (i == 0)
              curr[i] <= 0;
            else
              curr[i] <= MIN;
          end
        end
      end
      
      1: begin  // CALC
        // Update table with new values
        for (int i = 0; i < 16; i++) begin
          curr[i] <= next_table[i];
        end
        
        if (counter == 0) begin
          // Calculation complete
          state <= 2;  // DONE
          done <= 1;
          
          // Calculate final max profit
          max_profit = MIN;
          for (int i = 0; i < 16; i++) begin
            if (next_table[i] > max_profit)
              max_profit = next_table[i];
          end
        end
        else begin
          // Next candidate
          counter <= counter - 1;
        end
      end
      
      2: begin  // DONE
        if (!start_r && start) begin
          // Allow re-start
          state <= 0;
          done <= 0;
        end
      end
    endcase
  end
end

endmodule