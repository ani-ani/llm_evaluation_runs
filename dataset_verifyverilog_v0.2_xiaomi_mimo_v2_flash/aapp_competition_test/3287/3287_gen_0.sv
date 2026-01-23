module thieves_loot (
    input clk,
    input rst_n,
    input start,
    input [7:0] x0,
    input [7:0] x1,
    input [7:0] x2,
    input [7:0] x3,
    output reg [8:0] result,
    output reg done
);

    // Parameters
    parameter K = 4;
    parameter MAX_SUM = 240;
    parameter WIDTH = 8;
    parameter VALUE_WIDTH = 9;

    // State encoding
    localparam IDLE = 5'b00001;
    localparam COMPUTE_TOTAL = 5'b00010;
    localparam INIT_DP = 5'b00100;
    localparam UPDATE_DP = 5'b01000;
    localparam FIND_MAX = 5'b10000;

    // Registers and Wires
    reg [4:0] state;
    reg [4:0] next_state;

    // Total calculation registers
    reg [8:0] total_sum;
    reg [8:0] total_sum_next;
    reg [1:0] coin_idx; // 0 to 3
    reg [1:0] coin_idx_next;

    // DP storage (241 bits -> 8x32 bits)
    reg [31:0] dp [0:7];
    reg [31:0] dp_next [0:7];

    // Update DP counters
    reg [8:0] current_sum; // Current sum being checked/updated
    reg [8:0] current_sum_next;
    reg [7:0] count_rem; // Remaining coins of current type to process
    reg [7:0] count_rem_next;
    reg [3:0] bit_index; // Index within current coin iteration (0 to count-1)
    reg [3:0] bit_index_next;

    // Find Max registers
    reg [8:0] scan_idx;
    reg [8:0] scan_idx_next;
    reg [8:0] result_reg;
    reg [8:0] result_reg_next;
    reg done_reg;
    reg done_reg_next;

    // Helper wires for DP access
    // Check bit set
    wire dp_check;
    assign dp_check = dp[current_sum[8:5]][current_sum[4:0]];

    // Update logic variables
    reg [8:0] update_idx;
    reg [8:0] new_idx;
    reg [31:0] dp_mask;

    integer i;

    // Sequential State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_sum <= 0;
            coin_idx <= 0;
            current_sum <= 0;
            count_rem <= 0;
            bit_index <= 0;
            scan_idx <= 0;
            result <= 0;
            done <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                dp[i] <= 0;
            end
        end else begin
            state <= next_state;
            total_sum <= total_sum_next;
            coin_idx <= coin_idx_next;
            current_sum <= current_sum_next;
            count_rem <= count_rem_next;
            bit_index <= bit_index_next;
            scan_idx <= scan_idx_next;
            result <= result_reg_next;
            done <= done_reg_next;
            for (i = 0; i < 8; i = i + 1) begin
                dp[i] <= dp_next[i];
            end
        end
    end

    // Combinational Logic
    always @(*) begin
        // Default assignments to avoid latches
        next_state = state;
        total_sum_next = total_sum;
        coin_idx_next = coin_idx;
        current_sum_next = current_sum;
        count_rem_next = count_rem;
        bit_index_next = bit_index;
        scan_idx_next = scan_idx;
        result_reg_next = result;
        done_reg_next = 1'b0;
        
        for (i = 0; i < 8; i = i + 1) begin
            dp_next[i] = dp[i];
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_TOTAL;
                    total_sum_next = 0;
                    coin_idx_next = 0;
                    // Reset DP (clear all bits) for next run
                    for (i = 0; i < 8; i = i + 1) dp_next[i] = 0;
                    dp_next[0][0] = 1'b1; // Set bit 0
                    done_reg_next = 1'b0;
                end else begin
                    done_reg_next = 1'b1; // Keep done high in idle
                end
            end

            COMPUTE_TOTAL: begin
                // Accumulate total sum: x0*1 + x1*2 + x2*4 + x3*8
                case (coin_idx)
                    2'd0: total_sum_next = total_sum + {1'b0, x0}; // x0*1
                    2'd1: total_sum_next = total_sum + {x1, 1'b0}; // x1*2
                    2'd2: total_sum_next = total_sum + {x2, 2'b00}; // x2*4
                    2'd3: total_sum_next = total_sum + {x3, 3'b000}; // x3*8
                endcase

                if (coin_idx < 3) begin
                    coin_idx_next = coin_idx + 1;
                end else begin
                    next_state = INIT_DP;
                    coin_idx_next = 0;
                end
            end

            INIT_DP: begin
                // Initialize for the first coin type update
                case (coin_idx)
                    2'd0: count_rem_next = x0;
                    2'd1: count_rem_next = x1;
                    2'd2: count_rem_next = x2;
                    2'd3: count_rem_next = x3;
                endcase
                bit_index_next = 0;
                
                if (coin_idx < 4 && count_rem_next != 0) begin
                    next_state = UPDATE_DP;
                    current_sum_next = 0; // Start scan from 0
                end else begin
                    // Skip if no coins of this type or all types done
                    if (coin_idx < 3) begin
                        coin_idx_next = coin_idx + 1;
                        next_state = INIT_DP; // Go to next type immediately
                    end else begin
                        next_state = FIND_MAX;
                        scan_idx_next = total_sum; // Start scanning from total down to 0
                    end
                end
            end

            UPDATE_DP: begin
                // Read dp_check (current_sum) and update for (current_sum + 2^coin_idx)
                if (dp_check) begin
                    // Calculate new index
                    case (coin_idx)
                        2'd0: new_idx = current_sum + 1;
                        2'd1: new_idx = current_sum + 2;
                        2'd2: new_idx = current_sum + 4;
                        2'd3: new_idx = current_sum + 8;
                    endcase

                    // Update dp_next if new_idx is valid
                    if (new_idx <= MAX_SUM) begin
                        dp_next[new_idx[8:5]][new_idx[4:0]] = 1'b1;
                    end
                end

                // Iterate current_sum from MAX_SUM down to 0 for this bit_index iteration
                if (current_sum > 0) begin
                    current_sum_next = current_sum - 1;
                    // Stay in UPDATE_DP
                end else begin // current_sum reached 0
                    // This bit_index iteration is complete
                    if (bit_index + 1 < count_rem) begin
                        // Start next bit_index iteration (effectively adding another coin)
                        bit_index_next = bit_index + 1;
                        current_sum_next = MAX_SUM; // Reset for scan
                    end else begin
                        // Finished all coins of this type
                        if (coin_idx < 3) begin
                            coin_idx_next = coin_idx + 1;
                            next_state = INIT_DP; // Move to next type
                        end else begin
                            next_state = FIND_MAX;
                            scan_idx_next = total_sum; // Start final scan from total
                        end
                    end
                end
            end

            FIND_MAX: begin
                // Scan backwards to find largest even sum
                if (scan_idx[0] == 1'b0) begin // Even check
                    if (dp[scan_idx[8:5]][scan_idx[4:0]]) begin
                        result_reg_next = total_sum - scan_idx;
                        next_state = DONE;
                        done_reg_next = 1'b1;
                    end else begin
                        if (scan_idx > 0) scan_idx_next = scan_idx - 1;
                        else begin
                            // If no even sum found (should not happen if 0 is included and total>=0), default to total
                            result_reg_next = total_sum;
                            next_state = DONE;
                            done_reg_next = 1'b1;
                        end
                    end
                end else begin // Odd, decrement to check next even
                     if (scan_idx > 0) scan_idx_next = scan_idx - 1;
                     else begin
                        result_reg_next = total_sum;
                        next_state = DONE;
                        done_reg_next = 1'b1;
                     end
                end
            end

            DONE: begin
                done_reg_next = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                    done_reg_next = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
