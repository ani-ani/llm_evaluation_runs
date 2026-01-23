module first_repeated_char (
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
    input wire [4:0] str_len,
    output reg [7:0] result_char,
    output reg result_valid,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [4:0] check_idx;
    reg [4:0] compare_idx;
    reg [7:0] char_to_check;
    reg found_repeat;
    reg [7:0] char_storage_0;
    reg [7:0] char_storage_1;
    reg [7:0] char_storage_2;
    reg [7:0] char_storage_3;
    reg [7:0] char_storage_4;
    reg [7:0] char_storage_5;
    reg [7:0] char_storage_6;
    reg [7:0] char_storage_7;
    reg [7:0] char_storage_8;
    reg [7:0] char_storage_9;
    reg [7:0] char_storage_10;
    reg [7:0] char_storage_11;
    reg [7:0] char_storage_12;
    reg [7:0] char_storage_13;
    reg [7:0] char_storage_14;
    reg [7:0] char_storage_15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_char <= 8'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            check_idx <= 5'd0;
            compare_idx <= 5'd0;
            found_repeat <= 1'b0;
            char_to_check <= 8'd0;
            char_storage_0 <= 8'd0;
            char_storage_1 <= 8'd0;
            char_storage_2 <= 8'd0;
            char_storage_3 <= 8'd0;
            char_storage_4 <= 8'd0;
            char_storage_5 <= 8'd0;
            char_storage_6 <= 8'd0;
            char_storage_7 <= 8'd0;
            char_storage_8 <= 8'd0;
            char_storage_9 <= 8'd0;
            char_storage_10 <= 8'd0;
            char_storage_11 <= 8'd0;
            char_storage_12 <= 8'd0;
            char_storage_13 <= 8'd0;
            char_storage_14 <= 8'd0;
            char_storage_15 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    if (start && str_len > 5'd0) begin
                        state <= CHECKING;
                        check_idx <= 5'd0;
                        compare_idx <= 5'd0;
                        found_repeat <= 1'b0;
                    end
                end

                CHECKING: begin
                    if (!found_repeat && check_idx < str_len) begin
                        case (check_idx)
                            5'd0: char_to_check <= char_0;
                            5'd1: char_to_check <= char_1;
                            5'd2: char_to_check <= char_2;
                            5'd3: char_to_check <= char_3;
                            5'd4: char_to_check <= char_4;
                            5'd5: char_to_check <= char_5;
                            5'd6: char_to_check <= char_6;
                            5'd7: char_to_check <= char_7;
                            5'd8: char_to_check <= char_8;
                            5'd9: char_to_check <= char_9;
                            5'd10: char_to_check <= char_10;
                            5'd11: char_to_check <= char_11;
                            5'd12: char_to_check <= char_12;
                            5'd13: char_to_check <= char_13;
                            5'd14: char_to_check <= char_14;
                            5'd15: char_to_check <= char_15;
                        endcase

                        if (compare_idx < check_idx) begin
                            reg [7:0] stored_char;
                            case (compare_idx)
                                5'd0: stored_char <= char_storage_0;
                                5'd1: stored_char <= char_storage_1;
                                5'd2: stored_char <= char_storage_2;
                                5'd3: stored_char <= char_storage_3;
                                5'd4: stored_char <= char_storage_4;
                                5'd5: stored_char <= char_storage_5;
                                5'd6: stored_char <= char_storage_6;
                                5'd7: stored_char <= char_storage_7;
                                5'd8: stored_char <= char_storage_8;
                                5'd9: stored_char <= char_storage_9;
                                5'd10: stored_char <= char_storage_10;
                                5'd11: stored_char <= char_storage_11;
                                5'd12: stored_char <= char_storage_12;
                                5'd13: stored_char <= char_storage_13;
                                5'd14: stored_char <= char_storage_14;
                                5'd15: stored_char <= char_storage_15;
                            endcase

                            if (char_to_check == stored_char) begin
                                found_repeat <= 1'b1;
                                result_char <= char_to_check;
                                result_valid <= 1'b1;
                                state <= DONE_STATE;
                            end else begin
                                compare_idx <= compare_idx + 5'd1;
                            end
                        end else begin
                            case (check_idx)
                                5'd0: char_storage_0 <= char_to_check;
                                5'd1: char_storage_1 <= char_to_check;
                                5'd2: char_storage_2 <= char_to_check;
                                5'd3: char_storage_3 <= char_to_check;
                                5'd4: char_storage_4 <= char_to_check;
                                5'd5: char_storage_5 <= char_to_check;
                                5'd6: char_storage_6 <= char_to_check;
                                5'd7: char_storage_7 <= char_to_check;
                                5'd8: char_storage_8 <= char_to_check;
                                5'd9: char_storage_9 <= char_to_check;
                                5'd10: char_storage_10 <= char_to_check;
                                5'd11: char_storage_11 <= char_to_check;
                                5'd12: char_storage_12 <= char_to_check;
                                5'd13: char_storage_13 <= char_to_check;
                                5'd14: char_storage_14 <= char_to_check;
                                5'd15: char_storage_15 <= char_to_check;
                            endcase
                            check_idx <= check_idx + 5'd1;
                            compare_idx <= 5'd1;
                        end
                    end else begin
                        state <= DONE_STATE;
                        if (!found_repeat) begin
                            result_valid <= 1'b0;
                            result_char <= 8'd0;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule