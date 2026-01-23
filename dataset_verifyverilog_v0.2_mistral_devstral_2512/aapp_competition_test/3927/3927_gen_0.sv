module weight_reveal (
  input clk,
  input rst_n,
  input start,
  input [3:0] n_in,
  input [4:0] value_in,
  input input_valid,
  output reg [4:0] max_reveal,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_VALUES,
    COMPUTE_DP,
    CHECK_UNIQUE,
    DONE
  } state_t;
  state_t state, next_state;

  // Registers
  reg [4:0] count [0:15]; // Count of each value (1-15)
  reg [7:0] total_sum;
  reg [4:0] current_value;
  reg [3:0] current_n;
  reg [3:0] value_index;
  reg [3:0] sum_index;
  reg [3:0] count_index;
  reg [3:0] check_index;
  reg [4:0] temp_max;

  // DP table (sparse representation)
  reg [7:0] dp_sum [0:15]; // Sum for each value
  reg [3:0] dp_count [0:15]; // Count for each value
  reg dp_valid [0:15]; // Valid flag for DP entries
  reg [7:0] dp_table [0:15][0:10]; // DP table [value][count]

  // Binomial coefficients (precomputed)
  reg [7:0] binom [0:10][0:10];

  // Initialize binomial coefficients
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      max_reveal <= 0;
      done <= 0;
      current_n <= 0;
      current_value <= 0;
      value_index <= 0;
      sum_index <= 0;
      count_index <= 0;
      check_index <= 0;
      temp_max <= 0;
      total_sum <= 0;

      // Reset count array
      for (int i = 0; i < 16; i++) begin
        count[i] <= 0;
      end

      // Reset DP table
      for (int i = 0; i < 16; i++) begin
        dp_valid[i] <= 0;
        dp_sum[i] <= 0;
        dp_count[i] <= 0;
        for (int j = 0; j < 10; j++) begin
          dp_table[i][j] <= 0;
        end
      end

      // Initialize binomial coefficients
      for (int n = 0; n < 11; n++) begin
        for (int k = 0; k < 11; k++) begin
          if (k == 0 || k == n)
            binom[n][k] <= 1;
          else if (k > n)
            binom[n][k] <= 0;
          else
            binom[n][k] <= binom[n-1][k-1] + binom[n-1][k];
        end
      end
    end else begin
      state <= next_state;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            next_state <= LOAD_VALUES;
            current_n <= n_in;
            value_index <= 0;
            total_sum <= 0;
            temp_max <= 0;
            // Reset count array
            for (int i = 0; i < 16; i++) begin
              count[i] <= 0;
            end
          end else begin
            next_state <= IDLE;
          end
        end

        LOAD_VALUES: begin
          if (input_valid && value_index < current_n) begin
            current_value <= value_in;
            count[current_value] <= count[current_value] + 1;
            total_sum <= total_sum + current_value;
            value_index <= value_index + 1;
          end else if (value_index == current_n) begin
            next_state <= COMPUTE_DP;
            sum_index <= 0;
            count_index <= 0;
          end
        end

        COMPUTE_DP: begin
          // Compute DP table
          if (sum_index < 16 && count_index < 11) begin
            // Initialize DP table
            for (int i = 0; i < 16; i++) begin
              for (int j = 0; j < 10; j++) begin
                if (j == 0) begin
                  dp_table[i][j] <= (i == 0) ? 1 : 0;
                end else if (i == 0) begin
                  dp_table[i][j] <= 0;
                end else begin
                  dp_table[i][j] <= dp_table[i-1][j-1] + dp_table[i-1][j];
                end
              end
            end
            next_state <= CHECK_UNIQUE;
            check_index <= 0;
          end
        end

        CHECK_UNIQUE: begin
          if (check_index < 16) begin
            if (count[check_index] > 0) begin
              // Check if all check_index's can form unique subset
              if (dp_table[check_index * count[check_index]][count[check_index]] == binom[count[check_index]][count[check_index]]) begin
                // Check if remaining items form unique subset
                if (dp_table[total_sum - check_index * count[check_index]][current_n - count[check_index]] == binom[current_n - count[check_index]][current_n - count[check_index]]) begin
                  if (count[check_index] > temp_max) begin
                    temp_max <= count[check_index];
                  end
                end
              end
            end
            check_index <= check_index + 1;
          end else begin
            max_reveal <= temp_max;
            next_state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            next_state <= IDLE;
            done <= 0;
          end
        end

        default: next_state <= IDLE;
      endcase
    end
  end

endmodule