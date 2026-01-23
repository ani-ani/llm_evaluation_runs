module swap_digits_max (
  input clk,
  input rst_n,
  input start,
  input [15:0] number_in,
  input [3:0] k,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [15:0] current_number;
  reg [15:0] best_result;
  reg [3:0] swap_count;
  reg [3:0] pos1;
  reg [3:0] pos2;
  reg [3:0] iteration;
  reg [3:0] max_iterations;

  // Helper functions
  function [15:0] swap_digits;
    input [15:0] num;
    input [3:0] p1;
    input [3:0] p2;
    reg [15:0] swapped;
    reg [3:0] digit1, digit2;
    begin
      digit1 = num[15 - 4*p1 : 12 - 4*p1];
      digit2 = num[15 - 4*p2 : 12 - 4*p2];
      swapped = num;
      swapped[15 - 4*p1 : 12 - 4*p1] = digit2;
      swapped[15 - 4*p2 : 12 - 4*p2] = digit1;
      swap_digits = swapped;
    end
  endfunction

  function logic is_valid;
    input [15:0] num;
    begin
      is_valid = (num[15:12] != 0); // No leading zero
    end
  endfunction

  function logic is_greater;
    input [15:0] a;
    input [15:0] b;
    begin
      is_greater = (a > b);
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      current_number <= 0;
      best_result <= 0;
      swap_count <= 0;
      pos1 <= 0;
      pos2 <= 0;
      iteration <= 0;
      max_iterations <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
          end
        end
        INIT: begin
          current_number <= number_in;
          best_result <= number_in;
          swap_count <= 0;
          pos1 <= 0;
          pos2 <= 1;
          iteration <= 0;
          max_iterations <= 4; // 4 digits, so 4*3/2 = 6 possible swaps per step
          state <= PROCESSING;
        end
        PROCESSING: begin
          if (swap_count < k) begin
            if (iteration < max_iterations) begin
              // Perform swap
              current_number <= swap_digits(current_number, pos1, pos2);
              // Check if valid and better
              if (is_valid(current_number) && is_greater(current_number, best_result)) begin
                best_result <= current_number;
              end
              // Move to next swap position
              pos2 <= pos2 + 1;
              if (pos2 >= 4) begin
                pos2 <= pos1 + 1;
                pos1 <= pos1 + 1;
                if (pos1 >= 3) begin
                  pos1 <= 0;
                  pos2 <= 1;
                end
              end
              iteration <= iteration + 1;
            end else begin
              // Reset for next swap count
              current_number <= best_result;
              swap_count <= swap_count + 1;
              iteration <= 0;
              pos1 <= 0;
              pos2 <= 1;
            end
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          result <= best_result;
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule