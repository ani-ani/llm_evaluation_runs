module ComputeInterestingSubsequence(
    input clk,
    input rst_n,
    input start,
    input [15:0] A [0:15],
    input [3:0] N,
    input [15:0] S,
    output reg [3:0] result_index,
    output reg [7:0] result_length,
    output reg result_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] RESET_ACC   = 3'd1;
    localparam [2:0] CALC_SUMS   = 3'd2;
    localparam [2:0] CHECK_COND  = 3'd3;
    localparam [2:0] OUTPUT_RES  = 3'd4;
    localparam [2:0] CHECK_DONE  = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] curr_idx;           // Current position i (0 to N-1)
    reg [3:0] curr_K;             // Current K value (1 to (N-curr_idx)/2)
    reg [7:0] max_len;            // Max length for current index
    reg [15:0] sum_first;         // Sum of first K elements
    reg [15:0] sum_last;          // Sum of last K elements
    reg [3:0] sum_idx;            // Index for summation loop
    reg [2:0] cycle_count;        // Loop counter for summation
    reg [2:0] max_K;              // Maximum K for current index

    // Counter for overall progress (prevent infinite loops)
    reg [7:0] total_cycles;
    localparam [7:0] MAX_TOTAL_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_index <= 4'd0;
            result_length <= 8'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            curr_idx <= 4'd0;
            curr_K <= 4'd0;
            max_len <= 8'd0;
            sum_first <= 16'd0;
            sum_last <= 16'd0;
            sum_idx <= 4'd0;
            cycle_count <= 3'd0;
            max_K <= 3'd0;
            total_cycles <= 8'd0;
        end else begin
            state <= next_state;
            total_cycles <= total_cycles + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    total_cycles <= 8'd0;
                    if (start) begin
                        curr_idx <= 4'd0;
                    end
                end

                RESET_ACC: begin
                    max_len <= 8'd0;
                    // Calculate max K for this index: floor((N - curr_idx) / 2)
                    max_K <= (N - curr_idx) >> 1;
                    curr_K <= 4'd1;
                end

                CALC_SUMS: begin
                    // Reset sums and index for summation
                    if (cycle_count == 3'd0) begin
                        sum_first <= 16'd0;
                        sum_last <= 16'd0;
                        sum_idx <= 4'd0;
                        cycle_count <= 3'd1;
                    end else if (cycle_count == 3'd1) begin
                        // Calculate sum_first for current K
                        if (sum_idx < curr_K) begin
                            if (sum_first + A[curr_idx + sum_idx] > 65535) begin
                                sum_first <= 16'd65535;
                            end else begin
                                sum_first <= sum_first + A[curr_idx + sum_idx];
                            end
                            sum_idx <= sum_idx + 4'd1;
                        end else begin
                            // Move to next phase: calculate sum_last
                            sum_idx <= 4'd0;
                            cycle_count <= 3'd2;
                        end
                    end else if (cycle_count == 3'd2) begin
                        // Calculate sum_last for current K
                        if (sum_idx < curr_K) begin
                            if (sum_last + A[curr_idx + curr_K + sum_idx] > 65535) begin
                                sum_last <= 16'd65535;
                            end else begin
                                sum_last <= sum_last + A[curr_idx + curr_K + sum_idx];
                            end
                            sum_idx <= sum_idx + 4'd1;
                        end else begin
                            cycle_count <= 3'd0;
                        end
                    end
                end

                CHECK_COND: begin
                    if ((sum_first <= S) && (sum_last <= S)) begin
                        // Valid K found, update max length
                        max_len <= curr_K << 1;
                    end
                    // Move to next K
                    if (curr_K < max_K) begin
                        curr_K <= curr_K + 4'd1;
                    end
                end

                OUTPUT_RES: begin
                    result_index <= curr_idx;
                    result_length <= max_len;
                    result_valid <= 1'b1;
                end

                CHECK_DONE: begin
                    result_valid <= 1'b0;
                    if (curr_idx < (N - 4'd1)) begin
                        curr_idx <= curr_idx + 4'd1;
                    end else begin
                        done <= 1'b1;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = RESET_ACC;
                else next_state = IDLE;
            end

            RESET_ACC: begin
                if (max_K >= 4'd1) next_state = CALC_SUMS;
                else next_state = OUTPUT_RES;  // No valid K for this index
            end

            CALC_SUMS: begin
                // After summation completes (cycle_count == 0 again)
                if (cycle_count == 3'd0) next_state = CHECK_COND;
                else next_state = CALC_SUMS;
            end

            CHECK_COND: begin
                if (curr_K < max_K) next_state = RESET_ACC;  // Go to next K
                else next_state = OUTPUT_RES;  // All K tested
            end

            OUTPUT_RES: begin
                next_state = CHECK_DONE;
            end

            CHECK_DONE: begin
                if (curr_idx < (N - 4'd1)) next_state = RESET_ACC;  // Next index
                else next_state = IDLE;  // All done
            end

            default: next_state = IDLE;
        endcase

        // Timeout prevention
        if (total_cycles >= MAX_TOTAL_CYCLES) next_state = IDLE;
    end

endmodule