module gpa_to_letter_grades(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] gpa_array,
    input wire [2:0] num_grades,
    output reg [31:0] letter_grades,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [2:0] current_index;
    reg [7:0] current_gpa;
    reg [3:0] current_grade;
    
    // Thresholds in Q8.8 format (multiplied by 256)
    localparam [9:0] THRESHOLD_A  = 10'd947;  // 3.7 * 256
    localparam [9:0] THRESHOLD_A_MINUS = 10'd845;  // 3.3 * 256
    localparam [9:0] THRESHOLD_B_PLUS = 10'd768;  // 3.0 * 256
    localparam [9:0] THRESHOLD_B = 10'd691;  // 2.7 * 256
    localparam [9:0] THRESHOLD_B_MINUS = 10'd589;  // 2.3 * 256
    localparam [9:0] THRESHOLD_C_PLUS = 10'd512;  // 2.0 * 256
    localparam [9:0] THRESHOLD_C = 10'd435;  // 1.7 * 256
    localparam [9:0] THRESHOLD_C_MINUS = 10'd333;  // 1.3 * 256
    localparam [9:0] THRESHOLD_D_PLUS = 10'd256;  // 1.0 * 256
    localparam [9:0] THRESHOLD_D = 10'd180;  // 0.7 * 256
    localparam [9:0] THRESHOLD_D_MINUS = 10'd0;  // 0.0 * 256
    
    // Grade encoding
    localparam [3:0] GRADE_A_PLUS = 4'd0;
    localparam [3:0] GRADE_A = 4'd1;
    localparam [3:0] GRADE_A_MINUS = 4'd2;
    localparam [3:0] GRADE_B_PLUS = 4'd3;
    localparam [3:0] GRADE_B = 4'd4;
    localparam [3:0] GRADE_B_MINUS = 4'd5;
    localparam [3:0] GRADE_C_PLUS = 4'd6;
    localparam [3:0] GRADE_C = 4'd7;
    localparam [3:0] GRADE_C_MINUS = 4'd8;
    localparam [3:0] GRADE_D_PLUS = 4'd9;
    localparam [3:0] GRADE_D = 4'd10;
    localparam [3:0] GRADE_D_MINUS = 4'd11;
    localparam [3:0] GRADE_E = 4'd13;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 3'd0;
            current_gpa <= 8'd0;
            current_grade <= 4'd0;
            letter_grades <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        current_index <= 3'd0;
                    end
                end
                
                PROCESS: begin
                    // Extract current GPA from array
                    current_gpa <= gpa_array[(current_index * 8) +: 8];
                    
                    // Determine grade based on thresholds
                    if (current_gpa == 8'd1024) begin
                        current_grade <= GRADE_A_PLUS;
                    end else if (current_gpa > THRESHOLD_A) begin
                        current_grade <= GRADE_A;
                    end else if (current_gpa > THRESHOLD_A_MINUS) begin
                        current_grade <= GRADE_A_MINUS;
                    end else if (current_gpa > THRESHOLD_B_PLUS) begin
                        current_grade <= GRADE_B_PLUS;
                    end else if (current_gpa > THRESHOLD_B) begin
                        current_grade <= GRADE_B;
                    end else if (current_gpa > THRESHOLD_B_MINUS) begin
                        current_grade <= GRADE_B_MINUS;
                    end else if (current_gpa > THRESHOLD_C_PLUS) begin
                        current_grade <= GRADE_C_PLUS;
                    end else if (current_gpa > THRESHOLD_C) begin
                        current_grade <= GRADE_C;
                    end else if (current_gpa > THRESHOLD_C_MINUS) begin
                        current_grade <= GRADE_C_MINUS;
                    end else if (current_gpa > THRESHOLD_D_PLUS) begin
                        current_grade <= GRADE_D_PLUS;
                    end else if (current_gpa > THRESHOLD_D) begin
                        current_grade <= GRADE_D;
                    end else if (current_gpa > THRESHOLD_D_MINUS) begin
                        current_grade <= GRADE_D_MINUS;
                    end else begin
                        current_grade <= GRADE_E;
                    end
                    
                    // Pack grade into output
                    letter_grades[(current_index * 4) +: 4] <= current_grade;
                    
                    // Move to next grade or finish
                    if (current_index == num_grades) begin
                        state <= FINISH;
                    end else begin
                        current_index <= current_index + 1'b1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule