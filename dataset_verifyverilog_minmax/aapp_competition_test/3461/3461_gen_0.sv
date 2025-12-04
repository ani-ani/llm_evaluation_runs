module hearing_scheduler(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_hearings,
  input [15:0] s [0:3],
  input [15:0] a [0:3],
  input [15:0] b [0:3],
  output reg [31:0] result,
  output reg done
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam CALCULATE = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state;
  reg [7:0] cycle_count; // Max 256 cycles needed
  
  // Fixed-point arithmetic constants
  localparam FIXED_POINT_SCALE = 16'h10000; // 2^16 for Q16.16 format
  
  // Intermediate storage for calculations
  reg [31:0] expected_value;
  reg [15:0] current_time;
  reg [2:0] current_hearing;
  reg [5:0] current_split; // 0-63 splits per hearing
  
  // Function to convert integer to fixed-point
  function [31:0] int_to_fixed;
    input [15:0] value;
    begin
      int_to_fixed = {value, 16'h0000};
    end
  endfunction
  
  // Function to add fixed-point numbers
  function [31:0] fixed_add;
    input [31:0] a;
    input [31:0] b;
    begin
      fixed_add = a + b;
    end
  endfunction
  
  // Function for max of fixed-point numbers
  function [31:0] fixed_max;
    input [31:0] a;
    input [31:0] b;
    begin
      fixed_max = (a > b) ? a : b;
    end
  endfunction
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 32'h0;
      cycle_count <= 8'h0;
      expected_value <= 32'h0;
      current_time <= 16'h0;
      current_hearing <= 3'h0;
      current_split <= 6'h0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATE;
            cycle_count <= 8'h0;
            current_time <= 16'h0;
            current_hearing <= 3'h0;
            current_split <= 6'h0;
            expected_value <= 32'h0;
          end
        end
        
        CALCULATE: begin
          if (cycle_count < 8'hFF) begin // 255 cycles for calculation
            cycle_count <= cycle_count + 1;
            
            // Calculate current hearing duration split
            if (current_split < 6'd63) begin
              current_split <= current_split + 1;
            end else begin
              current_split <= 6'h0;
              if (current_hearing < num_hearings - 1) begin
                current_hearing <= current_hearing + 1;
              end else begin
                current_hearing <= 3'h0;
              end
            end
            
            // Simple heuristic: increase expected value by 1/64 for each valid hearing attended
            // This is a placeholder for the actual optimal strategy calculation
            if (current_time <= s[current_hearing] && 
                a[current_hearing] <= b[current_hearing] &&
                current_hearing < num_hearings) begin
              // Add 1 to expected value for this hearing
              expected_value <= fixed_add(expected_value, int_to_fixed(16'h0001));
              current_time <= current_time + (a[current_hearing] + 
                                current_split * (b[current_hearing] - a[current_hearing]) / 64);
            end
            
          end else begin
            // Calculation complete
            state <= DONE;
            result <= expected_value;
            done <= 1'b1;
          end
        end
        
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule