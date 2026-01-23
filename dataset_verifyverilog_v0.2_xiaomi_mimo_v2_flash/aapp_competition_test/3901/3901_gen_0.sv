module gcd_operations_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] a_0,
    input [7:0] a_1,
    input [7:0] a_2,
    input [7:0] a_3,
    input [7:0] a_4,
    input [7:0] a_5,
    input [7:0] a_6,
    input [7:0] a_7,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    parameter N = 8;
    parameter MAX_VAL = 8'd255;

    // State definition
    typedef enum logic [3:0] {
        IDLE,
        LOAD,
        CHECK_ONES,
        CHECK_TOTAL_GCD_START,
        CHECK_TOTAL_GCD_WAIT,
        FIND_SHORTEST_INIT,
        FIND_SHORTEST_OUTER,
        FIND_SHORTEST_INNER,
        FIND_SHORTEST_GCD,
        FIND_SHORTEST_UPDATE,
        CALC_RESULT,
        DONE_STATE
    } state_t;

    // Registers
    reg [7:0] arr [0:7];
    reg [3:0] curr_state;
    reg [3:0] next_state;
    
    // Counters
    reg [3:0] i; // Outer loop index (start of subarray)
    reg [3:0] j; // Inner loop index (end of subarray)
    reg [3:0] ones_count;
    
    // GCD registers
    reg [7:0] gcd_op_a;
    reg [7:0] gcd_op_b;
    wire [7:0] gcd_result;
    reg gcd_start;
    wire gcd_done;
    reg [7:0] current_gcd;
    reg [7:0] min_len;
    reg [7:0] temp_len;

    // --- GCD Calculator Module (Embedded) ---
    // Non-restoring division algorithm for GCD
    reg [7:0] gcd_a_reg, gcd_b_reg;
    reg [3:0] gcd_bit_cnt;
    reg gcd_active;
    
    assign gcd_done = (gcd_active && gcd_bit_cnt == 4'd8);
    assign gcd_result = gcd_a_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_active <= 0;
            gcd_a_reg <= 0;
            gcd_b_reg <= 0;
            gcd_bit_cnt <= 0;
        end else begin
            if (gcd_start && !gcd_active) begin
                gcd_a_reg <= (gcd_op_a > gcd_op_b) ? gcd_op_a : gcd_op_b;
                gcd_b_reg <= (gcd_op_a > gcd_op_b) ? gcd_op_b : gcd_op_a;
                gcd_bit_cnt <= 0;
                gcd_active <= 1;
            end else if (gcd_active) begin
                if (gcd_bit_cnt < 4'd8) begin
                    // Euclidean step: a % b
                    if (gcd_b_reg != 0) begin
                        if (gcd_a_reg >= gcd_b_reg) begin
                            gcd_a_reg <= gcd_a_reg - gcd_b_reg;
                        end else begin
                            // Swap for next iteration logic simulation (simplified for hardware)
                            // In hardware, we usually shift. Here we simulate subtraction steps.
                            // Optimization: Just standard Euclidean algorithm logic
                            // Since max value is 255, depth is small. We use a standard subtract/compare.
                            // Actually, let's use a more direct sequential Euclidean approach
                            // Swap a and b if a < b
                            if (gcd_a_reg < gcd_b_reg) begin
                                gcd_a_reg <= gcd_b_reg;
                                gcd_b_reg <= gcd_a_reg;
                            end else begin
                                gcd_a_reg <= gcd_a_reg - gcd_b_reg;
                            end
                        end
                        gcd_bit_cnt <= gcd_bit_cnt + 1;
                    end else begin
                        gcd_active <= 0; // Done early
                    end
                    
                    // Termination condition: if b becomes 0
                    if (gcd_b_reg == 0) begin
                        gcd_active <= 0;
                        gcd_bit_cnt <= 4'd8;
                    end
                end else begin
                    gcd_active <= 0;
                end
            end
        end
    end

    // --- Main State Machine ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            result <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
            ones_count <= 0;
            min_len <= 4'd8;
            temp_len <= 0;
            gcd_start <= 0;
            current_gcd <= 0;
        end else begin
            // Defaults
            gcd_start <= 0;
            
            case (curr_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        curr_state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load inputs into array
                    arr[0] <= a_0;
                    arr[1] <= a_1;
                    arr[2] <= a_2;
                    arr[3] <= a_3;
                    arr[4] <= a_4;
                    arr[5] <= a_5;
                    arr[6] <= a_6;
                    arr[7] <= a_7;
                    i <= 0;
                    ones_count <= 0;
                    curr_state <= CHECK_ONES;
                end

                CHECK_ONES: begin
                    // Check for ones and count them
                    if (arr[i] == 1) begin
                        ones_count <= ones_count + 1;
                    end
                    
                    if (i == 7) begin
                        if (ones_count > 0) begin
                            // If there are ones, we can skip total GCD check and go to calc
                            // But algorithm says: 1. If any element is 1 -> (N - count)
                            curr_state <= CALC_RESULT;
                        end else begin
                            curr_state <= CHECK_TOTAL_GCD_START;
                        end
                        i <= 0; // Reset i for next stages
                    end else begin
                        i <= i + 1;
                    end
                end

                CHECK_TOTAL_GCD_START: begin
                    // Start calculating GCD of all elements
                    // First, use arr[0] and arr[1]
                    if (i == 0) begin
                        // Need to start GCD of whole array
                        // Let's accumulate in a separate variable. 
                        // To save states, let's use a running GCD accumulation.
                        // Start with arr[0] as current_gcd, then combine with arr[1]..arr[7]
                        current_gcd <= arr[0];
                        i <= 1;
                        curr_state <= CHECK_TOTAL_GCD_WAIT;
                    end else if (i < 8) begin
                        // i represents next index to combine with current_gcd
                        gcd_op_a <= current_gcd;
                        gcd_op_b <= arr[i];
                        gcd_start <= 1;
                        curr_state <= CHECK_TOTAL_GCD_WAIT;
                    end else begin
                        // Done with total GCD
                        if (current_gcd == 1) begin
                            curr_state <= FIND_SHORTEST_INIT;
                        end else begin
                            // GCD != 1
                            result <= MAX_VAL;
                            curr_state <= DONE_STATE;
                        end
                    end
                end

                CHECK_TOTAL_GCD_WAIT: begin
                    if (gcd_done || !gcd_active) begin
                        if (gcd_start) begin
                             // Just started, wait for next cycle or result ready
                             // Actually gcd_start is high for 1 cycle. 
                             // We need to wait until gcd_active goes low and gcd_done is high.
                             // The GCD block logic above handles the cycles.
                             if (gcd_done) begin
                                current_gcd <= gcd_result;
                                i <= i + 1;
                                curr_state <= CHECK_TOTAL_GCD_START;
                             end
                        end else begin
                            // This state is for waiting for the GCD to finish if it took longer
                            if (gcd_done) begin
                                current_gcd <= gcd_result;
                                i <= i + 1;
                                curr_state <= CHECK_TOTAL_GCD_START;
                            end
                        end
                    end
                    // Fix: The GCD block might start in previous state. We just wait for done.
                    if (gcd_done) begin
                        current_gcd <= gcd_result;
                        i <= i + 1;
                        curr_state <= CHECK_TOTAL_GCD_START;
                    end
                end

                FIND_SHORTEST_INIT: begin
                    i <= 0;
                    j <= 1;
                    min_len <= 4'd8; // Initialize to max possible length
                    current_gcd <= arr[0]; // Start GCD with first element
                    curr_state <= FIND_SHORTEST_OUTER;
                end

                FIND_SHORTEST_OUTER: begin
                    // Outer loop: start index i
                    if (i >= 7) begin
                        // If min_len is still 8, check if we found a 1. 
                        // If array has no 1, but total GCD is 1, there MUST be a subarray with GCD 1.
                        // If min_len is 8, it means the whole array is the shortest.
                        curr_state <= CALC_RESULT;
                    end else begin
                        // Reset inner loop
                        j <= i + 1;
                        current_gcd <= arr[i];
                        curr_state <= FIND_SHORTEST_INNER;
                    end
                end

                FIND_SHORTEST_INNER: begin
                    // Inner loop: end index j
                    if (j < N) begin
                        // Compute GCD of current_gcd and arr[j]
                        gcd_op_a <= current_gcd;
                        gcd_op_b <= arr[j];
                        gcd_start <= 1;
                        curr_state <= FIND_SHORTEST_GCD;
                    end else begin
                        // Inner loop done for this i
                        i <= i + 1;
                        curr_state <= FIND_SHORTEST_OUTER;
                    end
                end

                FIND_SHORTEST_GCD: begin
                    if (gcd_done) begin
                        current_gcd <= gcd_result;
                        // If GCD becomes 1, we found the shortest for this start index i
                        if (gcd_result == 1) begin
                            temp_len <= j - i + 1; // Calculate length
                            curr_state <= FIND_SHORTEST_UPDATE;
                        end else begin
                            // Continue inner loop
                            j <= j + 1;
                            curr_state <= FIND_SHORTEST_INNER;
                        end
                    end
                end

                FIND_SHORTEST_UPDATE: begin
                    // Update minimum length found so far
                    // temp_len holds (j - i + 1)
                    // Note: j-i+1 <= 8. 
                    // Since i <= 6, j <= 7, max length is 8. min length can be 2.
                    // We want min of min_len and temp_len.
                    if (temp_len < min_len) begin
                        min_len <= temp_len;
                    end
                    // If we found length 2, we can't do better (need at least 2 elements for GCD 1 if no 1s)
                    // But let's keep iterating to be safe, or break.
                    // Optimization: break inner loop, continue outer.
                    i <= i + 1;
                    curr_state <= FIND_SHORTEST_OUTER;
                end

                CALC_RESULT: begin
                    if (ones_count > 0) begin
                        result <= (N - ones_count);
                    end else begin
                        // Result = (L - 1) + (N - 1)
                        // N=8, so (N-1) = 7.
                        // (L - 1) + 7 = L + 6.
                        // min_len holds L (the length of subarray).
                        // Note: min_len was initialized to 8. If no subarray found (shouldn't happen if total_gcd=1), use 8.
                        result <= min_len + 6; 
                    end
                    curr_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) begin // Wait for start to go low before going back to IDLE
                         curr_state <= IDLE;
                    end
                end
                
                default: curr_state <= IDLE;
            endcase
        end
    end

endmodule