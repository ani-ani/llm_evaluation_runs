module find_closest_elements #(
  parameter N = 8
)(
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in_valid,
  input [N-1:0][31:0] numbers,
  output reg [31:0] smaller,
  output reg [31:0] larger,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    SORTING,
    COMPARING,
    DONE
  } state_t;

  state_t state;
  reg [31:0] sorted_numbers [0:N-1];
  reg [31:0] min_diff;
  reg [31:0] current_diff;
  reg [31:0] temp;
  reg [4:0] i, j;
  reg [4:0] min_index;
  reg [4:0] sort_pass;
  reg [4:0] compare_index;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      i <= 0;
      j <= 0;
      sort_pass <= 0;
      compare_index <= 0;
      min_diff <= 32'hFFFFFFFF;
      min_index <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start && data_in_valid == 'b11111111) begin
            state <= INIT;
            done <= 0;
            valid <= 0;
          end
        end

        INIT: begin
          // Load input array
          for (i = 0; i < N; i = i + 1) begin
            sorted_numbers[i] <= numbers[i];
          end
          state <= SORTING;
          i <= 0;
          j <= 0;
          sort_pass <= 0;
        end

        SORTING: begin
          // Bubble sort implementation
          if (sort_pass < N-1) begin
            if (j < N - sort_pass - 1) begin
              if (sorted_numbers[j] > sorted_numbers[j+1]) begin
                // Swap
                temp <= sorted_numbers[j];
                sorted_numbers[j] <= sorted_numbers[j+1];
                sorted_numbers[j+1] <= temp;
              end
              j <= j + 1;
            end else begin
              j <= 0;
              sort_pass <= sort_pass + 1;
            end
          end else begin
            state <= COMPARING;
            compare_index <= 0;
            min_diff <= 32'hFFFFFFFF;
            min_index <= 0;
          end
        end

        COMPARING: begin
          if (compare_index < N-1) begin
            // Calculate absolute difference
            if (sorted_numbers[compare_index] > sorted_numbers[compare_index+1]) begin
              current_diff <= sorted_numbers[compare_index] - sorted_numbers[compare_index+1];
            end else begin
              current_diff <= sorted_numbers[compare_index+1] - sorted_numbers[compare_index];
            end

            // Compare with current minimum
            if (current_diff < min_diff) begin
              min_diff <= current_diff;
              min_index <= compare_index;
            end

            compare_index <= compare_index + 1;
          end else begin
            // Store result
            smaller <= sorted_numbers[min_index];
            larger <= sorted_numbers[min_index+1];
            state <= DONE;
            done <= 1;
            valid <= 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
          end
        end
      endcase
    end
  end

endmodule