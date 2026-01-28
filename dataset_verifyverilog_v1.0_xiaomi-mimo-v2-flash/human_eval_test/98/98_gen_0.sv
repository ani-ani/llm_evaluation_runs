module vowel_count_at_even_indices (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_0,
    input wire [7:0] char_1,
    input wire [7:0] char_2,
    input wire [7:0] char_3,
    input wire [7:0] char_4,
    input wire [7:0] char_5,
    input wire [7:0] char_6,
    input wire [7:0] char_7,
    input wire [7:0] char_8,
    input wire [7:0] char_9,
    input wire [7:0] char_10,
    input wire [7:0] char_11,
    input wire [7:0] char_12,
    input wire [7:0] char_13,
    input wire [7:0] char_14,
    input wire [7:0] char_15,
    input wire [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] current_index;
    reg [3:0] count;
    reg [7:0] current_char;
    reg is_vowel;

    // Combinational logic for vowel detection
    always @(*) begin
        is_vowel = 1'b0;
        case (current_char)
            8'h41, // 'A'
            8'h45, // 'E'
            8'h49, // 'I'
            8'h4F, // 'O'
            8'h55: // 'U'
                is_vowel = 1'b1;
            default: is_vowel = 1'b0;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            current_index <= 4'd0;
            count <= 4'd0;
            current_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    current_index <= 4'd0;
                    count <= 4'd0;
                    if (start) begin
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    // Character selection based on index
                    case (current_index)
                        4'd0:  current_char <= char_0;
                        4'd1:  current_char <= char_1;
                        4'd2:  current_char <= char_2;
                        4'd3:  current_char <= char_3;
                        4'd4:  current_char <= char_4;
                        4'd5:  current_char <= char_5;
                        4'd6:  current_char <= char_6;
                        4'd7:  current_char <= char_7;
                        4'd8:  current_char <= char_8;
                        4'd9:  current_char <= char_9;
                        4'd10: current_char <= char_10;
                        4'd11: current_char <= char_11;
                        4'd12: current_char <= char_12;
                        4'd13: current_char <= char_13;
                        4'd14: current_char <= char_14;
                        4'd15: current_char <= char_15;
                        default: current_char <= 8'd0;
                    endcase

                    // Check vowel if index is even and within length
                    if ((current_index[0] == 1'b0) && (current_index < len) && is_vowel) begin
                        count <= count + 4'd1;
                    end

                    // Increment index or finish
                    if (current_index >= 4'd15 || current_index + 4'd1 >= len) begin
                        state <= FINISH;
                    end else begin
                        current_index <= current_index + 4'd1;
                    end
                end

                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    current_index <= 4'd0;
                    count <= 4'd0;
                    current_char <= 8'd0;
                end
            endcase
        end
    end

endmodule