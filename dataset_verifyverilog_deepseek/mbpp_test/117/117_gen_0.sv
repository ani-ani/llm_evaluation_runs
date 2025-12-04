module string_to_fixed (
  input clk,
  input rst_n,
  input start,
  input [63:0] str1, str2,
  output reg [31:0] val1, val2,
  output reg is_str1, is_str2,
  output reg done
);

  localparam IDLE = 0;
  localparam CHECK_CHARS = 1;
  localparam CALC_INTEGER = 2;
  localparam CALC_FRACTION = 3;
  localparam DONE = 4;

  reg [2:0] state, next_state;
  reg [3:0] counter;
  
  reg [63:0] str1_reg, str2_reg;
  reg [31:0] integer1, integer2;
  reg [31:0] frac_value1, frac_value2;
  reg invalid1, invalid2;
  reg [3:0] dot_pos1, dot_pos2;
  reg [3:0] frac_digits1, frac_digits2;

  function automatic [15:0] get_frac_part(input [63:0] str, input [3:0] dot_pos, 
                                       input [3:0] frac_digits);
    begin
      reg [31:0] sum = 0;
      for (int i = 0; i < frac_digits; i++) begin
        reg [7:0] ch = str[dot_pos*8 + 8 + i*8 +: 8];
        if (ch >= 8'h30 && ch <=8'h39) begin
          reg [31:0] tmp = ch - 8'h30;
          case (i+1)
            1: tmp = (tmp * 65536) / 10;
            2: tmp = (tmp * 65536) / 100;
            3: tmp = (tmp * 65536) / 1000;
            4: tmp = (tmp * 65536) / 10000;
            5: tmp = (tmp * 65536) / 100000;
            6: tmp = (tmp * 65536) / 1000000;
            7: tmp = (tmp * 65536) / 10000000;
            default: tmp = 0;
          endcase
          sum = sum + tmp;
        end
      end
      get_frac_part = sum[15:0];
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      done <= 0;
      val1 <= 0;
      val2 <= 0;
      is_str1 <= 0;
      is_str2 <= 0;
    end else begin
      case(state)
        IDLE: begin
          done <= 0;
          if (start) begin
            str1_reg <= str1;
            str2_reg <= str2;
            state <= CHECK_CHARS;
            counter <= 0;
          end
        end
        CHECK_CHARS: begin
          invalid1 <= 0;
          invalid2 <= 0;
          dot_pos1 <= 8;
          dot_pos2 <= 8;
          // Check str1
          for (int i = 0; i < 8; i++) begin
            reg [7:0] ch = str1[i*8 +: 8];
            if (!(ch inside {8'h2E, [8'h30:8'h39}]))
              invalid1 <= 1;
            if (ch == 8'h2E) begin
              if (dot_pos1 == 8)
                dot_pos1 <= i;
              else // multiple dots
                invalid1 <= 1;
            end
          end
          // Check str2
          for (int i = 0; i < 8; i++) begin
            reg [7:0] ch = str2[i*8 +: 8];
            if (!(ch inside {8'h2E, [8'h30:8'h39}]))
              invalid2 <= 1;
            if (ch == 8'h2E) begin
              if (dot_pos2 == 8)
                dot_pos2 <= i;
              else
                invalid2 <= 1;
            end
          end
          frac_digits1 <= (dot_pos1 == 8) ? 0 : (8 - dot_pos1 - 1);
          frac_digits2 <= (dot_pos2 == 8) ? 0 : (8 - dot_pos2 - 1);
          state <= CALC_INTEGER;
          counter <= counter + 1;
        end
        CALC_INTEGER: begin
          // Process integer part
          if (!invalid1) begin
            for (int i = 0; i < ((dot_pos1 == 8) ? 8 : dot_pos1); i++) begin
              reg [7:0] ch = str1_reg[i*8 +: 8];
              if (ch >= 8'h30 && ch <=8'h39)
                integer1 = integer1 * 10 + (ch - 8'h30);
            end
          end
          if (!invalid2) begin
            for (int i = 0; i < ((dot_pos2 == 8) ? 8 : dot_pos2); i++) begin
              reg [7:0] ch = str2_reg[i*8 +: 8];
              if (ch >=8'h30 && ch <=8'h39) 
                integer2 = integer2 *10 + (ch - 8'h30);
            end
          end
          state <= CALC_FRACTION;
          counter <= counter + 1;
        end
        CALC_FRACTION: begin
          if (!invalid1)
            frac_value1 <= (invalid1 || frac_digits1 == 0) ? 0 : get_frac_part(str1_reg, dot_pos1, frac_digits1);
          if (!invalid2)
            frac_value2 <= (invalid2 || frac_digits2 == 0) ? 0 : get_frac_part(str2_reg, dot_pos2, frac_digits2);

          if (counter < 6) begin
            counter <= counter + 1;
            state <= CALC_FRACTION;
          end else begin
            state <= DONE;
            counter <= 0;
          end
        end
        DONE: begin
          if (!invalid1)
            val1 <= (integer1 << 16) + frac_value1;
          else
            val1 <= str1_reg[31:0];
          
          if (!invalid2)
            val2 <= (integer2 << 16) + frac_value2;
          else
            val2 <= str2_reg[31:0];
          
          is_str1 <= invalid1;
          is_str2 <= invalid2;
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule