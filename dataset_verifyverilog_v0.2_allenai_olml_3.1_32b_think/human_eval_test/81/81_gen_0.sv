module grade_converter (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [31:0] gpa_fixed,
    output reg [39:0] letter_grade,
    output reg done
);

parameter IDLE = 3'd0;
parameter COMPARE_1 = 3'd1;
parameter COMPARE_2 = 3'd2;
parameter DONE_STATE = 3'd3;

reg [2:0] state;
reg [39:0] grade_reg;

parameter THRESHOLD_A_PLUS = 32'h00040000;
parameter THRESHOLD_A = 32'h0003B333;
parameter THRESHOLD_A_MINUS = 32'h00034CCC;
parameter THRESHOLD_B_PLUS = 32'h00030000;
parameter THRESHOLD_B = 32'h0002B333;
parameter THRESHOLD_B_MINUS = 32'h00024CCC;
parameter THRESHOLD_C_PLUS = 32'h00020000;

parameter GRADE_A_PLUS = 40'h412B202020;
parameter GRADE_A = 40'h4120202020;
parameter GRADE_A_MINUS = 40'h412D202020;
parameter GRADE_B_PLUS = 40'h422B202020;
parameter GRADE_B = 40'h4220202020;
parameter GRADE_B_MINUS = 40'h422D202020;
parameter GRADE_C_PLUS = 40'h432B202020;

parameter THRESHOLD_C = 32'h0001B333;
parameter THRESHOLD_C_MINUS = 32'h00014CCC;
parameter THRESHOLD_D_PLUS = 32'h00010000;
parameter THRESHOLD_D = 32'h0000B333;
parameter THRESHOLD_D_MINUS = 32'h00000000;

parameter GRADE_C = 40'h4320202020;
parameter GRADE_C_MINUS = 40'h432D202020;
parameter GRADE_D_PLUS = 40'h442B202020;
parameter GRADE_D = 40'h4420202020;
parameter GRADE_D_MINUS = 40'h442D202020;
parameter GRADE_E = 40'h4520202020;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        grade_reg <= 40'h0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= COMPARE_1;
                end else begin
                    state <= IDLE;
                end
            end
            COMPARE_1: begin
                if (gpa_fixed >= THRESHOLD_A_PLUS) begin
                    grade_reg <= GRADE_A_PLUS;
                end else if (gpa_fixed >= THRESHOLD_A) begin
                    grade_reg <= GRADE_A;
                end else if (gpa_fixed >= THRESHOLD_A_MINUS) begin
                    grade_reg <= GRADE_A_MINUS;
                end else if (gpa_fixed >= THRESHOLD_B_PLUS) begin
                    grade_reg <= GRADE_B_PLUS;
                end else if (gpa_fixed >= THRESHOLD_B) begin
                    grade_reg <= GRADE_B;
                end else if (gpa_fixed >= THRESHOLD_B_MINUS) begin
                    grade_reg <= GRADE_B_MINUS;
                end else if (gpa_fixed >= THRESHOLD_C_PLUS) begin
                    grade_reg <= GRADE_C_PLUS;
                end
                state <= COMPARE_2;
            end
            COMPARE_2: begin
                if (grade_reg == 40'h0) begin
                    if (gpa_fixed >= THRESHOLD_C) begin
                        grade_reg <= GRADE_C;
                    end else if (gpa_fixed >= THRESHOLD_C_MINUS) begin
                        grade_reg <= GRADE_C_MINUS;
                    end else if (gpa_fixed >= THRESHOLD_D_PLUS) begin
                        grade_reg <= GRADE_D_PLUS;
                    end else if (gpa_fixed >= THRESHOLD_D) begin
                        grade_reg <= GRADE_D;
                    end else if (gpa_fixed >= THRESHOLD_D_MINUS) begin
                        if (gpa_fixed == 0) begin
                            grade_reg <= GRADE_E;
                        end else begin
                            grade_reg <= GRADE_D_MINUS;
                        end
                    end else begin
                        grade_reg <= GRADE_D_MINUS;
                    end
                end
                state <= DONE_STATE;
            end
            DONE_STATE: begin
                state <= DONE_STATE;
            end
        endcase
    end
end

assign letter_grade = grade_reg;
assign done = (state == DONE_STATE);

endmodule