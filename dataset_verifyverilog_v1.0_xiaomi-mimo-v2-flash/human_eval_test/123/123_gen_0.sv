module collatz_sorted_odds (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    output reg [15:0] result_0,
    output reg [15:0] result_1,
    output reg [15:0] result_2,
    output reg [15:0] result_3,
    output reg [15:0] result_4,
    output reg [15:0] result_5,
    output reg [15:0] result_6,
    output reg [15:0] result_7,
    output reg [15:0] result_8,
    output reg [15:0] result_9,
    output reg [15:0] result_10,
    output reg [15:0] result_11,
    output reg [15:0] result_12,
    output reg [15:0] result_13,
    output reg [15:0] result_14,
    output reg [15:0] result_15,
    output reg [3:0] result_len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALCULATE = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [3:0] FINISH    = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] current_n;
    reg [7:0] step_count;
    localparam [7:0] MAX_STEPS = 8'd255; // 0 to 255 = 256 steps
    reg [3:0] array_idx;
    reg [15:0] arr [0:15]; // Unpacked array for storage
    reg [3:0] sort_i, sort_j;
    reg [15:0] temp_val;
    reg sorting_phase; // 0: inner loop, 1: outer loop
    
    // Array outputs (combinational)
    always @(*) begin
        result_0 = arr[0];
        result_1 = arr[1];
        result_2 = arr[2];
        result_3 = arr[3];
        result_4 = arr[4];
        result_5 = arr[5];
        result_6 = arr[6];
        result_7 = arr[7];
        result_8 = arr[8];
        result_9 = arr[9];
        result_10 = arr[10];
        result_11 = arr[11];
        result_12 = arr[12];
        result_13 = arr[13];
        result_14 = arr[14];
        result_15 = arr[15];
    end

    // FSM Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CALCULATE;
                else next_state = IDLE;
            end
            CALCULATE: begin
                if (current_n == 16'd1 || step_count >= MAX_STEPS) begin
                    if (array_idx == 0) next_state = FINISH; // No odds found, go to finish
                    else next_state = SORT;
                end else begin
                    next_state = CALCULATE;
                end
            end
            SORT: begin
                // Bubble sort logic
                // We do one comparison per cycle
                if (sorting_phase) begin
                    // Outer loop: check if we are done
                    if (sort_i >= array_idx - 2) begin
                        next_state = FINISH;
                    end else begin
                        next_state = SORT;
                    end
                end else begin
                    // Inner loop: continue within current pass
                    next_state = SORT;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State Transition & Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            // Initialize array to avoid X
            arr[0] <= 16'd0;
            arr[1] <= 16'd0;
            arr[2] <= 16'd0;
            arr[3] <= 16'd0;
            arr[4] <= 16'd0;
            arr[5] <= 16'd0;
            arr[6] <= 16'd0;
            arr[7] <= 16'd0;
            arr[8] <= 16'd0;
            arr[9] <= 16'd0;
            arr[10] <= 16'd0;
            arr[11] <= 16'd0;
            arr[12] <= 16'd0;
            arr[13] <= 16'd0;
            arr[14] <= 16'd0;
            arr[15] <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_n <= n_in;
                        step_count <= 8'd0;
                        array_idx <= 4'd0;
                        // Clear previous results
                        arr[0] <= 16'd0;
                        arr[1] <= 16'd0;
                        arr[2] <= 16'd0;
                        arr[3] <= 16'd0;
                        arr[4] <= 16'd0;
                        arr[5] <= 16'd0;
                        arr[6] <= 16'd0;
                        arr[7] <= 16'd0;
                        arr[8] <= 16'd0;
                        arr[9] <= 16'd0;
                        arr[10] <= 16'd0;
                        arr[11] <= 16'd0;
                        arr[12] <= 16'd0;
                        arr[13] <= 16'd0;
                        arr[14] <= 16'd0;
                        arr[15] <= 16'd0;
                    end
                end

                CALCULATE: begin
                    if (current_n[0] == 1'b1) begin // If odd
                        // Store in array if space
                        if (array_idx < 4'd15) begin
                            arr[array_idx] <= current_n;
                            array_idx <= array_idx + 4'd1;
                        end
                        // Update n: 3*n + 1 (overflow wraps mod 2^16)
                        current_n <= (current_n << 1) + current_n + 16'd1;
                    end else begin // If even
                        current_n <= current_n >> 1;
                    end
                    step_count <= step_count + 8'd1;
                end

                SORT: begin
                    // Bubble sort implementation
                    // We use cycle-by-cycle comparison to fit timing
                    if (!sorting_phase) begin
                        // Compare arr[sort_j] and arr[sort_j + 1]
                        if (arr[sort_j] > arr[sort_j + 1]) begin
                            // Swap
                            temp_val <= arr[sort_j];
                            arr[sort_j] <= arr[sort_j + 1];
                            arr[sort_j + 1] <= temp_val; // Use previously saved temp or direct swap logic
                        end
                        sort_j <= sort_j + 4'd1;
                        // Check if inner loop finished
                        if (sort_j >= array_idx - 2) begin
                            sorting_phase <= 1'b1;
                            sort_j <= 4'd0;
                        end
                    end else begin
                        // Outer loop increment
                        sort_i <= sort_i + 4'd1;
                        sorting_phase <= 1'b0;
                        // Re-initialize temp_val for next pass (safe)
                        temp_val <= arr[0];
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result_len <= array_idx;
                end
            endcase
        end
    end

    // Sorting control signals logic (separate combinational logic for clarity)
    // To handle the temp_val swap correctly in a single cycle without conflict
    // We need a small tweak for the swap logic inside the always block above.
    // However, the provided code structure in the block above handles basic logic.
    // Let's refine the sorting logic to be fully inside the sequential block.
    
    // Correction for sorting state logic to ensure proper swap execution:
    // The previous block had a potential issue with 'temp_val' usage in the same cycle as read/write.
    // Revised logic:
    /* 
    In SORT state:
    if (!sorting_phase): 
      if (arr[sort_j] > arr[sort_j + 1]):
        arr[sort_j] <= arr[sort_j + 1];
        arr[sort_j + 1] <= arr[sort_j]; // Read old value before it's overwritten
      sort_j++
    */
    // Since Verilog reads the RHS at the clock edge, `arr[sort_j]` is the OLD value.
    // So the logic in the block above works correctly for the swap if we use the old values directly.
    // The explicit 'temp_val' register is actually redundant but harmless.
    // To be strictly correct for the code block in the previous step:
    // The code in the SORT block already has the swap logic. 
    // However, we need to ensure `temp_val` is initialized properly or removed.
    // Let's update the SORT logic in the main block to be explicit.
    
    // Note: Since I cannot edit the previous block once generated in this thought process,
    // I will apply the fix in the final code output. 
    // The logic below replaces the SORT block in the final output.

endmodule

// Corrected Module with refined sorting logic
module collatz_sorted_odds_fixed (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    output reg [15:0] result_0,
    output reg [15:0] result_1,
    output reg [15:0] result_2,
    output reg [15:0] result_3,
    output reg [15:0] result_4,
    output reg [15:0] result_5,
    output reg [15:0] result_6,
    output reg [15:0] result_7,
    output reg [15:0] result_8,
    output reg [15:0] result_9,
    output reg [15:0] result_10,
    output reg [15:0] result_11,
    output reg [15:0] result_12,
    output reg [15:0] result_13,
    output reg [15:0] result_14,
    output reg [15:0] result_15,
    output reg [3:0] result_len,
    output reg done
);

    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALCULATE = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state, next_state;
    reg [15:0] current_n;
    reg [7:0] step_count;
    localparam [7:0] MAX_STEPS = 8'd255;
    reg [3:0] array_idx;
    reg [15:0] arr [0:15];
    
    // Sorting counters
    reg [3:0] outer_idx; // i in bubble sort
    reg [3:0] inner_idx; // j in bubble sort
    reg swap_pending; // Flag if we need to swap
    reg [15:0] swap_val; // Value to swap in

    // Output mapping
    always @(*) begin
        result_0 = arr[0]; result_1 = arr[1]; result_2 = arr[2]; result_3 = arr[3];
        result_4 = arr[4]; result_5 = arr[5]; result_6 = arr[6]; result_7 = arr[7];
        result_8 = arr[8]; result_9 = arr[9]; result_10 = arr[10]; result_11 = arr[11];
        result_12 = arr[12]; result_13 = arr[13]; result_14 = arr[14]; result_15 = arr[15];
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CALCULATE;
                else next_state = IDLE;
            end
            CALCULATE: begin
                if (current_n == 16'd1 || step_count >= MAX_STEPS) begin
                    if (array_idx == 4'd0) next_state = FINISH;
                    else next_state = SORT;
                end else next_state = CALCULATE;
            end
            SORT: begin
                // Bubble sort: one swap or comparison per cycle
                if (outer_idx >= array_idx - 1) begin
                    next_state = FINISH;
                end else begin
                    next_state = SORT;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            // Initialize array to 0
            arr[0] <= 16'd0; arr[1] <= 16'd0; arr[2] <= 16'd0; arr[3] <= 16'd0;
            arr[4] <= 16'd0; arr[5] <= 16'd0; arr[6] <= 16'd0; arr[7] <= 16'd0;
            arr[8] <= 16'd0; arr[9] <= 16'd0; arr[10] <= 16'd0; arr[11] <= 16'd0;
            arr[12] <= 16'd0; arr[13] <= 16'd0; arr[14] <= 16'd0; arr[15] <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_n <= n_in;
                        step_count <= 8'd0;
                        array_idx <= 4'd0;
                        outer_idx <= 4'd0;
                        inner_idx <= 4'd0;
                        swap_pending <= 1'b0;
                        // Clear array explicitly (optional if logic handles valid data, but good for safety)
                    end
                end

                CALCULATE: begin
                    if (current_n[0]) begin // Odd
                        if (array_idx < 4'd15) begin
                            arr[array_idx] <= current_n;
                            array_idx <= array_idx + 4'd1;
                        end
                        current_n <= (current_n << 1) + current_n + 16'd1;
                    end else begin // Even
                        current_n <= current_n >> 1;
                    end
                    step_count <= step_count + 8'd1;
                end

                SORT: begin
                    // Bubble sort one pass per cycle
                    // If swap_pending is true, perform the swap for the previous comparison
                    if (swap_pending) begin
                        arr[inner_idx - 1] <= swap_val; // Value from right
                        arr[inner_idx] <= arr[inner_idx - 1]; // Value from left
                        swap_pending <= 1'b0;
                    end else begin
                        // Perform comparison if within bounds
                        // We only enter SORT state if array_idx > 1 (checked via outer_idx limit)
                        // inner_idx points to the right element in the pair (j)
                        if (arr[inner_idx - 1] > arr[inner_idx]) begin
                            // Schedule swap for next cycle
                            swap_pending <= 1'b1;
                            swap_val <= arr[inner_idx]; // Save right value
                            // Note: left value (arr[inner_idx-1]) is saved in the register implicitly 
                            // or we rely on the assignment logic in the 'if(swap_pending)' block above.
                        end
                        inner_idx <= inner_idx + 4'd1;
                    end

                    // Update indices
                    // We assume 1 cycle per inner step.
                    // Check if inner loop finished: inner_idx reaches the boundary
                    // Boundary for inner loop for pass 'outer_idx' is (array_idx - 1 - outer_idx)
                    // However, keeping it simple: inner_idx goes from 1 to array_idx-1
                    if (!swap_pending && inner_idx >= array_idx) begin
                        outer_idx <= outer_idx + 4'd1;
                        inner_idx <= 4'd1; // Reset for next pass (comparing 0 and 1)
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result_len <= array_idx;
                end
            endcase
        end
    end
endmodule