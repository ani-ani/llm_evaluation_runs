module laser_maximizer (
  input clk,
  input rst_n,
  input start,
  input [7:0] y_left [0:15],
  input [7:0] y_right [0:15],
  input [3:0] n_left,
  input [3:0] n_right,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    PREPARE_SOURCES,
    PROCESS_PAIRS,
    CALCULATE_MAX,
    DONE
  } state_t;

  state_t state;
  reg [7:0] y_left_buf [0:15];
  reg [7:0] y_right_buf [0:15];
  reg [3:0] n_left_buf;
  reg [3:0] n_right_buf;

  // Sum lookup table: 256 possible sums (0-255), each with a 256-bit mask
  reg [255:0] sum_mask [0:255];

  // Pair processing counters
  reg [3:0] i_cnt;
  reg [3:0] j_cnt;

  // Max calculation variables
  reg [7:0] max_count;
  reg [7:0] s1;
  reg [7:0] s2;
  reg [7:0] s1_cnt;
  reg [7:0] s2_cnt;
  reg [7:0] current_count;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      i_cnt <= 0;
      j_cnt <= 0;
      s1 <= 0;
      s2 <= 0;
      s1_cnt <= 0;
      s2_cnt <= 0;
      max_count <= 0;
      current_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREPARE_SOURCES;
            done <= 0;
          end
        end

        PREPARE_SOURCES: begin
          // Copy inputs to buffers
          for (int i = 0; i < 16; i++) begin
            y_left_buf[i] <= y_left[i];
            y_right_buf[i] <= y_right[i];
          end
          n_left_buf <= n_left;
          n_right_buf <= n_right;
          state <= PROCESS_PAIRS;
        end

        PROCESS_PAIRS: begin
          // Process all pairs
          if (i_cnt < n_left_buf) begin
            if (j_cnt < n_right_buf) begin
              // Calculate sum and set mask bit
              reg [7:0] sum_val = y_left_buf[i_cnt] + y_right_buf[j_cnt];
              reg [255:0] mask = sum_mask[sum_val];
              mask[i_cnt * n_right_buf + j_cnt] = 1'b1;
              sum_mask[sum_val] <= mask;
              j_cnt <= j_cnt + 1;
            end else begin
              j_cnt <= 0;
              i_cnt <= i_cnt + 1;
            end
          end else begin
            state <= CALCULATE_MAX;
            i_cnt <= 0;
            j_cnt <= 0;
          end
        end

        CALCULATE_MAX: begin
          // Find two sums with maximum coverage
          if (s1_cnt < 256) begin
            if (s2_cnt < 256) begin
              current_count = $countones(sum_mask[s1] | sum_mask[s2]);
              if (current_count > max_count) begin
                max_count <= current_count;
              end
              s2_cnt <= s2_cnt + 1;
            end else begin
              s2_cnt <= 0;
              s1_cnt <= s1_cnt + 1;
            end
          end else begin
            result <= max_count;
            state <= DONE;
            done <= 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule