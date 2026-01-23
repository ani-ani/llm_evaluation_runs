module multi_concat #(
    parameter NUM_ELEMENTS = 8,
    parameter ELEMENT_WIDTH = 8,  // Each integer stored as 8-bit (0-99 range)
    parameter RESULT_WIDTH = 64   // 8 elements * 8 bits each
  ) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [ELEMENT_WIDTH-1:0] arr [NUM_ELEMENTS-1:0],
    input wire [3:0] len,  // Number of valid elements (1-8)
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
  );

  // Internal state
  reg [3:0] idx;
  reg processing;
  reg [RESULT_WIDTH-1:0] temp_result;
  
  // Helper: Check if element is negative (MSB set)
  wire is_negative;
  assign is_negative = arr[0][ELEMENT_WIDTH-1] && (len > 0);
  
  // Helper: Convert element to 2-digit decimal value (0-99)
  function [15:0] to_decimal;
    input [ELEMENT_WIDTH-1:0] val;
    reg [7:0] abs_val;
    begin
      // Take absolute value, clamp to 99
      abs_val = val[ELEMENT_WIDTH-1] ? (~val + 1'b1) : val;
      if (abs_val > 99) abs_val = 99;
      // Convert to decimal: tens * 10 + ones
      to_decimal = ((abs_val / 10) * 100) + ((abs_val % 10) * 10);
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
      idx <= 0;
      processing <= 0;
      temp_result <= 0;
    end else begin
      if (start && !processing) begin
        // Start new computation
        idx <= 0;
        processing <= 1;
        done <= 0;
        temp_result <= 0;
        
        // Handle negative first element
        if (is_negative && len > 0) begin
          temp_result[RESULT_WIDTH-1] <= 1;  // Set sign bit
        end
      end else if (processing) begin
        if (idx < len) begin
          // Process element idx
          if (idx == 0 && is_negative) begin
            // First element is negative - already handled sign
            temp_result <= temp_result + (to_decimal(arr[0]) << ((len-1-idx)*8));
          end else begin
            // Regular element - shift and add
            temp_result <= temp_result + (to_decimal(arr[idx]) << ((len-1-idx)*8));
          end
          idx <= idx + 1;
        end else begin
          // Done
          result <= temp_result;
          done <= 1;
          processing <= 0;
        end
      end else begin
        done <= 0;
      end
    end
  end

endmodule