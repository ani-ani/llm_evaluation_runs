module find_element(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] range_left [0:3],
    input wire [3:0] range_right [0:3],
    input wire [1:0] num_ranges,
    input wire [1:0] rotations,
    input wire [3:0] target_index,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] current_index;
    reg [1:0] range_counter;
    reg [3:0] current_left, current_right;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            current_index <= 4'd0;
            range_counter <= 2'd0;
            current_left <= 4'd0;
            current_right <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            INIT: begin
                current_index = target_index;
                range_counter = num_ranges - 2'd1;
                cycle_count = 8'd0;
                next_state = PROCESS;
            end

            PROCESS: begin
                current_left = range_left[range_counter];
                current_right = range_right[range_counter];

                if ((current_index >= current_left) && (current_index <= current_right)) begin
                    if (current_index == current_left) begin
                        current_index = current_right;
                    end else begin
                        current_index = current_index - 4'd1;
                    end
                end

                if (range_counter == 2'd0) begin
                    next_state = OUTPUT;
                end else begin
                    range_counter = range_counter - 2'd1;
                    cycle_count = cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = PROCESS;
                    end
                end
            end

            OUTPUT: begin
                result = arr[current_index];
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule