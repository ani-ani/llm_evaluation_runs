module sorted_list_sum (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_strings,
  input [7:0] string_data [0:7][0:7],
  output reg [2:0] result_count,
  output reg [7:0] result_strings [0:7][0:7],
  output reg done
);

  // State machine states
  typedef enum logic [3:0] {
    IDLE,
    FILTER,
    SORT_COMPARE,
    SORT_SWAP,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] filtered_count;
  reg [7:0] filtered_strings [0:7][0:7];
  reg [2:0] i, j, k;
  reg [7:0] temp_string [0:7];
  reg swap_flag;
  reg [2:0] cycle_count;

  // Calculate string length (first null byte or 8)
  function [2:0] get_string_length;
    input [7:0] str [0:7];
    integer idx;
    begin
      for (idx = 0; idx < 8; idx = idx + 1) begin
        if (str[idx] == 8'h00) begin
          return idx;
        end
      end
      return 8;
    end
  endfunction

  // Check if string length is even
  function is_even_length;
    input [7:0] str [0:7];
    begin
      return (get_string_length(str) % 2 == 0);
    end
  endfunction

  // Compare two strings (returns 1 if str1 < str2)
  function compare_strings;
    input [7:0] str1 [0:7];
    input [7:0] str2 [0:7];
    integer len1, len2, idx;
    begin
      len1 = get_string_length(str1);
      len2 = get_string_length(str2);
      
      // Primary sort: by length
      if (len1 < len2) return 1;
      if (len1 > len2) return 0;
      
      // Secondary sort: alphabetically
      for (idx = 0; idx < len1; idx = idx + 1) begin
        if (str1[idx] < str2[idx]) return 1;
        if (str1[idx] > str2[idx]) return 0;
      end
      return 0; // equal
    end
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      filtered_count <= 0;
      result_count <= 0;
      done <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      cycle_count <= 0;
      swap_flag <= 0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          if (start) begin
            filtered_count <= 0;
            result_count <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            cycle_count <= 0;
            swap_flag <= 0;
            next_state <= FILTER;
          end else begin
            next_state <= IDLE;
          end
        end
        
        FILTER: begin
          if (i < num_strings) begin
            // Copy string if even length
            if (is_even_length(string_data[i])) begin
              for (k = 0; k < 8; k = k + 1) begin
                filtered_strings[filtered_count][k] <= string_data[i][k];
              end
              filtered_count <= filtered_count + 1;
            end
            i <= i + 1;
          end else begin
            i <= 0;
            j <= 0;
            cycle_count <= 0;
            next_state <= SORT_COMPARE;
          end
        end
        
        SORT_COMPARE: begin
          if (cycle_count < 512) begin
            if (j < filtered_count - 1) begin
              if (compare_strings(filtered_strings[j], filtered_strings[j+1])) begin
                swap_flag <= 1;
                next_state <= SORT_SWAP;
              end else begin
                j <= j + 1;
              end
            end else begin
              j <= 0;
              cycle_count <= cycle_count + 1;
              if (cycle_count == 511) begin
                next_state <= DONE;
              end
            end
          end else begin
            next_state <= DONE;
          end
        end
        
        SORT_SWAP: begin
          // Swap strings
          for (k = 0; k < 8; k = k + 1) begin
            temp_string[k] <= filtered_strings[j][k];
            filtered_strings[j][k] <= filtered_strings[j+1][k];
            filtered_strings[j+1][k] <= temp_string[k];
          end
          j <= j + 1;
          swap_flag <= 0;
          next_state <= SORT_COMPARE;
        end
        
        DONE: begin
          // Copy results to output
          result_count <= filtered_count;
          for (i = 0; i < filtered_count; i = i + 1) begin
            for (k = 0; k < 8; k = k + 1) begin
              result_strings[i][k] <= filtered_strings[i][k];
            end
          end
          done <= 1;
          next_state <= IDLE;
        end
        
        default: next_state <= IDLE;
      endcase
    end
  end

endmodule