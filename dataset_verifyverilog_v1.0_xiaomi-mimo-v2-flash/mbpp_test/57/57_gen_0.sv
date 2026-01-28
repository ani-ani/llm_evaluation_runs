module LargestNumberFromDigits (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] digits [0:7],
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SORTING = 2'd1;
    localparam [1:0] COMBINING = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    // FSM registers
    reg [1:0] state, next_state;
    reg [3:0] sort_stage, next_sort_stage;
    reg [2:0] combine_idx, next_combine_idx;
    reg [31:0] temp_result, next_temp_result;
    reg [7:0] sorted_digits [0:7];
    reg [7:0] next_sorted_digits [0:7];
    reg done_reg, next_done_reg;
    reg [31:0] result_reg, next_result_reg;

    // Timing constants
    localparam [3:0] SORT_STAGES = 4'd7;  // 7 stages for odd-even transposition sort
    localparam [2:0] COMBINE_MAX = 3'd7;  // Maximum 8 elements

    // Combinational sorting network (Odd-Even Transposition Sort)
    // Compare-swap pairs for each stage
    wire [7:0] stage_digits [0:7];
    wire [7:0] stage_swapped [0:7];

    // Helper for compare-swap (descending order)
    function automatic [7:0] compare_swap(input [7:0] a, input [7:0] b);
        begin
            if (a >= b) begin
                compare_swap = a;
            end else begin
                compare_swap = b;
            end
        end
    endfunction

    // Create comparers for each stage
    wire [7:0] pair0_a, pair0_b;
    wire [7:0] pair1_a, pair1_b;
    wire [7:0] pair2_a, pair2_b;
    wire [7:0] pair3_a, pair3_b;

    // Input selection based on stage
    assign pair0_a = (sort_stage[0] == 1'b0) ? sorted_digits[0] : sorted_digits[1];
    assign pair0_b = (sort_stage[0] == 1'b0) ? sorted_digits[1] : sorted_digits[2];
    assign pair1_a = (sort_stage[0] == 1'b0) ? sorted_digits[2] : sorted_digits[3];
    assign pair1_b = (sort_stage[0] == 1'b0) ? sorted_digits[3] : sorted_digits[4];
    assign pair2_a = (sort_stage[0] == 1'b0) ? sorted_digits[4] : sorted_digits[5];
    assign pair2_b = (sort_stage[0] == 1'b0) ? sorted_digits[5] : sorted_digits[6];
    assign pair3_a = (sort_stage[0] == 1'b0) ? sorted_digits[6] : sorted_digits[7];
    assign pair3_b = (sort_stage[0] == 1'b0) ? sorted_digits[7] : sorted_digits[0];

    // Apply compare-swap for odd-even pairs
    wire [7:0] swap0_hi = compare_swap(pair0_a, pair0_b);
    wire [7:0] swap0_lo = compare_swap(pair0_b, pair0_a);
    wire [7:0] swap1_hi = compare_swap(pair1_a, pair1_b);
    wire [7:0] swap1_lo = compare_swap(pair1_b, pair1_a);
    wire [7:0] swap2_hi = compare_swap(pair2_a, pair2_b);
    wire [7:0] swap2_lo = compare_swap(pair2_b, pair2_a);
    wire [7:0] swap3_hi = compare_swap(pair3_a, pair3_b);
    wire [7:0] swap3_lo = compare_swap(pair3_b, pair3_a);

    // Build next stage output
    assign stage_swapped[0] = (sort_stage[0] == 1'b0) ? swap0_hi : swap0_lo;
    assign stage_swapped[1] = (sort_stage[0] == 1'b0) ? swap0_lo : swap0_hi;
    assign stage_swapped[2] = (sort_stage[0] == 1'b0) ? swap1_hi : swap1_lo;
    assign stage_swapped[3] = (sort_stage[0] == 1'b0) ? swap1_lo : swap1_hi;
    assign stage_swapped[4] = (sort_stage[0] == 1'b0) ? swap2_hi : swap2_lo;
    assign stage_swapped[5] = (sort_stage[0] == 1'b0) ? swap2_lo : swap2_hi;
    assign stage_swapped[6] = (sort_stage[0] == 1'b0) ? swap3_hi : swap3_lo;
    assign stage_swapped[7] = (sort_stage[0] == 1'b0) ? swap3_lo : swap3_hi;

    // Next state logic
    always @(*) begin
        next_state = state;
        next_sort_stage = sort_stage;
        next_combine_idx = combine_idx;
        next_temp_result = temp_result;
        next_done_reg = done_reg;
        next_result_reg = result_reg;
        next_sorted_digits = sorted_digits;

        case (state)
            IDLE: begin
                next_done_reg = 1'b0;
                next_sort_stage = 4'd0;
                next_combine_idx = 3'd0;
                next_temp_result = 32'd0;
                if (start) begin
                    next_state = SORTING;
                    // Initialize sorted array with input digits
                    next_sorted_digits[0] = digits[0];
                    next_sorted_digits[1] = digits[1];
                    next_sorted_digits[2] = digits[2];
                    next_sorted_digits[3] = digits[3];
                    next_sorted_digits[4] = digits[4];
                    next_sorted_digits[5] = digits[5];
                    next_sorted_digits[6] = digits[6];
                    next_sorted_digits[7] = digits[7];
                end
            end

            SORTING: begin
                next_sort_stage = sort_stage + 4'd1;
                next_sorted_digits = stage_swapped;
                if (sort_stage >= SORT_STAGES) begin
                    next_state = COMBINING;
                    next_sort_stage = 4'd0;
                end
            end

            COMBINING: begin
                // Build number: result = result * 10 + digit
                // Only process valid digits based on len
                if (combine_idx < len[2:0]) begin
                    next_temp_result = temp_result * 32'd10 + {28'd0, sorted_digits[combine_idx][3:0]};
                    next_combine_idx = combine_idx + 3'd1;
                end else begin
                    next_state = FINISHED;
                    next_result_reg = temp_result;
                    next_done_reg = 1'b1;
                end
            end

            FINISHED: begin
                next_done_reg = 1'b0;  // Done pulse is one cycle
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sort_stage <= 4'd0;
            combine_idx <= 3'd0;
            temp_result <= 32'd0;
            done_reg <= 1'b0;
            result_reg <= 32'd0;
            sorted_digits[0] <= 8'd0;
            sorted_digits[1] <= 8'd0;
            sorted_digits[2] <= 8'd0;
            sorted_digits[3] <= 8'd0;
            sorted_digits[4] <= 8'd0;
            sorted_digits[5] <= 8'd0;
            sorted_digits[6] <= 8'd0;
            sorted_digits[7] <= 8'd0;
        end else begin
            state <= next_state;
            sort_stage <= next_sort_stage;
            combine_idx <= next_combine_idx;
            temp_result <= next_temp_result;
            done_reg <= next_done_reg;
            result_reg <= next_result_reg;
            sorted_digits <= next_sorted_digits;
        end
    end

    // Output assignments
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end

endmodule