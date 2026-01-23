module grade_converter(
    input clk,
    input rst_n,
    input start,
    input [31:0] gpa_fixed,
    output reg [39:0] letter_grade,
    output reg done
);

    // Threshold constants in Q16.16 format
    localparam [31:0] THRESH_4_0 = 32'h00040000;
    localparam [31:0] THRESH_3_7 = 32'h0003B333;
    localparam [31:0] THRESH_3_3 = 32'h00034CCC;
    localparam [31:0] THRESH_3_0 = 32'h00030000;
    localparam [31:0] THRESH_2_7 = 32'h0002B333;
    localparam [31:0] THRESH_2_3 = 32'h00024CCC;
    localparam [31:0] THRESH_2_0 = 32'h00020000;
    localparam [31:0] THRESH_1_7 = 32'h0001B333;
    localparam [31:0] THRESH_1_3 = 32'h00014CCC;
    localparam [31:0] THRESH_1_0 = 32'h00010000;
    localparam [31:0] THRESH_0_7 = 32'h0000B333;
    localparam [31:0] THRESH_0_0 = 32'h00000000;

    // ASCII constants for output characters
    // 5 bytes: [39:32], [31:24], [23:16], [15:8], [7:0]
    // A+   -> 0x41 0x2B 0x20 0x20 0x20
    // A    -> 0x41 0x20 0x20 0x20 0x20
    // A-   -> 0x41 0x2D 0x20 0x20 0x20
    // B+   -> 0x42 0x2B 0x20 0x20 0x20
    // B    -> 0x42 0x20 0x20 0x20 0x20
    // B-   -> 0x42 0x2D 0x20 0x20 0x20
    // C+   -> 0x43 0x2B 0x20 0x20 0x20
    // C    -> 0x43 0x20 0x20 0x20 0x20
    // C-   -> 0x43 0x2D 0x20 0x20 0x20
    // D+   -> 0x44 0x2B 0x20 0x20 0x20
    // D    -> 0x44 0x20 0x20 0x20 0x20
    // D-   -> 0x44 0x2D 0x20 0x20 0x20
    // E    -> 0x45 0x20 0x20 0x20 0x20
    
    localparam [39:0] GRADE_A_PLUS = {8'h41, 8'h2B, 8'h20, 8'h20, 8'h20}; // 0x412B202020 (Note: order might need adjustment based on standard, assuming big-endian byte order for the 5 byte stream)
    localparam [39:0] GRADE_A      = {8'h41, 8'h20, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_A_MINUS = {8'h41, 8'h2D, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_B_PLUS = {8'h42, 8'h2B, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_B      = {8'h42, 8'h20, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_B_MINUS = {8'h42, 8'h2D, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_C_PLUS = {8'h43, 8'h2B, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_C      = {8'h43, 8'h20, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_C_MINUS = {8'h43, 8'h2D, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_D_PLUS = {8'h44, 8'h2B, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_D      = {8'h44, 8'h20, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_D_MINUS = {8'h44, 8'h2D, 8'h20, 8'h20, 8'h20};
    localparam [39:0] GRADE_E      = {8'h45, 8'h20, 8'h20, 8'h20, 8'h20};

    // State encoding
    localparam [1:0] IDLE      = 2'b00;
    localparam [1:0] COMPARE_1 = 2'b01;
    localparam [1:0] COMPARE_2 = 2'b10;
    localparam [1:0] DONE      = 2'b11;

    reg [1:0] state;
    reg [31:0] gpa_reg;
    
    // Next state logic and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            letter_grade <= 40'd0;
            gpa_reg <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        gpa_reg <= gpa_fixed;
                        state <= COMPARE_1;
                    end
                end

                COMPARE_1: begin
                    // Compare thresholds >= 2.0
                    if (gpa_reg >= THRESH_4_0) begin
                        letter_grade <= GRADE_A_PLUS;
                        state <= DONE;
                    end else if (gpa_reg >= THRESH_3_7) begin
                        letter_grade <= GRADE_A;
                        state <= DONE;
                    end else if (gpa_reg >= THRESH_3_3) begin
                        letter_grade <= GRADE_A_MINUS;
                        state <= DONE;
                    end else if (gpa_reg >= THRESH_3_0) begin
                        letter_grade <= GRADE_B_PLUS;
                        state <= DONE;
                    end else if (gpa_reg >= THRESH_2_7) begin
                        letter_grade <= GRADE_B;
                        state <= DONE;
                    end else if (gpa_reg >= THRESH_2_3) begin
                        letter_grade <= GRADE_B_MINUS;
                        state <= DONE;
                    end else if (gpa_reg >= THRESH_2_0) begin
                        letter_grade <= GRADE_C_PLUS;
                        state <= DONE;
                    end else begin
                        state <= COMPARE_2;
                    end
                end

                COMPARE_2: begin
                    // Compare thresholds < 2.0
                    // Note: Spec says GPA == 0.0 -> E, but also GPA >= 0.0 -> D-.
                    // Since it is inclusive >=, we check higher brackets first.
                    // 1.7, 1.3, 1.0, 0.7, 0.0
                    if (gpa_reg >= THRESH_1_7) begin
                        letter_grade <= GRADE_C;
                    end else if (gpa_reg >= THRESH_1_3) begin
                        letter_grade <= GRADE_C_MINUS;
                    end else if (gpa_reg >= THRESH_1_0) begin
                        letter_grade <= GRADE_D_PLUS;
                    end else if (gpa_reg >= THRESH_0_7) begin
                        letter_grade <= GRADE_D;
                    end else if (gpa_reg >= THRESH_0_0) begin
                        // This covers > 0.0 (assuming non-negative inputs) and == 0.0
                        // Spec requires specific handling for 0.0 -> E, while 0.0+ -> D-
                        // However, since we are in the >= 0.0 bucket, and we've checked >= 0.7, we know it's < 0.7.
                        // If strictly == 0.0, output E, else D-.
                        if (gpa_reg == THRESH_0_0) begin
                            letter_grade <= GRADE_E;
                        end else begin
                            letter_grade <= GRADE_D_MINUS;
                        end
                    end else begin
                        // Should not happen for non-negative GPA
                        letter_grade <= GRADE_E;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE; // Ready for next conversion
                end
            endcase
        end
    end

endmodule
