module pancake_sort(
    input clk,
    input rst_n,
    input start,
    input [2:0] idx,
    input [7:0] data_in,
    output reg [7:0] sorted_out [0:7],
    output reg done,
    output reg [2:0] debug_state
);

    // State encoding
    localparam IDLE = 3'd0;
    localparam FIND_MAX = 3'd1;
    localparam FLIP_TO_END = 3'd2;
    localparam UPDATE_SIZE = 3'd3;
    localparam DONE = 3'd4;

    // Internal registers
    reg [7:0] arr [0:7];
    reg [2:0] current_size;
    reg [2:0] max_idx;
    reg [2:0] i;
    reg [2:0] j;
    reg [7:0] temp_max;
    reg [7:0] temp_val;
    reg [2:0] state;
    reg [2:0] next_state;
    reg start_hold;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && start_hold)
                    next_state = FIND_MAX;
                else
                    next_state = IDLE;
            end
            FIND_MAX: begin
                if (current_size <= 1)
                    next_state = DONE;
                else if (i >= current_size - 1)
                    next_state = FLIP_TO_END;
                else
                    next_state = FIND_MAX;
            end
            FLIP_TO_END: begin
                if (j >= (max_idx + 1) >> 1)
                    next_state = UPDATE_SIZE;
                else
                    next_state = FLIP_TO_END;
            end
            UPDATE_SIZE: begin
                if (current_size <= 1)
                    next_state = DONE;
                else
                    next_state = FIND_MAX;
            end
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            debug_state <= IDLE;
            current_size <= 3'd0;
            start_hold <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            temp_max <= 8'd0;
            max_idx <= 3'd0;
            sorted_out <= '{8{8'd0}};
            arr <= '{8{8'd0}};
        end else begin
            state <= next_state;
            debug_state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        start_hold <= 1'b1;
                        // Load initial data based on idx
                        arr[idx] <= data_in;
                        if (start_hold) begin
                            current_size <= 3'd8;
                            i <= 3'd0;
                            j <= 3'd0;
                            temp_max <= arr[0];
                            max_idx <= 3'd0;
                        end
                    end else begin
                        start_hold <= 1'b0;
                    end
                end

                FIND_MAX: begin
                    if (i < current_size - 1) begin
                        i <= i + 1'b1;
                        if (arr[i + 1'b1] > temp_max) begin
                            temp_max <= arr[i + 1'b1];
                            max_idx <= i + 1'b1;
                        end
                    end
                end

                FLIP_TO_END: begin
                    if (j < (max_idx + 1) >> 1) begin
                        // Swap arr[j] and arr[max_idx - j]
                        arr[j] <= arr[max_idx - j];
                        arr[max_idx - j] <= arr[j];
                        j <= j + 1'b1;
                    end
                end

                UPDATE_SIZE: begin
                    // Swap max (now at position 0) with last element of unsorted part
                    arr[0] <= arr[current_size - 1];
                    arr[current_size - 1] <= arr[0];
                    current_size <= current_size - 1'b1;
                    // Reset for next iteration
                    i <= 3'd0;
                    j <= 3'd0;
                    temp_max <= arr[0];
                    max_idx <= 3'd0;
                end

                DONE: begin
                    done <= 1'b1;
                    sorted_out <= arr;
                end
            endcase
        end
    end

endmodule