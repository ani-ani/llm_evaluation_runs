module grade_converter(
    input [31:0] gpa0, gpa1, gpa2, gpa3,
    output reg [23:0] grade0, grade1, grade2, grade3
);

    // Define ASCII values
    localparam [7:0] ASCII_A = 8'h41;
    localparam [7:0] ASCII_B = 8'h42;
    localparam [7:0] ASCII_C = 8'h43;
    localparam [7:0] ASCII_D = 8'h44;
    localparam [7:0] ASCII_E = 8'h45;
    localparam [7:0] ASCII_PLUS = 8'h2b;
    localparam [7:0] ASCII_MINUS = 8'h2d;
    localparam [7:0] ASCII_SPACE = 8'h20;

    // Define grade boundaries in Q16.16 format
    localparam [31:0] GPA_4_0 = 32'd262144;  // 4.0 * 65536
    localparam [31:0] GPA_3_7 = 32'd242483;  // 3.7 * 65536
    localparam [31:0] GPA_3_3 = 32'd216268;  // 3.3 * 65536
    localparam [31:0] GPA_3_0 = 32'd196608;  // 3.0 * 65536
    localparam [31:0] GPA_2_7 = 32'd176947;  // 2.7 * 65536
    localparam [31:0] GPA_2_3 = 32'd150732;  // 2.3 * 65536
    localparam [31:0] GPA_2_0 = 32'd131072;  // 2.0 * 65536
    localparam [31:0] GPA_1_7 = 32'd111411;  // 1.7 * 65536
    localparam [31:0] GPA_1_3 = 32'd85196;   // 1.3 * 65536
    localparam [31:0] GPA_1_0 = 32'd65536;   // 1.0 * 65536
    localparam [31:0] GPA_0_7 = 32'd45875;   // 0.7 * 65536
    localparam [31:0] GPA_0_0 = 32'd0;       // 0.0

    // Function to convert GPA to grade
    function [23:0] gpa_to_grade(input [31:0] gpa);
        if (gpa >= GPA_4_0) begin
            gpa_to_grade = {ASCII_A, ASCII_PLUS, ASCII_SPACE};
        end else if (gpa >= GPA_3_7) begin
            gpa_to_grade = {ASCII_A, ASCII_SPACE, ASCII_SPACE};
        end else if (gpa >= GPA_3_3) begin
            gpa_to_grade = {ASCII_A, ASCII_MINUS, ASCII_SPACE};
        end else if (gpa >= GPA_3_0) begin
            gpa_to_grade = {ASCII_B, ASCII_PLUS, ASCII_SPACE};
        end else if (gpa >= GPA_2_7) begin
            gpa_to_grade = {ASCII_B, ASCII_SPACE, ASCII_SPACE};
        end else if (gpa >= GPA_2_3) begin
            gpa_to_grade = {ASCII_B, ASCII_MINUS, ASCII_SPACE};
        end else if (gpa >= GPA_2_0) begin
            gpa_to_grade = {ASCII_C, ASCII_PLUS, ASCII_SPACE};
        end else if (gpa >= GPA_1_7) begin
            gpa_to_grade = {ASCII_C, ASCII_SPACE, ASCII_SPACE};
        end else if (gpa >= GPA_1_3) begin
            gpa_to_grade = {ASCII_C, ASCII_MINUS, ASCII_SPACE};
        end else if (gpa >= GPA_1_0) begin
            gpa_to_grade = {ASCII_D, ASCII_PLUS, ASCII_SPACE};
        end else if (gpa >= GPA_0_7) begin
            gpa_to_grade = {ASCII_D, ASCII_SPACE, ASCII_SPACE};
        end else if (gpa > GPA_0_0) begin
            gpa_to_grade = {ASCII_D, ASCII_MINUS, ASCII_SPACE};
        end else begin
            gpa_to_grade = {ASCII_E, ASCII_SPACE, ASCII_SPACE};
        end
    endfunction

    // Combinational logic for all grades
    always @(*) begin
        grade0 = gpa_to_grade(gpa0);
        grade1 = gpa_to_grade(gpa1);
        grade2 = gpa_to_grade(gpa2);
        grade3 = gpa_to_grade(gpa3);
    end

endmodule