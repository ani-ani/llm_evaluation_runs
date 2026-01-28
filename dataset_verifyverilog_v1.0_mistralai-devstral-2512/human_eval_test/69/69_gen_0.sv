module find_max_frequency_match(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [8:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COUNT   = 3'd1;
    localparam [2:0] EVAL    = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Frequency counters (16 entries for 16 possible unique values)
    reg [7:0] freq_value [0:15];
    reg [7:0] freq_count [0:15];
    reg [3:0] freq_index;

    // Sorting registers
    reg [7:0] sorted_arr [0:15];
    reg [3:0] sort_i, sort_j;
    reg [7:0] temp;

    // Evaluation registers
    reg [7:0] current_value;
    reg [7:0] current_count;
    reg [3:0] eval_index;
    reg [7:0] max_valid;
    reg [1:0] eval_state;

    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 9'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            // Initialize frequency counters
            for (freq_index = 0; freq_index < 16; freq_index = freq_index + 1) begin
                freq_value[freq_index] <= 8'd0;
                freq_count[freq_index] <= 8'd0;
            end
            // Initialize sorting registers
            for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                sorted_arr[sort_i] <= 8'd0;
            end
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            eval_index <= 4'd0;
            max_valid <= 8'd0;
            eval_state <= 2'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COUNT;
                        // Copy input array to sorted array
                        for (sort_i = 0; sort_i < 16; sort_i = sort_i + 1) begin
                            if (sort_i < len)
                                sorted_arr[sort_i] <= arr[sort_i];
                            else
                                sorted_arr[sort_i] <= 8'd0;
                        end
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COUNT: begin
                    // Bubble sort implementation
                    if (sort_i < 15) begin
                        if (sort_j < 15 - sort_i) begin
                            if (sorted_arr[sort_j] > sorted_arr[sort_j + 1]) begin
                                temp <= sorted_arr[sort_j];
                                sorted_arr[sort_j] <= sorted_arr[sort_j + 1];
                                sorted_arr[sort_j + 1] <= temp;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        // Sorting complete, move to frequency counting
                        next_state <= EVAL;
                        // Initialize frequency counters
                        for (freq_index = 0; freq_index < 16; freq_index = freq_index + 1) begin
                            freq_value[freq_index] <= 8'd0;
                            freq_count[freq_index] <= 8'd0;
                        end
                        freq_index <= 4'd0;
                        current_value <= 8'd0;
                        current_count <= 8'd0;
                        eval_index <= 4'd0;
                        max_valid <= 8'd0;
                        eval_state <= 2'd0;
                    end
                end

                EVAL: begin
                    // Count frequencies of each value
                    if (eval_state == 2'd0) begin
                        if (eval_index < len) begin
                            if (eval_index == 0 || sorted_arr[eval_index] != current_value) begin
                                // New value found
                                if (current_value != 8'd0) begin
                                    // Store previous count
                                    freq_value[freq_index] <= current_value;
                                    freq_count[freq_index] <= current_count;
                                    freq_index <= freq_index + 4'd1;
                                end
                                current_value <= sorted_arr[eval_index];
                                current_count <= 8'd1;
                            end else begin
                                current_count <= current_count + 8'd1;
                            end
                            eval_index <= eval_index + 4'd1;
                        end else begin
                            // Store last count
                            freq_value[freq_index] <= current_value;
                            freq_count[freq_index] <= current_count;
                            freq_index <= freq_index + 4'd1;
                            eval_state <= 2'd1;
                            eval_index <= 4'd0;
                            max_valid <= 8'd0;
                        end
                    end else if (eval_state == 2'd1) begin
                        // Find maximum valid value
                        if (eval_index < freq_index) begin
                            if (freq_count[eval_index] >= freq_value[eval_index] &&
                                freq_value[eval_index] > max_valid) begin
                                max_valid <= freq_value[eval_index];
                            end
                            eval_index <= eval_index + 4'd1;
                        end else begin
                            next_state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    if (max_valid == 8'd0) begin
                        result <= 9'd255; // -1 in 9-bit signed
                    end else begin
                        result <= max_valid;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
                result <= 9'd0;
            end
        end
    end

endmodule