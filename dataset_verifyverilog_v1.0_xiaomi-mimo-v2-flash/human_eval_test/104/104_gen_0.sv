module DigitFilterSorter(
    input clk,
    input rst_n,
    input start,
    input [7:0] input_0,
    input [7:0] input_1,
    input [7:0] input_2,
    input [7:0] input_3,
    input [7:0] input_4,
    input [7:0] input_5,
    input [7:0] input_6,
    input [7:0] input_7,
    input [3:0] input_len,
    output reg [7:0] output_0,
    output reg [7:0] output_1,
    output reg [7:0] output_2,
    output reg [7:0] output_3,
    output reg [7:0] output_4,
    output reg [7:0] output_5,
    output reg [7:0] output_6,
    output reg [7:0] output_7,
    output reg [3:0] output_len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CHECK_START = 3'd1;
    localparam [2:0] CHECK_DIGIT = 3'd2;
    localparam [2:0] SORT        = 3'd3;
    localparam [2:0] DONE_STATE  = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] input_buffer[0:7];
    reg [7:0] result_buffer[0:7];
    reg [3:0] input_idx, next_input_idx;
    reg [3:0] output_idx, next_output_idx;
    reg [7:0] current_num, next_current_num;
    reg [7:0] temp_num, next_temp_num;
    reg [2:0] digit_count, next_digit_count;
    reg valid_flag, next_valid_flag;
    
    // Sorting registers
    reg [2:0] sort_pass, next_sort_pass;
    reg [2:0] sort_idx, next_sort_idx;
    reg [7:0] temp_swap, next_temp_swap;
    
    reg [7:0] cycle_count, next_cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Output register array for easy assignment
    reg [7:0] outputs[0:7];
    
    integer i;

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_idx <= 4'd0;
            output_idx <= 4'd0;
            current_num <= 8'd0;
            temp_num <= 8'd0;
            digit_count <= 3'd0;
            valid_flag <= 1'b0;
            sort_pass <= 3'd0;
            sort_idx <= 3'd0;
            temp_swap <= 8'd0;
            cycle_count <= 8'd0;
            output_0 <= 8'd0;
            output_1 <= 8'd0;
            output_2 <= 8'd0;
            output_3 <= 8'd0;
            output_4 <= 8'd0;
            output_5 <= 8'd0;
            output_6 <= 8'd0;
            output_7 <= 8'd0;
            output_len <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                input_buffer[i] <= 8'd0;
                result_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            input_idx <= next_input_idx;
            output_idx <= next_output_idx;
            current_num <= next_current_num;
            temp_num <= next_temp_num;
            digit_count <= next_digit_count;
            valid_flag <= next_valid_flag;
            sort_pass <= next_sort_pass;
            sort_idx <= next_sort_idx;
            temp_swap <= next_temp_swap;
            cycle_count <= next_cycle_count;
            
            // Assign outputs from result buffer when done
            if (state == DONE_STATE) begin
                output_0 <= result_buffer[0];
                output_1 <= result_buffer[1];
                output_2 <= result_buffer[2];
                output_3 <= result_buffer[3];
                output_4 <= result_buffer[4];
                output_5 <= result_buffer[5];
                output_6 <= result_buffer[6];
                output_7 <= result_buffer[7];
                output_len <= output_idx;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
            
            // Load inputs on start
            if (start && state == IDLE) begin
                input_buffer[0] <= input_0;
                input_buffer[1] <= input_1;
                input_buffer[2] <= input_2;
                input_buffer[3] <= input_3;
                input_buffer[4] <= input_4;
                input_buffer[5] <= input_5;
                input_buffer[6] <= input_6;
                input_buffer[7] <= input_7;
                for (i = 0; i < 8; i = i + 1) begin
                    result_buffer[i] <= 8'd0;
                end
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        next_input_idx = input_idx;
        next_output_idx = output_idx;
        next_current_num = current_num;
        next_temp_num = temp_num;
        next_digit_count = digit_count;
        next_valid_flag = valid_flag;
        next_sort_pass = sort_pass;
        next_sort_idx = sort_idx;
        next_temp_swap = temp_swap;
        next_cycle_count = cycle_count;

        case (state)
            IDLE: begin
                next_input_idx = 4'd0;
                next_output_idx = 4'd0;
                next_digit_count = 3'd0;
                next_valid_flag = 1'b1;
                next_sort_pass = 3'd0;
                next_sort_idx = 3'd0;
                next_cycle_count = 8'd0;
                if (start) begin
                    if (input_len == 4'd0) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = CHECK_START;
                    end
                end
            end

            CHECK_START: begin
                if (input_idx >= input_len) begin
                    next_state = SORT;
                    next_input_idx = 4'd0;
                end else begin
                    next_current_num = input_buffer[input_idx];
                    next_temp_num = input_buffer[input_idx];
                    next_valid_flag = 1'b1;
                    next_digit_count = 3'd0;
                    next_state = CHECK_DIGIT;
                end
            end

            CHECK_DIGIT: begin
                next_cycle_count = cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else if (temp_num == 8'd0) begin
                    if (digit_count == 3'd0) begin
                        next_valid_flag = 1'b0;
                    end
                    if (valid_flag && next_valid_flag) begin
                        result_buffer[output_idx] = current_num;
                        next_output_idx = output_idx + 4'd1;
                    end
                    next_input_idx = input_idx + 4'd1;
                    next_state = CHECK_START;
                end else begin
                    // Check digit (last digit of temp_num)
                    if ((temp_num[3:0] == 4'd0) || (temp_num[0] == 1'b0)) begin
                        next_valid_flag = 1'b0;
                    end
                    // Divide by 10 (approximation for unsigned)
                    if (temp_num >= 8'd10) begin
                        next_temp_num = temp_num - 8'd10;
                        // Check if we can subtract more
                        if (next_temp_num >= 8'd10) begin
                            next_temp_num = next_temp_num - 8'd10;
                            if (next_temp_num >= 8'd10) begin
                                next_temp_num = next_temp_num - 8'd10;
                                if (next_temp_num >= 8'd10) begin
                                    next_temp_num = next_temp_num - 8'd10;
                                    if (next_temp_num >= 8'd10) begin
                                        next_temp_num = next_temp_num - 8'd10;
                                        if (next_temp_num >= 8'd10) begin
                                            next_temp_num = next_temp_num - 8'd10;
                                            if (next_temp_num >= 8'd10) begin
                                                next_temp_num = next_temp_num - 8'd10;
                                                if (next_temp_num >= 8'd10) begin
                                                    next_temp_num = next_temp_num - 8'd10;
                                                    if (next_temp_num >= 8'd10) begin
                                                        next_temp_num = next_temp_num - 8'd10;
                                                        if (next_temp_num >= 8'd10) begin
                                                            next_temp_num = next_temp_num - 8'd10;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end else begin
                        next_temp_num = 8'd0;
                    end
                    next_digit_count = digit_count + 3'd1;
                end
            end

            SORT: begin
                next_cycle_count = cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else if (sort_pass >= 3'd7) begin
                    next_state = DONE_STATE;
                end else if (sort_idx >= output_idx - 4'd1) begin
                    next_sort_pass = sort_pass + 3'd1;
                    next_sort_idx = 3'd0;
                end else begin
                    // Bubble sort comparison
                    if (result_buffer[sort_idx] > result_buffer[sort_idx + 3'd1]) begin
                        next_temp_swap = result_buffer[sort_idx];
                        result_buffer[sort_idx] = result_buffer[sort_idx + 3'd1];
                        result_buffer[sort_idx + 3'd1] = next_temp_swap;
                    end
                    next_sort_idx = sort_idx + 3'd1;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule