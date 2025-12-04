module string_to_fixed (
  input clk,
  input rst_n,
  input start,
  input [63:0] str1,
  input [63:0] str2,
  output reg [31:0] val1,
  output reg [31:0] val2,
  output reg is_str1,
  output reg is_str2,
  output reg done
);

  // State encoding
  localparam IDLE = 0;
  localparam CHECK_CHARS = 1;
  localparam CALC_INTEGER = 2;
  localparam CALC_FRACTION = 3;
  localparam DONE = 4;

  // State and cycle tracking
  reg [2:0] state, next_state;
  reg [2:0] cycle_count;
  
  // Character checking results
  reg [7:0] invalid_char1, invalid_char2;
  reg [2:0] dot_count1, dot_count2;
  reg [2:0] dot_pos1, dot_pos2;
  
  // Calculation results
  reg [31:0] int_val1, int_val2;
  reg [31:0] frac_val1, frac_val2;
  reg [2:0] frac_digits1, frac_digits2;
  
  // Valid flags
  reg valid1, valid2;
  
  // Output pipeline registers for 8-cycle latency
  reg [31:0] val1_pipe [7:0];
  reg [31:0] val2_pipe [7:0];
  reg is_str1_pipe [7:0];
  reg is_str2_pipe [7:0];
  reg done_pipe [7:0];

  // Function to convert string to integer
  function [31:0] str_to_int;
    input [63:0] str;
    input [2:0] dot_pos;
    integer i;
    reg [31:0] result;
    begin
      result = 0;
      for (i = 0; i < 8; i = i + 1) begin
        if (i < dot_pos) begin
          result = result * 10 + (str[8*i+7:8*i] - 8'd48);
        end
      end
      str_to_int = result;
    end
  endfunction

  // Function to convert string to fixed-point fraction
  function [31:0] str_to_frac_fixed;
    input [63:0] str;
    input [2:0] dot_pos;
    input [2:0] frac_digits;
    integer i;
    reg [31:0] fraction;
    reg [31:0] multiplier;
    begin
      fraction = 0;
      for (i = 0; i < 8; i = i + 1) begin
        if (i > dot_pos) begin
          fraction = fraction * 10 + (str[8*i+7:8*i] - 8'd48);
        end
      end
      
      // Calculate multiplier = 65536 / (10^frac_digits)
      case (frac_digits)
        0: multiplier = 65536;
        1: multiplier = 6554;    // 65536 / 10
        2: multiplier = 655;     // 65536 / 100
        3: multiplier = 66;      // 65536 / 1000
        4: multiplier = 7;       // 65536 / 10000
        default: multiplier = 0;
      endcase
      
      str_to_frac_fixed = (fraction * multiplier) >> 16;
    end
  endfunction

  // State machine sequential logic
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      
      if (state == IDLE) begin
        cycle_count <= 0;
      end else if (state == DONE) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count == 7) begin
          done <= 1;
        end
      end else begin
        cycle_count <= cycle_count + 1;
      end
    end
  end

  // State machine combinational logic
  always @(*) begin
    next_state = state;
    
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_CHARS;
        end
      end
      
      CHECK_CHARS: begin
        next_state = CALC_INTEGER;
      end
      
      CALC_INTEGER: begin
        if (cycle_count == 1) begin
          next_state = CALC_FRACTION;
        end
      end
      
      CALC_FRACTION: begin
        if (cycle_count == 1) begin
          next_state = DONE;
        end
      end
      
      DONE: begin
        if (cycle_count == 7) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Character checking and calculation logic
  always @(posedge clk) begin
    if (!rst_n) begin
      int_val1 <= 0;
      int_val2 <= 0;
      frac_val1 <= 0;
      frac_val2 <= 0;
      valid1 <= 0;
      valid2 <= 0;
      is_str1 <= 0;
      is_str2 <= 0;
    end else begin
      case (state)
        CHECK_CHARS: begin
          // Check each character for validity
          invalid_char1 = 0;
          invalid_char2 = 0;
          dot_count1 = 0;
          dot_count2 = 0;
          dot_pos1 = 8;
          dot_pos2 = 8;
          
          for (int i = 0; i < 8; i++) begin
            // Check str1
            if (!((str1[8*i+7:8*i] >= 8'd48 && str1[8*i+7:8*i] <= 8'd57) ||
                  str1[8*i+7:8*i] == 8'd46)) begin
              invalid_char1[i] = 1;
            end
            if (str1[8*i+7:8*i] == 8'd46) begin
              dot_count1 = dot_count1 + 1;
              dot_pos1 = i;
            end
            
            // Check str2
            if (!((str2[8*i+7:8*i] >= 8'd48 && str2[8*i+7:8*i] <= 8'd57) ||
                  str2[8*i+7:8*i] == 8'd46)) begin
              invalid_char2[i] = 1;
            end
            if (str2[8*i+7:8*i] == 8'd46) begin
              dot_count2 = dot_count2 + 1;
              dot_pos2 = i;
            end
          end
          
          // Determine validity
          valid1 = ~( |invalid_char1 ) && (dot_count1 <= 1);
          valid2 = ~( |invalid_char2 ) && (dot_count2 <= 1);
          
          // Set is_str flags for invalid strings
          is_str1 = ~valid1;
          is_str2 = ~valid2;
          
          // Calculate fractional digits count
          if (dot_pos1 == 8) begin
            frac_digits1 = 0;
          end else begin
            frac_digits1 = 7 - dot_pos1;
          end
          
          if (dot_pos2 == 8) begin
            frac_digits2 = 0;
          end else begin
            frac_digits2 = 7 - dot_pos2;
          end
        end
        
        CALC_INTEGER: begin
          if (valid1) begin
            int_val1 = str_to_int(str1, dot_pos1);
          end else begin
            int_val1 = 0;
          end
          
          if (valid2) begin
            int_val2 = str_to_int(str2, dot_pos2);
          end else begin
            int_val2 = 0;
          end
        end
        
        CALC_FRACTION: begin
          if (valid1) begin
            frac_val1 = str_to_frac_fixed(str1, dot_pos1, frac_digits1);
          end else begin
            frac_val1 = 0;
          end
          
          if (valid2) begin
            frac_val2 = str_to_frac_fixed(str2, dot_pos2, frac_digits2);
          end else begin
            frac_val2 = 0;
          end
        end
        
        DONE: begin
          // Combine integer and fractional parts
          if (valid1) begin
            val1 = (int_val1 << 16) + frac_val1;
          end else begin
            val1 = 0;
          end
          
          if (valid2) begin
            val2 = (int_val2 << 16) + frac_val2;
          end else begin
            val2 = 0;
          end
        end
      endcase
    end
  end

  // Output pipeline for 8-cycle latency
  always @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) begin
        val1_pipe[i] <= 0;
        val2_pipe[i] <= 0;
        is_str1_pipe[i] <= 0;
        is_str2_pipe[i] <= 0;
        done_pipe[i] <= 0;
      end
    end else begin
      val1_pipe[0] <= val1;
      val2_pipe[0] <= val2;
      is_str1_pipe[0] <= is_str1;
      is_str2_pipe[0] <= is_str2;
      done_pipe[0] <= done;
      
      for (int i = 1; i < 8; i++) begin
        val1_pipe[i] <= val1_pipe[i-1];
        val2_pipe[i] <= val2_pipe[i-1];
        is_str1_pipe[i] <= is_str1_pipe[i-1];
        is_str2_pipe[i] <= is_str2_pipe[i-1];
        done_pipe[i] <= done_pipe[i-1];
      end
    end
  end

  // Final output assignment
  assign val1 = val1_pipe[7];
  assign val2 = val2_pipe[7];
  assign is_str1 = is_str1_pipe[7];
  assign is_str2 = is_str2_pipe[7];
  assign done = done_pipe[7];

endmodule