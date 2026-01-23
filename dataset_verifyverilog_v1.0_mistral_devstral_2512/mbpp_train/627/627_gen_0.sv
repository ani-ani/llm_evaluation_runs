module find_first_missing(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [2:0] len,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] start_idx;
    reg [2:0] end_idx;
    reg [2:0] mid_idx;
    reg [2:0] shift_count;
    reg [7:0] arr_mid;
    reg [7:0] arr_start;

    // Combinational array access for mid_idx
    always @(*) begin
        case (mid_idx)
            3'd0: arr_mid = arr_0;
            3'd1: arr_mid = arr_1;
            3'd2: arr_mid = arr_2;
            3'd3: arr_mid = arr_3;
            3'd4: arr_mid = arr_4;
            3'd5: arr_mid = arr_5;
            3'd6: arr_mid = arr_6;
            3'd7: arr_mid = arr_7;
            default: arr_mid = 8'd0;
        endcase
    end

    // Combinational array access for start_idx
    always @(*) begin
        case (start_idx)
            3'd0: arr_start = arr_0;
            3'd1: arr_start = arr_1;
            3'd2: arr_start = arr_2;
            3'd3: arr_start = arr_3;
            3'd4: arr_start = arr_4;
            3'd5: arr_start = arr_5;
            3'd6: arr_start = arr_6;
            3'd7: arr_start = arr_7;
            default: arr_start = 8'd0;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            start_idx <= 3'd0;
            end_idx <= 3'd0;
            mid_idx <= 3'd0;
            shift_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                        start_idx <= 3'd0;
                        end_idx <= (len > 3'd7) ? 3'd7 : len - 1'b1;
                        shift_count <= 3'd0;
                    end
                end

                SEARCH: begin
                    if (shift_count < 3'd3) begin
                        shift_count <= shift_count + 1'b1;
                    end else begin
                        shift_count <= 3'd0;
                        mid_idx <= (start_idx + end_idx) >> 1;

                        if (start_idx > end_idx) begin
                            result <= end_idx + 1'b1;
                            state <= FINISH;
                        end else if (start_idx != arr_start) begin
                            result <= start_idx;
                            state <= FINISH;
                        end else if (arr_mid == mid_idx) begin
                            start_idx <= mid_idx + 1'b1;
                        end else begin
                            end_idx <= mid_idx - 1'b1;
                        end
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