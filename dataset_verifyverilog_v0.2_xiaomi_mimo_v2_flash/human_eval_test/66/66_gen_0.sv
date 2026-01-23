module digitSum(
    input [7:0] char0,
    input [7:0] char1,
    input [7:0] char2,
    input [7:0] char3,
    input [7:0] char4,
    input [7:0] char5,
    input [7:0] char6,
    input [7:0] char7,
    output [15:0] sum
);

    // Helper logic to determine if each character is an uppercase letter (A-Z: 65-90)
    wire is_upper0 = (char0 >= 8'd65) && (char0 <= 8'd90);
    wire is_upper1 = (char1 >= 8'd65) && (char1 <= 8'd90);
    wire is_upper2 = (char2 >= 8'd65) && (char2 <= 8'd90);
    wire is_upper3 = (char3 >= 8'd65) && (char3 <= 8'd90);
    wire is_upper4 = (char4 >= 8'd65) && (char4 <= 8'd90);
    wire is_upper5 = (char5 >= 8'd65) && (char5 <= 8'd90);
    wire is_upper6 = (char6 >= 8'd65) && (char6 <= 8'd90);
    wire is_upper7 = (char7 >= 8'd65) && (char7 <= 8'd90);

    // Conditional addition: add char value if uppercase, else add 0
    wire [15:0] term0 = is_upper0 ? {8'b0, char0} : 16'd0;
    wire [15:0] term1 = is_upper1 ? {8'b0, char1} : 16'd0;
    wire [15:0] term2 = is_upper2 ? {8'b0, char2} : 16'd0;
    wire [15:0] term3 = is_upper3 ? {8'b0, char3} : 16'd0;
    wire [15:0] term4 = is_upper4 ? {8'b0, char4} : 16'd0;
    wire [15:0] term5 = is_upper5 ? {8'b0, char5} : 16'd0;
    wire [15:0] term6 = is_upper6 ? {8'b0, char6} : 16'd0;
    wire [15:0] term7 = is_upper7 ? {8'b0, char7} : 16'd0;

    // Combinational summation
    assign sum = term0 + term1 + term2 + term3 + term4 + term5 + term6 + term7;

endmodule