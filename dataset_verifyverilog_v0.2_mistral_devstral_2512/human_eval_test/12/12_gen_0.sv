module longest_string(
  input clk,
  input rst_n,
  input [7:0] str0,
  input [7:0] str1,
  input [7:0] str2,
  input [7:0] str3,
  input [7:0] str4,
  input [7:0] str5,
  output reg [7:0] result,
  output reg valid
);

  always @(*) begin
    if (!rst_n) begin
      result = 8'b0;
      valid = 1'b0;
    end else begin
      // Check if all inputs are zero
      if (str0 == 0 && str1 == 0 && str2 == 0 && str3 == 0 && str4 == 0 && str5 == 0) begin
        valid = 1'b0;
        result = 8'b0;
      end else begin
        valid = 1'b1;
        // Cascaded comparison tree with priority to lower indices
        if (str0 >= str1 && str0 >= str2 && str0 >= str3 && str0 >= str4 && str0 >= str5) begin
          result = str0;
        end else if (str1 >= str0 && str1 >= str2 && str1 >= str3 && str1 >= str4 && str1 >= str5) begin
          result = str1;
        end else if (str2 >= str0 && str2 >= str1 && str2 >= str3 && str2 >= str4 && str2 >= str5) begin
          result = str2;
        end else if (str3 >= str0 && str3 >= str1 && str3 >= str2 && str3 >= str4 && str3 >= str5) begin
          result = str3;
        end else if (str4 >= str0 && str4 >= str1 && str4 >= str2 && str4 >= str3 && str4 >= str5) begin
          result = str4;
        end else begin
          result = str5;
        end
      end
    end
  end

endmodule