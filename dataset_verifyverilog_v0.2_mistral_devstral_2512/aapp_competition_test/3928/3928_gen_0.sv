module string_compressor (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [15:0] a_cost,
  input [15:0] b_cost,
  input [3:0] str_len,
  output reg [15:0] min_cost,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    COMPUTE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [3:0] char_count;
  reg [7:0] char_buffer [0:15];
  reg [15:0] dp [0:15];
  reg [3:0] i_reg, j_reg, l_reg;
  reg [15:0] current_min;
  reg match_found;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_count <= 0;
      i_reg <= 0;
      j_reg <= 0;
      l_reg <= 0;
      current_min <= 0;
      match_found <= 0;
      done <= 0;
      min_cost <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (char_count == str_len - 1) next_state = COMPUTE;
      end
      COMPUTE: begin
        if (i_reg == str_len) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Load phase
  always @(posedge clk) begin
    if (!rst_n) begin
      char_count <= 0;
    end else if (state == LOAD && start) begin
      if (char_count < str_len) begin
        char_buffer[char_count] <= char_in;
        char_count <= char_count + 1;
      end
    end
  end

  // Compute phase
  always @(posedge clk) begin
    if (!rst_n) begin
      i_reg <= 0;
      j_reg <= 0;
      l_reg <= 0;
      current_min <= 0;
      match_found <= 0;
    end else if (state == COMPUTE) begin
      // Initialize DP table
      if (i_reg == 0) begin
        dp[0] <= 0;
        i_reg <= 1;
        j_reg <= 0;
        l_reg <= 0;
        current_min <= a_cost;
        match_found <= 0;
      end
      // Compute dp[i]
      else if (i_reg <= str_len) begin
        // Initialize with dp[i-1] + a_cost
        if (j_reg == 0 && l_reg == 0) begin
          dp[i_reg] <= dp[i_reg - 1] + a_cost;
          current_min <= dp[i_reg];
          j_reg <= 0;
          l_reg <= 1;
        end
        // Check for substring matches
        else if (j_reg < i_reg && l_reg <= (i_reg - j_reg)) begin
          // Check if s[i_reg-l_reg...i_reg-1] matches s[j_reg-l_reg+1...j_reg]
          if (char_buffer[i_reg - l_reg] == char_buffer[j_reg - l_reg + 1]) begin
            if (l_reg == (i_reg - j_reg)) begin
              // Full match found
              if (dp[j_reg] + b_cost < current_min) begin
                current_min <= dp[j_reg] + b_cost;
                match_found <= 1;
              end
              j_reg <= j_reg + 1;
              l_reg <= 1;
            end else begin
              l_reg <= l_reg + 1;
            end
          end else begin
            j_reg <= j_reg + 1;
            l_reg <= 1;
          end
        end
        // Move to next i
        else begin
          if (match_found) begin
            dp[i_reg] <= current_min;
          end
          i_reg <= i_reg + 1;
          j_reg <= 0;
          l_reg <= 0;
          current_min <= 0;
          match_found <= 0;
        end
      end
    end
  end

  // Output handling
  always @(posedge clk) begin
    if (!rst_n) begin
      done <= 0;
      min_cost <= 0;
    end else if (state == DONE) begin
      done <= 1;
      min_cost <= dp[str_len];
    end else if (state != DONE) begin
      done <= 0;
    end
  end

endmodule