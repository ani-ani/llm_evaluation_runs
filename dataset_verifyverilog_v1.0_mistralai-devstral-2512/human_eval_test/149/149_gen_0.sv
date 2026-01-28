module StringProcessor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] strings [0:7],
    input wire [2:0] valid_count,
    output reg [127:0] result [0:7],
    output reg [2:0] result_count,
    output reg done
);

    // Parameters
    localparam [2:0] STRING_WIDTH = 128;
    localparam [2:0] MAX_STRINGS = 8;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FILTER = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    // State and control signals
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Filtered strings storage
    reg [127:0] filtered_strings [0:7];
    reg [2:0] filtered_count;

    // Sorting variables
    reg [7:0] i, j;
    reg [7:0] sort_i, sort_j;
    reg sort_done;

    // String length calculation
    function [3:0] calculate_length;
        input [127:0] str;
        integer k;
        begin
            for (k = 0; k < 16; k = k + 1) begin
                if (str[8*k +: 8] == 8'd0) begin
                    calculate_length = k;
                end
            end
            calculate_length = 16;
        end
    endfunction

    // String comparison (returns 1 if a < b)
    function [0:0] compare_strings;
        input [127:0] a, b;
        integer k;
        reg [7:0] byte_a, byte_b;
        begin
            for (k = 0; k < 16; k = k + 1) begin
                byte_a = a[8*k +: 8];
                byte_b = b[8*k +: 8];
                if (byte_a != byte_b) begin
                    compare_strings = (byte_a < byte_b);
                end
            end
            compare_strings = 1'b0; // equal
        end
    endfunction

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            filtered_count <= 3'd0;
            result_count <= 3'd0;
            sort_done <= 1'b0;
            i <= 8'd0;
            j <= 8'd0;
            sort_i <= 8'd0;
            sort_j <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FILTER;
                end
            end
            FILTER: begin
                if (i >= valid_count) begin
                    next_state = SORT;
                end
            end
            SORT: begin
                if (sort_done) begin
                    next_state = OUTPUT;
                end
            end
            OUTPUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Filtering logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 8'd0;
            filtered_count <= 3'd0;
        end else if (state == FILTER) begin
            if (i < valid_count) begin
                reg [3:0] str_len;
                str_len = calculate_length(strings[i]);
                if (str_len % 2 == 0) begin
                    filtered_strings[filtered_count] <= strings[i];
                    filtered_count <= filtered_count + 1'b1;
                end
                i <= i + 1'b1;
            end
        end
    end

    // Sorting logic (bubble sort)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_i <= 8'd0;
            sort_j <= 8'd0;
            sort_done <= 1'b0;
        end else if (state == SORT) begin
            if (!sort_done) begin
                if (sort_i < filtered_count - 1) begin
                    if (sort_j < filtered_count - sort_i - 1) begin
                        reg [3:0] len_i, len_j;
                        reg [0:0] cmp_result;
                        len_i = calculate_length(filtered_strings[sort_j]);
                        len_j = calculate_length(filtered_strings[sort_j + 1]);
                        
                        if (len_i > len_j) begin
                            // Swap
                            filtered_strings[sort_j] <= filtered_strings[sort_j + 1];
                            filtered_strings[sort_j + 1] <= filtered_strings[sort_j];
                        end else if (len_i == len_j) begin
                            cmp_result = compare_strings(filtered_strings[sort_j], filtered_strings[sort_j + 1]);
                            if (!cmp_result) begin
                                // Swap if a > b
                                filtered_strings[sort_j] <= filtered_strings[sort_j + 1];
                                filtered_strings[sort_j + 1] <= filtered_strings[sort_j];
                            end
                        end
                        sort_j <= sort_j + 1'b1;
                    end else begin
                        sort_j <= 8'd0;
                        sort_i <= sort_i + 1'b1;
                    end
                end else begin
                    sort_done <= 1'b1;
                end
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_count <= 3'd0;
            done <= 1'b0;
        end else if (state == OUTPUT) begin
            // Copy filtered and sorted strings to result
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                if (k < filtered_count) begin
                    result[k] <= filtered_strings[k];
                end else begin
                    result[k] <= 128'd0;
                end
            end
            result_count <= filtered_count;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE) begin
            cycle_count <= cycle_count + 1'b1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule