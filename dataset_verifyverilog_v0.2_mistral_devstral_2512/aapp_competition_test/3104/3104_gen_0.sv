module equation_solver (
  input clk,
  input rst_n,
  input start,
  input [63:0] a_in,
  input [7:0] s_in,
  output reg [255:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PARSE,
    COMPUTE,
    RECONSTRUCT,
    DONE
  } state_t;

  state_t state, next_state;

  // Parsed digits (8 digits max)
  reg [3:0] digits [0:7];
  reg [2:0] num_digits;

  // DP table: dp[i][j] = min splits for first i digits to sum to j
  reg [7:0] dp [0:8][0:255];
  reg [7:0] split_pos [0:8][0:255];

  // Current computation variables
  reg [2:0] i, j, k;
  reg [7:0] current_sum;
  reg [7:0] temp_num;

  // Reconstruction variables
  reg [7:0] remaining_sum;
  reg [2:0] pos;
  reg [255:0] result_str;
  reg [7:0] result_idx;

  // Initialize DP table
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      num_digits <= 0;
      for (int d = 0; d < 8; d++) begin
        digits[d] <= 0;
      end
      for (int x = 0; x < 8; x++) begin
        for (int y = 0; y < 255; y++) begin
          dp[x][y] <= 8'hFF;
          split_pos[x][y] <= 0;
        end
      end
      i <= 0;
      j <= 0;
      k <= 0;
      current_sum <= 0;
      temp_num <= 0;
      remaining_sum <= 0;
      pos <= 0;
      result_str <= 0;
      result_idx <= 0;
    end else begin
      state <= next_state;
    end
  end

  // State machine
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PARSE;
      end
      PARSE: begin
        next_state = COMPUTE;
      end
      COMPUTE: begin
        if (i == 7 && j == s_in) next_state = RECONSTRUCT;
      end
      RECONSTRUCT: begin
        if (pos == num_digits) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Parse input string
  always @(posedge clk) begin
    if (state == PARSE) begin
      // Extract ASCII digits (0-9 only)
      for (int d = 0; d < 8; d++) begin
        digits[d] <= a_in[8*d + 7:8*d] - 8'd48;
      end
      // Count actual digits (stop at first non-digit)
      num_digits <= 0;
      for (int d = 0; d < 8; d++) begin
        if (digits[d] <= 9) num_digits <= num_digits + 1;
        else break;
      end
      // Initialize DP table
      for (int x = 0; x < 8; x++) begin
        for (int y = 0; y < 255; y++) begin
          dp[x][y] <= 8'hFF;
          split_pos[x][y] <= 0;
        end
      end
      dp[0][0] <= 0; // Base case: 0 digits sum to 0 with 0 splits
      i <= 0;
      j <= 0;
      k <= 0;
    end
  end

  // Compute DP table
  always @(posedge clk) begin
    if (state == COMPUTE) begin
      if (i < num_digits) begin
        if (j < 255) begin
          // Try all possible split positions
          if (k < i) begin
            // Calculate number formed by digits[k..i-1]
            temp_num <= 0;
            for (int d = k; d < i; d++) begin
              temp_num <= temp_num * 10 + digits[d];
            end
            current_sum <= j - temp_num;
            if (current_sum < 255 && dp[k][current_sum] != 8'hFF) begin
              if (dp[i][j] > dp[k][current_sum] + 1) begin
                dp[i][j] <= dp[k][current_sum] + 1;
                split_pos[i][j] <= k;
              end
            end
            k <= k + 1;
          end else begin
            k <= 0;
            j <= j + 1;
          end
        end else begin
          j <= 0;
          i <= i + 1;
        end
      end
    end
  end

  // Reconstruct solution
  always @(posedge clk) begin
    if (state == RECONSTRUCT) begin
      if (pos == 0) begin
        // Start reconstruction
        remaining_sum <= s_in;
        pos <= num_digits;
        result_str <= 0;
        result_idx <= 0;
      end else begin
        if (pos > 0) begin
          // Get split position
          k <= split_pos[pos][remaining_sum];
          // Calculate current number
          temp_num <= 0;
          for (int d = k; d < pos; d++) begin
            temp_num <= temp_num * 10 + digits[d];
          end
          // Add to result string
          if (result_idx > 0) begin
            result_str[result_idx] <= 8'h2B; // '+'
            result_idx <= result_idx + 1;
          end
          // Convert number to ASCII
          if (temp_num >= 10) begin
            result_str[result_idx] <= (temp_num / 10) + 8'd48;
            result_idx <= result_idx + 1;
          end
          result_str[result_idx] <= (temp_num % 10) + 8'd48;
          result_idx <= result_idx + 1;
          // Update remaining sum
          remaining_sum <= remaining_sum - temp_num;
          pos <= k;
        end else begin
          // Add '=' and target value
          result_str[result_idx] <= 8'h3D; // '='
          result_idx <= result_idx + 1;
          if (s_in >= 100) begin
            result_str[result_idx] <= (s_in / 100) + 8'd48;
            result_idx <= result_idx + 1;
          end
          if (s_in >= 10) begin
            result_str[result_idx] <= ((s_in / 10) % 10) + 8'd48;
            result_idx <= result_idx + 1;
          end
          result_str[result_idx] <= (s_in % 10) + 8'd48;
          result_idx <= result_idx + 1;
          // Pad with nulls
          for (int x = result_idx; x < 256; x++) begin
            result_str[x] <= 8'h00;
          end
          result <= result_str;
          pos <= 0; // Force completion
        end
      end
    end
  end

  // Done signal
  always @(posedge clk) begin
    if (state == DONE) begin
      done <= 1;
    end else if (state == IDLE) begin
      done <= 0;
    end
  end

endmodule