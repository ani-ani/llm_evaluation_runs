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
        // Default values
        result = 8'b0;
        valid = 1'b0;

        // If all inputs are zero, valid remains 0
        if (str0 != 8'b0 || str1 != 8'b0 || str2 != 8'b0 || str3 != 8'b0 || str4 != 8'b0 || str5 != 8'b0) begin
            valid = 1'b1;

            // Cascaded comparison tree with tie-breaking priority (str0 > str1 > ... > str5)
            if (str0 >= str1 && str0 >= str2 && str0 >= str3 && str0 >= str4 && str0 >= str5) begin
                result = str0;
            end else if (str1 >= str2 && str1 >= str3 && str1 >= str4 && str1 >= str5) begin
                result = str1;
            end else if (str2 >= str3 && str2 >= str4 && str2 >= str5) begin
                result = str2;
            end else if (str3 >= str4 && str3 >= str5) begin
                result = str3;
            end else if (str4 >= str5) begin
                result = str4;
            end else begin
                result = str5;
            end
        end
    end

endmodule
