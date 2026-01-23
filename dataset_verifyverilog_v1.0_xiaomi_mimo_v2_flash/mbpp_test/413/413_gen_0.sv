module ExtractNthElement (
    input clk,
    input rst_n,
    input start,
    input [1:0] field_select,
    input [7:0] name_0_0,
    input [7:0] name_0_1,
    input [7:0] name_0_2,
    input [7:0] name_0_3,
    input [7:0] name_0_4,
    input [7:0] name_0_5,
    input [7:0] name_0_6,
    input [7:0] name_0_7,
    input [7:0] name_0_8,
    input [7:0] name_0_9,
    input [7:0] name_0_10,
    input [7:0] name_0_11,
    input [7:0] name_0_12,
    input [7:0] name_0_13,
    input [7:0] name_0_14,
    input [7:0] name_0_15,
    input [7:0] name_1_0,
    input [7:0] name_1_1,
    input [7:0] name_1_2,
    input [7:0] name_1_3,
    input [7:0] name_1_4,
    input [7:0] name_1_5,
    input [7:0] name_1_6,
    input [7:0] name_1_7,
    input [7:0] name_1_8,
    input [7:0] name_1_9,
    input [7:0] name_1_10,
    input [7:0] name_1_11,
    input [7:0] name_1_12,
    input [7:0] name_1_13,
    input [7:0] name_1_14,
    input [7:0] name_1_15,
    input [7:0] name_2_0,
    input [7:0] name_2_1,
    input [7:0] name_2_2,
    input [7:0] name_2_3,
    input [7:0] name_2_4,
    input [7:0] name_2_5,
    input [7:0] name_2_6,
    input [7:0] name_2_7,
    input [7:0] name_2_8,
    input [7:0] name_2_9,
    input [7:0] name_2_10,
    input [7:0] name_2_11,
    input [7:0] name_2_12,
    input [7:0] name_2_13,
    input [7:0] name_2_14,
    input [7:0] name_2_15,
    input [7:0] name_3_0,
    input [7:0] name_3_1,
    input [7:0] name_3_2,
    input [7:0] name_3_3,
    input [7:0] name_3_4,
    input [7:0] name_3_5,
    input [7:0] name_3_6,
    input [7:0] name_3_7,
    input [7:0] name_3_8,
    input [7:0] name_3_9,
    input [7:0] name_3_10,
    input [7:0] name_3_11,
    input [7:0] name_3_12,
    input [7:0] name_3_13,
    input [7:0] name_3_14,
    input [7:0] name_3_15,
    input [7:0] score1_0,
    input [7:0] score1_1,
    input [7:0] score1_2,
    input [7:0] score1_3,
    input [7:0] score2_0,
    input [7:0] score2_1,
    input [7:0] score2_2,
    input [7:0] score2_3,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] EXTRACT   = 2'd1;
    localparam [1:0] FINISH    = 2'd2;

    reg [1:0] state;
    reg [7:0] temp_result_0;
    reg [7:0] temp_result_1;
    reg [7:0] temp_result_2;
    reg [7:0] temp_result_3;

    // Combinational extraction logic
    always @(*) begin
        case (field_select)
            2'd0: begin
                // Extract first character of each name
                temp_result_0 = name_0_0;
                temp_result_1 = name_1_0;
                temp_result_2 = name_2_0;
                temp_result_3 = name_3_0;
            end
            2'd1: begin
                // Extract score1
                temp_result_0 = score1_0;
                temp_result_1 = score1_1;
                temp_result_2 = score1_2;
                temp_result_3 = score1_3;
            end
            2'd2: begin
                // Extract score2
                temp_result_0 = score2_0;
                temp_result_1 = score2_1;
                temp_result_2 = score2_2;
                temp_result_3 = score2_3;
            end
            default: begin
                temp_result_0 = 8'd0;
                temp_result_1 = 8'd0;
                temp_result_2 = 8'd0;
                temp_result_3 = 8'd0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= EXTRACT;
                    end
                end

                EXTRACT: begin
                    // Register the combinatorial result
                    result_0 <= temp_result_0;
                    result_1 <= temp_result_1;
                    result_2 <= temp_result_2;
                    result_3 <= temp_result_3;
                    state <= FINISH;
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