module next_tolerable_string (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [4:0] p,
  input [127:0] s_in,
  output reg valid,
  output reg [127:0] s_out,
  output reg no_solution
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SEARCH,
    VALIDATE,
    FILL,
    DONE,
    NO_SOLUTION
  } state_t;

  state_t state, next_state;

  // Working string storage
  reg [7:0] working_string [0:15];
  reg [3:0] current_index;
  reg [4:0] current_char;
  reg [3:0] fill_index;
  reg [4:0] fill_char;
  reg [3:0] i, j;
  reg [4:0] k;
  reg valid_flag;
  reg no_sol_flag;

  // Initialize working string from input
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 0;
      no_solution <= 0;
      current_index <= 0;
      fill_index <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      valid_flag <= 0;
      no_sol_flag <= 0;
      for (int idx = 0; idx < 16; idx = idx + 1) begin
        working_string[idx] <= 0;
      end
    end else begin
      state <= next_state;

      // State machine actions
      case (state)
        IDLE: begin
          if (start) begin
            // Load input string
            for (int idx = 0; idx < 16; idx = idx + 1) begin
              if (idx < n) begin
                working_string[idx] <= s_in[(idx+1)*8-1:idx*8];
              end else begin
                working_string[idx] <= 0;
              end
            end
            current_index <= n - 1;
            next_state <= SEARCH;
          end
        end

        SEARCH: begin
          // Try to increment current character
          current_char <= working_string[current_index] + 1;
          if (current_char < p) begin
            // Check if new character is valid
            next_state <= VALIDATE;
          end else begin
            // Cannot increment, move left
            if (current_index == 0) begin
              next_state <= NO_SOLUTION;
            end else begin
              current_index <= current_index - 1;
            end
          end
        end

        VALIDATE: begin
          // Check palindrome constraints
          valid_flag <= 1;

          // Check length 2 palindrome (current == previous)
          if (current_index > 0 && current_char == working_string[current_index - 1]) begin
            valid_flag <= 0;
          end

          // Check length 3 palindrome (current == two positions back)
          if (current_index > 1 && current_char == working_string[current_index - 2]) begin
            valid_flag <= 0;
          end

          if (valid_flag) begin
            // Update working string
            working_string[current_index] <= current_char;
            fill_index <= current_index + 1;
            next_state <= FILL;
          end else begin
            // Try next character
            next_state <= SEARCH;
          end
        end

        FILL: begin
          // Greedily fill remaining positions
          if (fill_index < n) begin
            fill_char <= 0;
            // Find smallest valid character for this position
            while (fill_char < p) begin
              valid_flag <= 1;

              // Check length 2 palindrome
              if (fill_index > 0 && fill_char == working_string[fill_index - 1]) begin
                valid_flag <= 0;
              end

              // Check length 3 palindrome
              if (fill_index > 1 && fill_char == working_string[fill_index - 2]) begin
                valid_flag <= 0;
              end

              if (valid_flag) begin
                working_string[fill_index] <= fill_char;
                fill_index <= fill_index + 1;
                break;
              end
              fill_char <= fill_char + 1;
            end

            if (fill_char == p) begin
              // No valid character found, backtrack
              next_state <= SEARCH;
              current_index <= current_index - 1;
            end
          end else begin
            next_state <= DONE;
          end
        end

        DONE: begin
          valid <= 1;
          no_solution <= 0;
          // Output the result
          for (int idx = 0; idx < 16; idx = idx + 1) begin
            if (idx < n) begin
              s_out[(idx+1)*8-1:idx*8] <= working_string[idx];
            end else begin
              s_out[(idx+1)*8-1:idx*8] <= 0;
            end
          end
          next_state <= IDLE;
        end

        NO_SOLUTION: begin
          no_solution <= 1;
          valid <= 0;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // Default assignments
  always @(*) begin
    s_out = 0;
  end

endmodule