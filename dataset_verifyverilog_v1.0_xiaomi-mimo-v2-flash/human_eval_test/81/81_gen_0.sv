module gpa_to_letter_converter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] gpa_array,
    input wire [2:0] num_grades,
    output reg [31:0] letter_grades,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Register declarations
    reg [1:0] state;
    reg [2:0] index;
    reg [2:0] num_grades_reg;
    reg [63:0] gpa_buffer;
    reg [31:0] letter_grades_reg;
    reg [3:0] letter_code;
    reg [7:0] current_gpa;

    // Combinational threshold signals
    wire [7:0] gpa_threshold;
    assign gpa_threshold = current_gpa;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            letter_grades <= 32'd0;
            letter_grades_reg <= 32'd0;
            done <= 1'b0;
            index <= 3'd0;
            num_grades_reg <= 3'd0;
            gpa_buffer <= 64'd0;
            current_gpa <= 8'd0;
            letter_code <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    if (start) begin
                        gpa_buffer <= gpa_array;
                        num_grades_reg <= num_grades;
                        letter_grades_reg <= 32'd0;
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (index < num_grades_reg) begin
                        // Extract current GPA (8 bits per grade)
                        case (index)
                            3'd0: current_gpa <= gpa_buffer[7:0];
                            3'd1: current_gpa <= gpa_buffer[15:8];
                            3'd2: current_gpa <= gpa_buffer[23:16];
                            3'd3: current_gpa <= gpa_buffer[31:24];
                            3'd4: current_gpa <= gpa_buffer[39:32];
                            3'd5: current_gpa <= gpa_buffer[47:40];
                            3'd6: current_gpa <= gpa_buffer[55:48];
                            3'd7: current_gpa <= gpa_buffer[63:56];
                            default: current_gpa <= 8'd0;
                        endcase

                        // Determine letter grade (combinational)
                        if (current_gpa == 8'd255) begin // 4.0 * 256 = 1024, but 8-bit max is 255
                            // Need to handle 4.0 case: 1024/256 = 4.0, but 8-bit Q8.8 stores 0-255
                            // Assuming Q8.8: integer part in [7:4], fractional in [3:0]
                            // Actually, let's interpret: 8 bits where 255 = 4.0
                            // So 4.0 = 255, 0.0 = 0
                            // Adjust thresholds: divide by 4
                            // 4.0 = 255, 3.7 = 239, 3.3 = 212, etc.
                            letter_code <= 4'd0; // A+
                        end else if (current_gpa > 8'd239) begin // > 3.7
                            letter_code <= 4'd1; // A
                        end else if (current_gpa > 8'd212) begin // > 3.3
                            letter_code <= 4'd2; // A-
                        end else if (current_gpa > 8'd192) begin // > 3.0
                            letter_code <= 4'd3; // B+
                        end else if (current_gpa > 8'd171) begin // > 2.7
                            letter_code <= 4'd4; // B
                        end else if (current_gpa > 8'd150) begin // > 2.3
                            letter_code <= 4'd5; // B-
                        end else if (current_gpa > 8'd128) begin // > 2.0
                            letter_code <= 4'd6; // C+
                        end else if (current_gpa > 8'd111) begin // > 1.7
                            letter_code <= 4'd7; // C
                        end else if (current_gpa > 8'd85) begin // > 1.3
                            letter_code <= 4'd8; // C-
                        end else if (current_gpa > 8'd64) begin // > 1.0
                            letter_code <= 4'd9; // D+
                        end else if (current_gpa > 8'd46) begin // > 0.7
                            letter_code <= 4'd10; // D
                        end else if (current_gpa > 8'd0) begin // > 0.0
                            letter_code <= 4'd11; // D-
                        end else begin // == 0.0
                            letter_code <= 4'd13; // E
                        end

                        // Pack into result
                        letter_grades_reg[index*4 +: 4] <= letter_code;
                        index <= index + 3'd1;
                    end else begin
                        letter_grades <= letter_grades_reg;
                        state <= FINISH;
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