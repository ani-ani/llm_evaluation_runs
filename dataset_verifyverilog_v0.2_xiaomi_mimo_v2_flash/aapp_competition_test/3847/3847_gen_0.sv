module max_subrect_area(
    input clk,
    input rst_n,
    input start,
    input [7:0] a_len,
    input [7:0] b_len,
    input [15:0] x,
    input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input [7:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALC_PREFIX_A = 3'b001;
    localparam CALC_PREFIX_B = 3'b010;
    localparam FIND_MIN_A = 3'b011;
    localparam FIND_MIN_B = 3'b100;
    localparam CHECK_COMBOS = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    
    // Internal arrays
    reg [7:0] a_reg [0:7];
    reg [7:0] b_reg [0:7];
    
    // Prefix sums: index k stores sum of first k elements (indices 0 to k-1)
    // Size 9 to accommodate length 8 (prefix[8] = sum of all 8)
    reg [15:0] pref_a [0:8];
    reg [15:0] pref_b [0:8];
    
    // Min sums for each length
    reg [15:0] min_sum_a [0:8];
    reg [15:0] min_sum_b [0:8];
    
    // Loop counters
    reg [3:0] i; // general purpose loop counter
    reg [3:0] j; // general purpose loop counter
    reg [3:0] k; // general purpose loop counter
    
    // Temporary calculation variables
    reg [15:0] current_sum;
    reg [15:0] current_min;
    reg [15:0] product;
    reg [15:0] temp_area;

    // Control flags
    reg processing_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'b0;
            done <= 1'b0;
            i <= 4'b0;
            j <= 4'b0;
            k <= 4'b0;
            processing_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Store inputs to local regs
                        a_reg[0] <= a_0; a_reg[1] <= a_1; a_reg[2] <= a_2; a_reg[3] <= a_3;
                        a_reg[4] <= a_4; a_reg[5] <= a_5; a_reg[6] <= a_6; a_reg[7] <= a_7;
                        b_reg[0] <= b_0; b_reg[1] <= b_1; b_reg[2] <= b_2; b_reg[3] <= b_3;
                        b_reg[4] <= b_4; b_reg[5] <= b_5; b_reg[6] <= b_6; b_reg[7] <= b_7;
                        
                        // Initialize
                        pref_a[0] <= 16'b0;
                        pref_b[0] <= 16'b0;
                        result <= 16'b0;
                        i <= 4'b0;
                        j <= 4'b0;
                        k <= 4'b0;
                        
                        state <= CALC_PREFIX_A;
                    end
                end

                // Calculate prefix sums for A
                CALC_PREFIX_A: begin
                    if (i < a_len) begin
                        pref_a[i+1] <= pref_a[i] + a_reg[i];
                        i <= i + 1;
                    end else begin
                        i <= 4'b0;
                        state <= CALC_PREFIX_B;
                    end
                end

                // Calculate prefix sums for B
                CALC_PREFIX_B: begin
                    if (i < b_len) begin
                        pref_b[i+1] <= pref_b[i] + b_reg[i];
                        i <= i + 1;
                    end else begin
                        i <= 4'b0;
                        state <= FIND_MIN_A;
                    end
                end

                // Find min sum for A for each length
                FIND_MIN_A: begin
                    // Loop structure: length i (1 to 8)
                    // Start phase: init min for current length i
                    if (j == 0) begin
                        // Initialize min for length i (start index 0)
                        if (i < a_len) begin
                            min_sum_a[i+1] <= pref_a[i+1]; // sum from 0 to i
                            j <= 1; // move to iterate starts
                        end else begin
                            // Done with A, reset for B
                            i <= 4'b0;
                            j <= 4'b0;
                            state <= FIND_MIN_B;
                        end
                    end else begin
                        // Iterate start indices j (1 to a_len - i - 1)
                        if (j <= (a_len - (i+1))) begin
                            current_sum <= pref_a[j + i + 1] - pref_a[j];
                            j <= j + 1;
                            // We need a separate state to compare or do it here with logic
                            // Actually, let's compute current_sum and update min in next cycle or combinational
                            // To keep single cycle update logic simple, we use a combinational block for the check? No, sequential is requested.
                            // Let's split: State to compute sum, State to update min?
                            // Optimization: Do it in one go using delay line or separate combinational logic.
                            // Let's use combinational logic for the calculation and register the result.
                            // Wait, strict sequential implies specific states.
                            // Let's combine sum calculation and comparison in one block but separate by j.
                            // Actually, `current_sum` is computed from pref_a. It takes 0 time in hardware.
                            // We can update min_sum immediately if we want.
                            // But to stick to the "sequential" spirit (cycle per operation), let's just do it.
                            // To save states, we can compute sum immediately.
                            current_sum <= pref_a[j + i + 1] - pref_a[j];
                            // We need to compare in same cycle? No, use next cycle or separate block.
                            // Let's use a helper state or combinational assignment.
                            // Let's use combinational logic for the sum calculation to save states, but register the min.
                            // Actually, the prompt asks for a state machine. 
                            // Let's use a helper state `UPDATE_MIN` if we want to be pedantic, but for 8 elements, we can unroll or loop.
                            // Let's just loop. The `current_sum` is ready immediately if we use `always @*`.
                        end else begin
                            j <= 4'b0;
                            i <= i + 1;
                        end
                    end
                    // Correct logic: In FIND_MIN_A, we are iterating lengths i (1..a_len). 
                    // For each i, we iterate start j (0..a_len-i).
                    // Sum = pref_a[j+i] - pref_a[j].
                    // Update min_sum_a[i].
                end

                // Find min sum for B for each length
                FIND_MIN_B: begin
                    if (j == 0) begin
                        if (i < b_len) begin
                            min_sum_b[i+1] <= pref_b[i+1];
                            j <= 1;
                        end else begin
                            i <= 4'b0;
                            j <= 4'b0;
                            state <= CHECK_COMBOS;
                        end
                    end else begin
                        if (j <= (b_len - (i+1))) begin
                            current_sum <= pref_b[j + i + 1] - pref_b[j];
                            j <= j + 1;
                        end else begin
                            j <= 4'b0;
                            i <= i + 1;
                        end
                    end
                end

                // Combinational Update Logic for Min Values
                // Since we are in a clocked block, we can't update directly from `current_sum` in the same cycle unless we use combinational logic outside.
                // To keep strictly sequential and avoid complex combinational paths inside the FSM, let's add a specific update logic block
                // OR we can simply say: The `current_sum` is computed, and we register it. But we need to update the MIN.
                // The state machine above updates `current_sum`. 
                // We need to actually compare `current_sum` with `min_sum_a[i+1]`.
                // Let's modify the FSM states slightly to handle the min update.
                // Actually, we can do the comparison in a combinational block:
                wire [15:0] sum_a_sub = pref_a[j + i + 1] - pref_a[j];
                wire [15:0] sum_b_sub = pref_b[j + i + 1] - pref_b[j];
                
                // However, inside `always @(posedge clk)`, we cannot use these wires for indexing if we want to be purely reg-based.
                // Let's change the design to be more explicit with helper states or just calculate the sums directly in the `FIND_MIN` states using combinational logic inside the always block.
                // Actually, we can use combinational logic for the calculation. 
                // Let's assume the standard way to do this in FPGA is combinational logic for index calculations.
                // To be robust:
                // In `FIND_MIN_A` state:
                // 1. Compute sum = pref_a[j+i] - pref_a[j].
                // 2. Update min_sum_a[i+1] = min(min_sum_a[i+1], sum).
                // This requires logic. 
                // Let's revert to using combinational calculations inside the clocked block for simplicity and performance.
                
            endcase
        end
    end

    // Helper combinational logic to handle the min update mechanism without needing extra states
    // This effectively implements the loop body in hardware
    // We need to know when we are in the update phase.
    // Actually, to strictly follow the state machine instructions and "Sequential", let's do it carefully.
    // We will combine the loop body logic into the state machine transitions or add a micro-coded approach.
    // To save lines and make it efficient, let's use the previously defined logic but fix the comparison.
    
    // Re-implementing the state machine logic for Min Calculation to handle the comparison correctly in one cycle per iteration.
    // We need a way to know if we are currently calculating a valid sum.
    
    // Let's refine the state machine logic inside the always block.
    // We will use a helper register to store the "current valid sum".
    // But wait, the `current_sum` update in the code above happens on `j <= ...`. 
    // The logic `pref_a[j + i + 1] - pref_a[j]` is combinational.
    // We can use it directly.

    // Overriding the always block to be cleaner:
    // We will use a separate combinational block to calculate the "potential new min".
    
    wire [15:0] next_min_a;
    wire [15:0] next_min_b;
    
    // Calculate current subarray sum combinations
    // Note: We must handle boundaries carefully.
    // In state FIND_MIN_A, if j > 0, we are calculating for start index j-1 (previous j) or current j?
    // In the code above, we incremented j. 
    // Let's trace: Initial j=0. We set min for start 0. Then j=1. We calculate sum for start 1.
    // So we need to compare sum for start j (where j is the new index).
    // But `pref_a[j + i + 1] - pref_a[j]` requires j to be valid.
    
    // To make it perfectly sequential without combinational flow (like a CPU), let's use a micro-instruction approach.
    // However, for 8 elements, unrolling is better.
    // Let's implement a more robust standard FSM.
    
    // We will rewrite the always block for clarity and correctness.
    // We use a separate always block for the combinatorial logic to update the registers.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Load arrays
                        a_reg[0] <= a_0; a_reg[1] <= a_1; a_reg[2] <= a_2; a_reg[3] <= a_3;
                        a_reg[4] <= a_4; a_reg[5] <= a_5; a_reg[6] <= a_6; a_reg[7] <= a_7;
                        b_reg[0] <= b_0; b_reg[1] <= b_1; b_reg[2] <= b_2; b_reg[3] <= b_3;
                        b_reg[4] <= b_4; b_reg[5] <= b_5; b_reg[6] <= b_6; b_reg[7] <= b_7;
                        
                        // Reset indices
                        i <= 1;
                        j <= 0;
                        k <= 0;
                        result <= 0;
                        
                        // Initialize prefix sums
                        pref_a[0] <= 0;
                        pref_b[0] <= 0;
                        
                        state <= CALC_PREFIX_A;
                    end
                end

                CALC_PREFIX_A: begin
                    if (i <= a_len) begin
                        pref_a[i] <= pref_a[i-1] + a_reg[i-1];
                        i <= i + 1;
                    end else begin
                        i <= 1; // Use i for lengths now
                        state <= CALC_PREFIX_B;
                    end
                end

                CALC_PREFIX_B: begin
                    if (j <= b_len) begin
                        pref_b[j] <= pref_b[j-1] + b_reg[j-1];
                        j <= j + 1;
                    end else begin
                        i <= 1; // Length of A
                        j <= 1; // Length of B
                        k <= 0; // Start index for A
                        // Initialize min_sum_a and min_sum_b arrays (conceptually)
                        // We need to set initial values.
                        // Let's set min_sum_a[1] = a[0] etc in the first state of Find Min
                        state <= FIND_MIN_A;
                    end
                end

                FIND_MIN_A: begin
                    // Sub-state machine for finding mins
                    // We iterate length L from 1 to 8
                    // For each L, iterate start S from 0 to len-L
                    // Sum = pref_a[S+L] - pref_a[S]
                    // Update min_sum_a[L]
                    
                    // We will use `i` as Length, `k` as Start
                    // We need to store the current min for length `i`.
                    // Let's use `min_sum_a[i]` to store the running minimum.
                    
                    // First cycle for this length? 
                    // We can set `min_sum_a[i]` to the first sum (start 0) at the beginning.
                    
                    // Logic flow:
                    // 1. If k == 0: 
                    //    If i > a_len: Done with A. Go to FIND_MIN_B.
                    //    Else: Set min_sum_a[i] = pref_a[i] - pref_a[0]. k = 1.
                    // 2. Else (k > 0):
                    //    If k <= a_len - i:
                    //       Sum = pref_a[k+i] - pref_a[k]
                    //       min_sum_a[i] = min(min_sum_a[i], Sum)
                    //       k = k + 1
                    //    Else:
                    //       i = i + 1, k = 0
                    
                    if (k == 0) begin
                        if (i > a_len) begin
                            // Done with A
                            i <= 1; // Reset for B
                            k <= 0;
                            state <= FIND_MIN_B;
                        end else begin
                            // Initialize min for length i
                            min_sum_a[i] <= pref_a[i] - pref_a[0];
                            k <= 1;
                        end
                    end else begin
                        if (k <= (a_len - i)) begin
                            // Compare
                            if (pref_a[k+i] - pref_a[k] < min_sum_a[i])
                                min_sum_a[i] <= pref_a[k+i] - pref_a[k];
                            k <= k + 1;
                        end else begin
                            // Next length
                            i <= i + 1;
                            k <= 0;
                        end
                    end
                end

                FIND_MIN_B: begin
                    // Same logic for B
                    if (k == 0) begin
                        if (i > b_len) begin
                            // Done with B
                            i <= 1;
                            j <= 1;
                            state <= CHECK_COMBOS;
                        end else begin
                            min_sum_b[i] <= pref_b[i] - pref_b[0];
                            k <= 1;
                        end
                    end else begin
                        if (k <= (b_len - i)) begin
                            if (pref_b[k+i] - pref_b[k] < min_sum_b[i])
                                min_sum_b[i] <= pref_b[k+i] - pref_b[k];
                            k <= k + 1;
                        end else begin
                            i <= i + 1;
                            k <= 0;
                        end
                    end
                end

                CHECK_COMBOS: begin
                    // Iterate i (1..a_len), j (1..b_len)
                    // Check min_sum_a[i] * min_sum_b[j] <= x
                    // Update max area
                    
                    // Optimization: We can do this in 1 cycle or loop.
                    // Since max 64 combos (8x8), we can loop.
                    
                    // Logic:
                    // 1. Calculate product = min_sum_a[i] * min_sum_b[j]
                    // 2. If product <= x, area = i * j. Update result if area > result.
                    // 3. Increment j. If j > b_len, increment i, reset j. If i > a_len, DONE.
                    
                    if (i <= a_len) begin
                        if (j <= b_len) begin
                            product <= min_sum_a[i] * min_sum_b[j];
                            // Check condition in next state or combinational? 
                            // Let's do the check in this state using combinational logic inside the block if possible, 
                            // or separate logic. To keep it simple, we will assume we can read the product immediately if we calculate it blocking.
                            // But we are in clocked logic.
                            // Let's calculate the multiplication. We will check result in the NEXT cycle.
                            // Wait, that doubles the latency.
                            // Alternatively, just do the check here:
                            if (min_sum_a[i] * min_sum_b[j] <= x) begin
                                temp_area <= i * j; // i and j are 4-bit, product is 8-bit, fits in 16-bit reg
                                // We need to compare with result. 
                                // We can't update result directly here if we want to avoid logic depth issues, but for 8x8 it's fine.
                                // Let's use a combinational max update.
                                if (i * j > result)
                                    result <= i * j;
                            end
                            j <= j + 1;
                        end else begin
                            j <= 1;
                            i <= i + 1;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule