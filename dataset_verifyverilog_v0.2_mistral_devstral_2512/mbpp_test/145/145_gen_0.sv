module max_diff (
  input [7:0] arr_0,
  input [7:0] arr_1,
  input [7:0] arr_2,
  input [7:0] arr_3,
  input [7:0] arr_4,
  input [7:0] arr_5,
  input [7:0] arr_6,
  input [7:0] arr_7,
  input [2:0] valid_count,
  output [7:0] max_diff_result
);

  reg [7:0] min_val;
  reg [7:0] max_val;
  reg [7:0] current_val;

  always @* begin
    min_val = 8'b11111111; // Initialize to maximum signed value
    max_val = 8'b00000000; // Initialize to minimum signed value

    case (valid_count)
      3'b001: begin
        current_val = arr_0;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
      end
      3'b010: begin
        current_val = arr_0;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_1;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
      end
      3'b011: begin
        current_val = arr_0;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_1;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_2;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
      end
      3'b100: begin
        current_val = arr_0;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_1;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_2;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_3;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
      end
      3'b101: begin
        current_val = arr_0;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_1;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_2;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_3;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_4;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
      end
      3'b110: begin
        current_val = arr_0;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_1;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_2;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_3;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_4;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_5;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
      end
      3'b111: begin
        current_val = arr_0;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_1;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_2;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_3;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_4;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_5;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_6;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
      end
      default: begin
        current_val = arr_0;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_1;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_2;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_3;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_4;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_5;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_6;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
        current_val = arr_7;
        min_val = (current_val < min_val) ? current_val : min_val;
        max_val = (current_val > max_val) ? current_val : max_val;
      end
    endcase

    max_diff_result = max_val - min_val;
  end

endmodule