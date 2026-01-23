module find_first_occurrence(
    input clk,
    input rst_n,
    input start,
    input [7:0] target,
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] ARRAY_SIZE = 4'd8;
    localparam [3:0] DATA_WIDTH = 4'd8;
    localparam [3:0] INDEX_WIDTH = 4'd4;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] left, right, mid;
    reg [7:0] result_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SEARCH;
                else
                    next_state = IDLE;
            end
            SEARCH: begin
                if (cycle_count >= MAX_CYCLES || (left > right))
                    next_state = COMPLETE;
                else
                    next_state = SEARCH;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            left <= 4'd0;
            right <= 4'd7;
            mid <= 4'd0;
            result_index <= 8'd255;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    left <= 4'd0;
                    right <= 4'd7;
                    result_index <= 8'd255;
                end
                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    mid <= left + (right - left) / 2;
                    if (arr[mid] == target) begin
                        result_index <= mid;
                        right <= mid - 1;
                    end else if (arr[mid] < target) begin
                        left <= mid + 1;
                    end else begin
                        right <= mid - 1;
                    end
                end
                COMPLETE: begin
                    if (result_index == 8'd255)
                        result <= 8'd255;
                    else
                        result <= result_index;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule