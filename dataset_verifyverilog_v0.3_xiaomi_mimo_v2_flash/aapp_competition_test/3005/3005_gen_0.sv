module MaximalFactoring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] string_in [0:15],
    input wire [4:0] length_in,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] INIT = 3'd2;
    localparam [2:0] MAIN_LOOP = 3'd3;
    localparam [2:0] COMPUTE_SPLIT = 3'd4;
    localparam [2:0] CHECK_REPETITION = 3'd5;
    localparam [2:0] UPDATE_DP = 3'd6;
    localparam [2:0] DONE = 3'd7;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] str_reg [0:15];  // String storage
    reg [4:0] n;                // String length
    reg [3:0] L;                // Current substring length
    reg [3:0] i;                // Start index
    reg [3:0] j;                // End index
    reg [3:0] k;                // Split index
    reg [3:0] d;                // Divisor for repetition check
    reg [4:0] min_val;          // Minimum DP value
    reg [4:0] temp_sum;         // Temporary sum for split
    reg [4:0] dp_mem [0:255];   // DP table: indexed by {i[3:0], j[3:0]}
    reg [3:0] r;                // Character index for repetition check
    reg [3:0] p;                // Repetition iteration
    reg [3:0] loop_idx;         // General loop index
    reg [2:0] sub_state;        // Sub-state for loops
    reg [3:0] divisor;          // Current divisor being tested
    reg is_periodic;            // Flag for periodicity check
    reg [3:0] char_idx1, char_idx2; // Character indices for comparison
    reg [7:0] char1, char2;     // Characters to compare
    reg mismatch;               // Mismatch flag for repetition check
    reg [4:0] cycle_counter;    // Safety cycle counter
    localparam [4:0] MAX_CYCLES = 5'd30; // Safety limit

    integer idx;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: next_state = INIT;
            INIT: next_state = MAIN_LOOP;
            MAIN_LOOP: begin
                if (L <= n && i <= n - L)
                    next_state = COMPUTE_SPLIT;
                else if (L <= n)
                    next_state = MAIN_LOOP; // Next i
                else
                    next_state = DONE;
            end
            COMPUTE_SPLIT: begin
                if (k < j)
                    next_state = COMPUTE_SPLIT;
                else
                    next_state = CHECK_REPETITION;
            end
            CHECK_REPETITION: begin
                if (sub_state == 3'd0) begin // Check divisor validity
                    if (d <= (L >> 1)) begin
                        next_state = CHECK_REPETITION;
                    end else begin
                        next_state = UPDATE_DP;
                    end
                end else if (sub_state == 3'd1) begin // Check periodicity
                    if (mismatch)
                        next_state = CHECK_REPETITION; // Continue with next d
                    else if (p < (L/d - 1))
                        next_state = CHECK_REPETITION;
                    else
                        next_state = CHECK_REPETITION; // Periodic found, update min_val
                end else begin
                    next_state = CHECK_REPETITION; // Should not happen
                end
            end
            UPDATE_DP: next_state = MAIN_LOOP;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            n <= 5'd0;
            L <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            d <= 4'd0;
            min_val <= 5'd0;
            temp_sum <= 5'd0;
            r <= 4'd0;
            p <= 4'd0;
            loop_idx <= 4'd0;
            sub_state <= 3'd0;
            divisor <= 4'd0;
            is_periodic <= 1'b0;
            char_idx1 <= 4'd0;
            char_idx2 <= 4'd0;
            char1 <= 8'd0;
            char2 <= 8'd0;
            mismatch <= 1'b0;
            cycle_counter <= 5'd0;
            for (idx = 0; idx < 16; idx = idx + 1)
                str_reg[idx] <= 8'd0;
            for (idx = 0; idx < 256; idx = idx + 1)
                dp_mem[idx] <= 5'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_counter <= cycle_counter + 5'd1;

            case (state)
                IDLE: begin
                    cycle_counter <= 5'd0;
                    if (start) begin
                        // Initialize for new computation
                        result <= 5'd0;
                        cycle_counter <= 5'd0;
                    end
                end

                LOAD: begin
                    n <= length_in;
                    for (idx = 0; idx < 16; idx = idx + 1)
                        str_reg[idx] <= string_in[idx];
                end

                INIT: begin
                    L <= 4'd1;
                    i <= 4'd0;
                    // Initialize dp for length 1
                    if (i < n) begin
                        dp_mem[{i, i}] <= 5'd1;
                        i <= i + 4'd1;
                    end
                    // If n==0, skip to done
                    if (n == 5'd0)
                        state <= DONE;
                    else if (i >= n)
                        state <= MAIN_LOOP;
                end

                MAIN_LOOP: begin
                    if (L <= n && i <= n - L) begin
                        j <= i + L - 4'd1;
                        k <= i;
                        min_val <= 5'd31; // Initialize with max value
                        sub_state <= 3'd0;
                        divisor <= 4'd1;
                        is_periodic <= 1'b0;
                    end else if (L <= n) begin
                        // Next L
                        L <= L + 4'd1;
                        i <= 4'd0;
                    end
                end

                COMPUTE_SPLIT: begin
                    if (k < j) begin
                        temp_sum <= dp_mem[{i, k}] + dp_mem[{k + 4'd1, j}];
                        if (dp_mem[{i, k}] + dp_mem[{k + 4'd1, j}] < min_val)
                            min_val <= dp_mem[{i, k}] + dp_mem[{k + 4'd1, j}];
                        k <= k + 4'd1;
                    end else begin
                        // Final split
                        temp_sum <= dp_mem[{i, k}] + dp_mem[{k + 4'd1, j}];
                        if (dp_mem[{i, k}] + dp_mem[{k + 4'd1, j}] < min_val)
                            min_val <= dp_mem[{i, k}] + dp_mem[{k + 4'd1, j}];
                    end
                end

                CHECK_REPETITION: begin
                    if (sub_state == 3'd0) begin
                        // Check if divisor d divides L
                        if (d <= (L >> 1)) begin
                            if ((L % d) == 4'd0) begin
                                // Valid divisor, check periodicity
                                sub_state <= 3'd1;
                                r <= 4'd0;
                                p <= 4'd0;
                                mismatch <= 1'b0;
                            end else begin
                                // Next divisor
                                d <= d + 4'd1;
                            end
                        end
                    end else if (sub_state == 3'd1) begin
                        // Check periodicity: s[i + r] == s[i + r + d] for all repetitions
                        if (!mismatch && p < (L/d - 1)) begin
                            char_idx1 <= i + r + (p * d);
                            char_idx2 <= i + r + ((p + 4'd1) * d);
                            // Next cycle comparison
                            if (r < d - 4'd1) begin
                                r <= r + 4'd1;
                            end else begin
                                r <= 4'd0;
                                p <= p + 4'd1;
                            end
                            // Check character equality in next cycle
                        end else if (!mismatch && p >= (L/d - 1)) begin
                            // Periodic found, update min_val if dp[i][i+d-1] is smaller
                            if (dp_mem[{i, i + d - 4'd1}] < min_val)
                                min_val <= dp_mem[{i, i + d - 4'd1}];
                            // Move to next divisor
                            sub_state <= 3'd0;
                            d <= d + 4'd1;
                        end else begin
                            // Mismatch, next divisor
                            sub_state <= 3'd0;
                            d <= d + 4'd1;
                        end
                    end
                end

                UPDATE_DP: begin
                    dp_mem[{i, j}] <= min_val;
                    i <= i + 4'd1;
                    // Reset for next iteration
                    d <= 4'd1;
                end

                DONE: begin
                    if (n > 5'd0)
                        result <= dp_mem[{4'd0, n - 4'd1}];
                    else
                        result <= 5'd0;
                    done <= 1'b1;
                end
            endcase

            // Character comparison logic (combinational within clocked block for simplicity)
            // In a real design, this would be a separate combinational block
            // but for Icarus compatibility, we embed logic
            if (state == CHECK_REPETITION && sub_state == 3'd1) begin
                // We need to compare characters from str_reg
                // Note: This is a simplification; proper comparison needs separate combinational logic
                // Here we set mismatch flag based on character values
                if (char_idx1 < 4'd16 && char_idx2 < 4'd16) begin
                    char1 <= str_reg[char_idx1];
                    char2 <= str_reg[char_idx2];
                    if (str_reg[char_idx1] != str_reg[char_idx2])
                        mismatch <= 1'b1;
                end else begin
                    mismatch <= 1'b1; // Out of bounds
                end
            end
        end
    end

endmodule