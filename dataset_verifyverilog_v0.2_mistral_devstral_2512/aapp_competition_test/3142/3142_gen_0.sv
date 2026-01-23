module digit_sum_counter (
  input [5:0] A_digits,
  input [5:0] B_digits,
  input [5:0] S_value,
  output [17:0] count,
  output [23:0] min_number
);

  reg [19:0] current_number;
  reg [17:0] count_reg = 0;
  reg [23:0] min_number_reg = 24'h999999;
  reg [3:0] digit_sum;
  reg [3:0] digit;
  reg [5:0] A_reg = A_digits;
  reg [5:0] B_reg = B_digits;
  reg [5:0] S_reg = S_value;

  always @* begin
    count_reg = 0;
    min_number_reg = 24'h999999;

    for (current_number = {A_reg[5:4], A_reg[3:0], 12'h000}; 
         current_number <= {B_reg[5:4], B_reg[3:0], 12'h000};
         current_number = current_number + 1) begin

      digit_sum = 0;

      // Extract and sum each BCD digit
      digit = current_number[23:20];
      case (digit)
        4'h0: digit_sum = digit_sum + 0;
        4'h1: digit_sum = digit_sum + 1;
        4'h2: digit_sum = digit_sum + 2;
        4'h3: digit_sum = digit_sum + 3;
        4'h4: digit_sum = digit_sum + 4;
        4'h5: digit_sum = digit_sum + 5;
        4'h6: digit_sum = digit_sum + 6;
        4'h7: digit_sum = digit_sum + 7;
        4'h8: digit_sum = digit_sum + 8;
        4'h9: digit_sum = digit_sum + 9;
        default: digit_sum = digit_sum + 0;
      endcase

      digit = current_number[19:16];
      case (digit)
        4'h0: digit_sum = digit_sum + 0;
        4'h1: digit_sum = digit_sum + 1;
        4'h2: digit_sum = digit_sum + 2;
        4'h3: digit_sum = digit_sum + 3;
        4'h4: digit_sum = digit_sum + 4;
        4'h5: digit_sum = digit_sum + 5;
        4'h6: digit_sum = digit_sum + 6;
        4'h7: digit_sum = digit_sum + 7;
        4'h8: digit_sum = digit_sum + 8;
        4'h9: digit_sum = digit_sum + 9;
        default: digit_sum = digit_sum + 0;
      endcase

      digit = current_number[15:12];
      case (digit)
        4'h0: digit_sum = digit_sum + 0;
        4'h1: digit_sum = digit_sum + 1;
        4'h2: digit_sum = digit_sum + 2;
        4'h3: digit_sum = digit_sum + 3;
        4'h4: digit_sum = digit_sum + 4;
        4'h5: digit_sum = digit_sum + 5;
        4'h6: digit_sum = digit_sum + 6;
        4'h7: digit_sum = digit_sum + 7;
        4'h8: digit_sum = digit_sum + 8;
        4'h9: digit_sum = digit_sum + 9;
        default: digit_sum = digit_sum + 0;
      endcase

      digit = current_number[11:8];
      case (digit)
        4'h0: digit_sum = digit_sum + 0;
        4'h1: digit_sum = digit_sum + 1;
        4'h2: digit_sum = digit_sum + 2;
        4'h3: digit_sum = digit_sum + 3;
        4'h4: digit_sum = digit_sum + 4;
        4'h5: digit_sum = digit_sum + 5;
        4'h6: digit_sum = digit_sum + 6;
        4'h7: digit_sum = digit_sum + 7;
        4'h8: digit_sum = digit_sum + 8;
        4'h9: digit_sum = digit_sum + 9;
        default: digit_sum = digit_sum + 0;
      endcase

      digit = current_number[7:4];
      case (digit)
        4'h0: digit_sum = digit_sum + 0;
        4'h1: digit_sum = digit_sum + 1;
        4'h2: digit_sum = digit_sum + 2;
        4'h3: digit_sum = digit_sum + 3;
        4'h4: digit_sum = digit_sum + 4;
        4'h5: digit_sum = digit_sum + 5;
        4'h6: digit_sum = digit_sum + 6;
        4'h7: digit_sum = digit_sum + 7;
        4'h8: digit_sum = digit_sum + 8;
        4'h9: digit_sum = digit_sum + 9;
        default: digit_sum = digit_sum + 0;
      endcase

      digit = current_number[3:0];
      case (digit)
        4'h0: digit_sum = digit_sum + 0;
        4'h1: digit_sum = digit_sum + 1;
        4'h2: digit_sum = digit_sum + 2;
        4'h3: digit_sum = digit_sum + 3;
        4'h4: digit_sum = digit_sum + 4;
        4'h5: digit_sum = digit_sum + 5;
        4'h6: digit_sum = digit_sum + 6;
        4'h7: digit_sum = digit_sum + 7;
        4'h8: digit_sum = digit_sum + 8;
        4'h9: digit_sum = digit_sum + 9;
        default: digit_sum = digit_sum + 0;
      endcase

      if (digit_sum == S_reg) begin
        count_reg = count_reg + 1;
        if (current_number < min_number_reg) begin
          min_number_reg = current_number;
        end
      end
    end
  end

  assign count = count_reg;
  assign min_number = min_number_reg;

endmodule