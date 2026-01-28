module grade_converter(
    input [31:0] gpa0,
    input [31:0] gpa1,
    input [31:0] gpa2,
    input [31:0] gpa3,
    output reg [23:0] grade0,
    output reg [23:0] grade1,
    output reg [23:0] grade2,
    output reg [23:0] grade3
);

    // Q16.16 constants for grade boundaries
    localparam [31:0] GPA_4_0 = 32'h00040000; // 4.0
    localparam [31:0] GPA_3_7 = 32'h003C0000; // 3.7 (approx)
    localparam [31:0] GPA_3_3 = 32'h00340000; // 3.3 (approx)
    localparam [31:0] GPA_3_0 = 32'h00300000; // 3.0
    localparam [31:0] GPA_2_7 = 32'h002B0000; // 2.7 (approx)
    localparam [31:0] GPA_2_3 = 32'h00240000; // 2.3 (approx)
    localparam [31:0] GPA_2_0 = 32'h00200000; // 2.0
    localparam [31:0] GPA_1_7 = 32'h001B0000; // 1.7 (approx)
    localparam [31:0] GPA_1_3 = 32'h00140000; // 1.3 (approx)
    localparam [31:0] GPA_1_0 = 32'h00100000; // 1.0
    localparam [31:0] GPA_0_7 = 32'h000B0000; // 0.7 (approx)

    // ASCII constants
    localparam [7:0] CHAR_A = 8'h41;
    localparam [7:0] CHAR_B = 8'h42;
    localparam [7:0] CHAR_C = 8'h43;
    localparam [7:0] CHAR_D = 8'h44;
    localparam [7:0] CHAR_E = 8'h45;
    localparam [7:0] CHAR_PLUS = 8'h2b;
    localparam [7:0] CHAR_MINUS = 8'h2d;
    localparam [7:0] CHAR_SPACE = 8'h20;

    // Grade definitions (24-bit concatenated characters)
    localparam [23:0] GRADE_A_PLUS = {CHAR_A, CHAR_PLUS, CHAR_SPACE};
    localparam [23:0] GRADE_A = {CHAR_A, CHAR_SPACE, CHAR_SPACE};
    localparam [23:0] GRADE_A_MINUS = {CHAR_A, CHAR_MINUS, CHAR_SPACE};
    localparam [23:0] GRADE_B_PLUS = {CHAR_B, CHAR_PLUS, CHAR_SPACE};
    localparam [23:0] GRADE_B = {CHAR_B, CHAR_SPACE, CHAR_SPACE};
    localparam [23:0] GRADE_B_MINUS = {CHAR_B, CHAR_MINUS, CHAR_SPACE};
    localparam [23:0] GRADE_C_PLUS = {CHAR_C, CHAR_PLUS, CHAR_SPACE};
    localparam [23:0] GRADE_C = {CHAR_C, CHAR_SPACE, CHAR_SPACE};
    localparam [23:0] GRADE_C_MINUS = {CHAR_C, CHAR_MINUS, CHAR_SPACE};
    localparam [23:0] GRADE_D_PLUS = {CHAR_D, CHAR_PLUS, CHAR_SPACE};
    localparam [23:0] GRADE_D = {CHAR_D, CHAR_SPACE, CHAR_SPACE};
    localparam [23:0] GRADE_D_MINUS = {CHAR_D, CHAR_MINUS, CHAR_SPACE};
    localparam [23:0] GRADE_E = {CHAR_E, CHAR_SPACE, CHAR_SPACE};

    always @(*) begin
        // Process GPA0
        if (gpa0 == 32'd0) begin
            grade0 = GRADE_E;
        end else if (gpa0 >= GPA_4_0) begin
            grade0 = GRADE_A_PLUS;
        end else if (gpa0 >= GPA_3_7) begin
            grade0 = GRADE_A;
        end else if (gpa0 >= GPA_3_3) begin
            grade0 = GRADE_A_MINUS;
        end else if (gpa0 >= GPA_3_0) begin
            grade0 = GRADE_B_PLUS;
        end else if (gpa0 >= GPA_2_7) begin
            grade0 = GRADE_B;
        end else if (gpa0 >= GPA_2_3) begin
            grade0 = GRADE_B_MINUS;
        end else if (gpa0 >= GPA_2_0) begin
            grade0 = GRADE_C_PLUS;
        end else if (gpa0 >= GPA_1_7) begin
            grade0 = GRADE_C;
        end else if (gpa0 >= GPA_1_3) begin
            grade0 = GRADE_C_MINUS;
        end else if (gpa0 >= GPA_1_0) begin
            grade0 = GRADE_D_PLUS;
        end else if (gpa0 >= GPA_0_7) begin
            grade0 = GRADE_D;
        end else begin
            grade0 = GRADE_D_MINUS;
        end

        // Process GPA1
        if (gpa1 == 32'd0) begin
            grade1 = GRADE_E;
        end else if (gpa1 >= GPA_4_0) begin
            grade1 = GRADE_A_PLUS;
        end else if (gpa1 >= GPA_3_7) begin
            grade1 = GRADE_A;
        end else if (gpa1 >= GPA_3_3) begin
            grade1 = GRADE_A_MINUS;
        end else if (gpa1 >= GPA_3_0) begin
            grade1 = GRADE_B_PLUS;
        end else if (gpa1 >= GPA_2_7) begin
            grade1 = GRADE_B;
        end else if (gpa1 >= GPA_2_3) begin
            grade1 = GRADE_B_MINUS;
        end else if (gpa1 >= GPA_2_0) begin
            grade1 = GRADE_C_PLUS;
        end else if (gpa1 >= GPA_1_7) begin
            grade1 = GRADE_C;
        end else if (gpa1 >= GPA_1_3) begin
            grade1 = GRADE_C_MINUS;
        end else if (gpa1 >= GPA_1_0) begin
            grade1 = GRADE_D_PLUS;
        end else if (gpa1 >= GPA_0_7) begin
            grade1 = GRADE_D;
        end else begin
            grade1 = GRADE_D_MINUS;
        end

        // Process GPA2
        if (gpa2 == 32'd0) begin
            grade2 = GRADE_E;
        end else if (gpa2 >= GPA_4_0) begin
            grade2 = GRADE_A_PLUS;
        end else if (gpa2 >= GPA_3_7) begin
            grade2 = GRADE_A;
        end else if (gpa2 >= GPA_3_3) begin
            grade2 = GRADE_A_MINUS;
        end else if (gpa2 >= GPA_3_0) begin
            grade2 = GRADE_B_PLUS;
        end else if (gpa2 >= GPA_2_7) begin
            grade2 = GRADE_B;
        end else if (gpa2 >= GPA_2_3) begin
            grade2 = GRADE_B_MINUS;
        end else if (gpa2 >= GPA_2_0) begin
            grade2 = GRADE_C_PLUS;
        end else if (gpa2 >= GPA_1_7) begin
            grade2 = GRADE_C;
        end else if (gpa2 >= GPA_1_3) begin
            grade2 = GRADE_C_MINUS;
        end else if (gpa2 >= GPA_1_0) begin
            grade2 = GRADE_D_PLUS;
        end else if (gpa2 >= GPA_0_7) begin
            grade2 = GRADE_D;
        end else begin
            grade2 = GRADE_D_MINUS;
        end

        // Process GPA3
        if (gpa3 == 32'd0) begin
            grade3 = GRADE_E;
        end else if (gpa3 >= GPA_4_0) begin
            grade3 = GRADE_A_PLUS;
        end else if (gpa3 >= GPA_3_7) begin
            grade3 = GRADE_A;
        end else if (gpa3 >= GPA_3_3) begin
            grade3 = GRADE_A_MINUS;
        end else if (gpa3 >= GPA_3_0) begin
            grade3 = GRADE_B_PLUS;
        end else if (gpa3 >= GPA_2_7) begin
            grade3 = GRADE_B;
        end else if (gpa3 >= GPA_2_3) begin
            grade3 = GRADE_B_MINUS;
        end else if (gpa3 >= GPA_2_0) begin
            grade3 = GRADE_C_PLUS;
        end else if (gpa3 >= GPA_1_7) begin
            grade3 = GRADE_C;
        end else if (gpa3 >= GPA_1_3) begin
            grade3 = GRADE_C_MINUS;
        end else if (gpa3 >= GPA_1_0) begin
            grade3 = GRADE_D_PLUS;
        end else if (gpa3 >= GPA_0_7) begin
            grade3 = GRADE_D;
        end else begin
            grade3 = GRADE_D_MINUS;
        end
    end

endmodule