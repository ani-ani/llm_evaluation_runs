module find_common_elements (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr0_0, input wire [7:0] arr0_1, input wire [7:0] arr0_2, input wire [7:0] arr0_3,
    input wire [7:0] arr0_4, input wire [7:0] arr0_5, input wire [7:0] arr0_6, input wire [7:0] arr0_7,
    input wire [7:0] arr1_0, input wire [7:0] arr1_1, input wire [7:0] arr1_2, input wire [7:0] arr1_3,
    input wire [7:0] arr1_4, input wire [7:0] arr1_5, input wire [7:0] arr1_6, input wire [7:0] arr1_7,
    input wire [7:0] arr2_0, input wire [7:0] arr2_1, input wire [7:0] arr2_2, input wire [7:0] arr2_3,
    input wire [7:0] arr2_4, input wire [7:0] arr2_5, input wire [7:0] arr2_6, input wire [7:0] arr2_7,
    input wire [3:0] len0, input wire [3:0] len1, input wire [3:0] len2,
    output reg [63:0] result,
    output reg [3:0] result_count,
    output reg done
);

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CHECK   = 3'd1;
    localparam [2:0] VALIDATE = 3'd2;
    localparam [2:0] STORE   = 3'd3;
    localparam [2:0] NEXT    = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] idx0;
    reg [3:0] result_idx;
    reg [7:0] candidate;
    reg found1, found2;
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx0 <= 4'd0;
            result_idx <= 4'd0;
            result_count <= 4'd0;
            result <= 64'd0;
            done <= 1'b0;
            candidate <= 8'd0;
            found1 <= 1'b0;
            found2 <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        idx0 <= 4'd0;
                        result_idx <= 4'd0;
                        result_count <= 4'd0;
                        result <= 64'd0;
                    end
                end
                CHECK: begin
                    candidate <= arr0_0;
                    found1 <= 1'b0;
                    found2 <= 1'b0;
                end
                VALIDATE: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        if (arr1_0 == candidate) found1 <= 1'b1;
                        if (arr2_0 == candidate) found2 <= 1'b1;
                    end
                end
                STORE: begin
                    if (found1 && found2 && result_idx < 8) begin
                        result[result_idx*8 +: 8] <= candidate;
                        result_count <= result_count + 1'b1;
                        result_idx <= result_idx + 1'b1;
                    end
                end
                NEXT: begin
                    idx0 <= idx0 + 1'b1;
                end
                COMPLETE: begin
                    done <= 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CHECK;
            CHECK: next_state = VALIDATE;
            VALIDATE: next_state = STORE;
            STORE: next_state = NEXT;
            NEXT: next_state = (idx0 < len0 - 1'b1) ? CHECK : COMPLETE;
            COMPLETE: if (!start) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule