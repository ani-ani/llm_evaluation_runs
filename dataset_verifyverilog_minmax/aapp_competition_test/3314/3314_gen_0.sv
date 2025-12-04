module wheel_rotator(
  input clk,               // clock signal
  input rst_n,             // active-low reset
  input start,             // pulse high to start computation
  input [2:0] str_len,     // actual string length (2-8)
  input [7:0][1:0] wheel0, // first wheel (8 cols max)
  input [7:0][1:0] wheel1, // second wheel
  input [7:0][1:0] wheel2, // third wheel
  output reg [3:0] result, // min rotations or 15 for -1
  output reg done           // high when computation complete
);

  // State machine states
  parameter [1:0] INIT = 2'b00;
  parameter [1:0] CONFIG = 2'b01;
  parameter [1:0] CALC = 2'b10;
  parameter [1:0] DONE = 2'b11;
  
  // State register
  reg [1:0] state;
  
  // Rotation counters and string length storage
  reg [2:0] n;        // current string length
  reg [2:0] i0, i1, i2; // rotation offsets for each wheel (0 to n-1)
  reg [3:0] best_rot; // best rotation found so far
  reg cond;           // condition check result
  
  // Minimum function
  function [3:0] min_val;
    input [3:0] a;
    input [3:0] b;
    begin
      if (a < b) min_val = a;
      else min_val = b;
    end
  endfunction
  
  // Condition check function
  function [0:0] check_condition;
    input [2:0] i0;
    input [2:0] i1;
    input [2:0] i2;
    input [2:0] n;
    integer col;
    reg [1:0] temp0, temp1, temp2;
    reg [2:0] index0, index1, index2;
    begin
      cond = 1;
      for (col = 0; col < 8; col = col + 1) begin
        if (col < n) begin
          // Calculate index0
          if (col >= i0) index0 = col - i0;
          else index0 = col - i0 + n;
          
          // Calculate index1
          if (col >= i1) index1 = col - i1;
          else index1 = col - i1 + n;
          
          // Calculate index2
          if (col >= i2) index2 = col - i2;
          else index2 = col - i2 + n;
          
          // Get letters
          temp0 = wheel0[index0];
          temp1 = wheel1[index1];
          temp2 = wheel2[index2];
          
          // Check for invalid letters or duplicates
          if (temp0 == 2'b11 || temp1 == 2'b11 || temp2 == 2'b11) 
            cond = 0;
          else if (temp0 == temp1 || temp0 == temp2 || temp1 == temp2)
            cond = 0;
        end
      end
      check_condition = cond;
    end
  endfunction
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= INIT;
      i0 <= 0;
      i1 <= 0;
      i2 <= 0;
      best_rot <= 15;
      result <= 15;
      done <= 0;
      n <= 0;
    end
    else begin
      case (state)
        INIT: begin
          if (start) begin
            state <= CONFIG;
          end
          result <= 15;
          done <= 0;
        end
        
        CONFIG: begin
          n <= str_len;
          i0 <= 0;
          i1 <= 0;
          i2 <= 0;
          best_rot <= 15;
          state <= CALC;
        end
        
        CALC: begin
          // Check condition for current offsets
          if (check_condition(i0, i1, i2, n)) begin
            best_rot <= min_val(best_rot, min_val(i0, n-i0) + min_val(i1, n-i1) + min_val(i2, n-i2));
          end
          
          // Advance offsets
          if (i2 < n-1) 
            i2 <= i2 + 1;
          else if (i1 < n-1) begin
            i1 <= i1 + 1;
            i2 <= 0;
          end
          else if (i0 < n-1) begin
            i0 <= i0 + 1;
            i1 <= 0;
            i2 <= 0;
          end
          else begin
            // Last combination - go to DONE
            state <= DONE;
          end
          
          // Stay in CALC if not done with all combinations
          if (!(i0 == n-1 && i1 == n-1 && i2 == n-1))
            state <= CALC;
        end
        
        DONE: begin
          result <= best_rot;
          done <= 1;
          if (start)
            state <= CONFIG;
          else
            state <= DONE;
        end
      endcase
    end
  end

endmodule
