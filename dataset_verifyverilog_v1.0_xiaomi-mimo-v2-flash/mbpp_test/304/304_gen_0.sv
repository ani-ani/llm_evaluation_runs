module find_element (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] range_left [0:3],
    input [3:0] range_right [0:3],
    input [1:0] num_ranges,
    input [1:0] rotations,
    input [3:0] target_index,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] FETCH     = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] GET_VALUE = 3'd5;
    localparam [2:0] FINISH    = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] current_index;
    reg [3:0] range_idx; // Iterates from (num_ranges-1) down to 0
    reg [3:0] L, R;
    reg [7:0] temp_result;
    reg [7:0] temp_arr [0:15]; // Copy of array for consistent reading

    integer i;

    // State transition logic
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
            end

            INIT: begin
                next_state = FETCH;
            end

            FETCH: begin
                next_state = CHECK;
            end

            CHECK: begin
                if ((current_index >= L) && (current_index <= R)) begin
                    next_state = UPDATE;
                end else begin
                    // Range doesn't cover index, move to next range
                    if (range_idx == 4'd0) begin
                        next_state = GET_VALUE;
                    end else begin
                        next_state = FETCH;
                    end
                end
            end

            UPDATE: begin
                // Index updated, move to next range
                if (range_idx == 4'd0) begin
                    next_state = GET_VALUE;
                end else begin
                    next_state = FETCH;
                end
            end

            GET_VALUE: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            current_index <= 4'd0;
            range_idx <= 4'd0;
            L <= 4'd0;
            R <= 4'd0;
            temp_result <= 8'd0;
            // Initialize temp_arr to avoid X propagation
            for (i = 0; i < 16; i = i + 1) begin
                temp_arr[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                INIT: begin
                    current_index <= target_index;
                    // Initialize range_idx to num_ranges - 1
                    case (num_ranges)
                        2'd0: range_idx <= 4'd0; // Not used if num_ranges=0
                        2'd1: range_idx <= 4'd0;
                        2'd2: range_idx <= 4'd1;
                        2'd3: range_idx <= 4'd2;
                        default: range_idx <= 4'd0;
                    endcase
                    // Copy array to internal regs for consistent reading
                    temp_arr[0] <= arr[0];
                    temp_arr[1] <= arr[1];
                    temp_arr[2] <= arr[2];
                    temp_arr[3] <= arr[3];
                    temp_arr[4] <= arr[4];
                    temp_arr[5] <= arr[5];
                    temp_arr[6] <= arr[6];
                    temp_arr[7] <= arr[7];
                    temp_arr[8] <= arr[8];
                    temp_arr[9] <= arr[9];
                    temp_arr[10] <= arr[10];
                    temp_arr[11] <= arr[11];
                    temp_arr[12] <= arr[12];
                    temp_arr[13] <= arr[13];
                    temp_arr[14] <= arr[14];
                    temp_arr[15] <= arr[15];
                end

                FETCH: begin
                    L <= range_left[range_idx[1:0]];
                    R <= range_right[range_idx[1:0]];
                end

                CHECK: begin
                    // Logic handled in next_state logic
                end

                UPDATE: begin
                    if (current_index == L) begin
                        current_index <= R;
                    end else begin
                        current_index <= current_index - 4'd1;
                    end
                    // Decrement range index for next iteration
                    if (range_idx > 4'd0) begin
                        range_idx <= range_idx - 4'd1;
                    end
                end

                GET_VALUE: begin
                    temp_result <= temp_arr[current_index];
                end

                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule