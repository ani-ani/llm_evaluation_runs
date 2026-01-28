module find_first_missing (
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
    input wire [2:0] len,  // Number of valid elements (1-8)
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SEARCHING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [2:0] start_idx;
    reg [2:0] end_idx;
    reg [2:0] mid_idx;
    reg [7:0] arr_start;
    reg [7:0] arr_mid;

    // Combinational block for array access and mid calculation
    always @(*) begin
        // Select arr_start
        case (start_idx)
            3'd0: arr_start = arr_0;
            3'd1: arr_start = arr_1;
            3'd2: arr_start = arr_2;
            3'd3: arr_start = arr_3;
            3'd4: arr_start = arr_4;
            3'd5: arr_start = arr_5;
            3'd6: arr_start = arr_6;
            3'd7: arr_start = arr_7;
            default: arr_start = 8'hFF;
        endcase

        // Select arr_mid
        case (mid_idx)
            3'd0: arr_mid = arr_0;
            3'd1: arr_mid = arr_1;
            3'd2: arr_mid = arr_2;
            3'd3: arr_mid = arr_3;
            3'd4: arr_mid = arr_4;
            3'd5: arr_mid = arr_5;
            3'd6: arr_mid = arr_6;
            3'd7: arr_mid = arr_7;
            default: arr_mid = 8'hFF;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            start_idx <= 3'd0;
            end_idx <= 3'd0;
            mid_idx <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCHING;
                        start_idx <= 3'd0;
                        // Cap end_idx at 7 (8 elements total)
                        if (len > 3'd7) begin
                            end_idx <= 3'd7;
                        end else begin
                            end_idx <= len - 3'd1;
                        end
                    end
                end

                SEARCHING: begin
                    // Binary search logic
                    if (start_idx > end_idx) begin
                        // Missing element found at end_idx + 1
                        result <= end_idx + 3'd1;
                        state <= DONE_STATE;
                    end else if (start_idx != arr_start) begin
                        // Missing element found at start_idx
                        result <= start_idx;
                        state <= DONE_STATE;
                    end else begin
                        // Continue search
                        mid_idx <= (start_idx + end_idx) >> 1;
                        if (arr_mid == mid_idx) begin
                            // Search right half
                            start_idx <= mid_idx + 3'd1;
                        end else begin
                            // Search left half
                            end_idx <= mid_idx - 3'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule