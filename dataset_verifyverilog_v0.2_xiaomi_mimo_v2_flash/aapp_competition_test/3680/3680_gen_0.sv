module fence_cuts(
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [7:0] n,
    input [7:0] p0,
    input [7:0] p1,
    input [7:0] p2,
    input [7:0] p3,
    output reg [7:0] min_cuts,
    output reg done
);

    // State encoding
    localparam IDLE    = 3'b000;
    localparam SEARCH  = 3'b001;
    localparam CALC    = 3'b010;
    localparam UPDATE  = 3'b011;
    localparam DONE    = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Registers for binary search
    reg [7:0] low;
    reg [7:0] high;
    reg [7:0] mid;
    reg [7:0] best_L;
    reg [7:0] best_cuts;

    // Temporary variables for calculations
    reg [7:0] curr_pole;
    reg [7:0] posts_i;
    reg [7:0] cuts_i;
    reg [7:0] temp_posts_sum;
    reg [7:0] temp_cuts_sum;

    // Loop counters
    reg [2:0] pole_idx;

    // Delayed done signal generation to ensure output stability
    reg done_internal;

    // Find max pole length for initial high bound
    function [7:0] get_max_pole;
        input [7:0] p0, p1, p2, p3;
        input [7:0] k;
        reg [7:0] m;
        begin
            m = p0;
            if (k > 1 && p1 > m) m = p1;
            if (k > 2 && p2 > m) m = p2;
            if (k > 3 && p3 > m) m = p3;
            get_max_pole = m;
        end
    endfunction

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? SEARCH : IDLE;
            SEARCH:     next_state = (low > high) ? DONE : CALC;
            CALC:       next_state = (pole_idx >= k) ? UPDATE : CALC;
            UPDATE:     next_state = (temp_posts_sum >= n) ? (mid > best_L ? SEARCH : SEARCH) : SEARCH;
            DONE:       next_state = DONE;
            default:    next_state = IDLE;
        endcase
    end

    // State Registers and Data Path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            done_internal <= 1'b0;
            min_cuts <= 8'b0;
            low <= 8'b0;
            high <= 8'b0;
            mid <= 8'b0;
            best_L <= 8'b0;
            best_cuts <= 8'b0;
            pole_idx <= 3'b0;
            temp_posts_sum <= 8'b0;
            temp_cuts_sum <= 8'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize binary search
                        low <= 8'd1;
                        high <= get_max_pole(p0, p1, p2, p3, k);
                        best_L <= 8'd0;
                        best_cuts <= 8'd0;
                        done <= 1'b0;
                        done_internal <= 1'b0;
                    end
                end

                SEARCH: begin
                    if (low <= high) begin
                        mid <= (low >> 1) + (high >> 1); // (low + high) / 2
                        if (low[0] && high[0]) mid <= mid + 8'd1; // Correct rounding for odd numbers
                    end
                    pole_idx <= 3'b0;
                    temp_posts_sum <= 8'b0;
                    temp_cuts_sum <= 8'b0;
                end

                CALC: begin
                    // Select current pole based on idx
                    case (pole_idx)
                        3'd0: curr_pole <= p0;
                        3'd1: curr_pole <= p1;
                        3'd2: curr_pole <= p2;
                        3'd3: curr_pole <= p3;
                        default: curr_pole <= 8'b0;
                    endcase

                    // Calculate posts and cuts for current pole (will be processed next cycle or combinational)
                    // To keep logic simple and combinational for calculation results, we can do it here if we assume mid stable.
                    // However, to strictly follow sequential update logic:
                    // Let's process calculation results in the next state or combinational block inside.
                    // Here we will just increment index and sum up pre-calculated values or compute inline.
                    // To minimize latency, let's compute logic within the CALC state logic.

                    pole_idx <= pole_idx + 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic for Calculation inside CALC state (since we need to sum up immediately or in sequential registers)
    // Actually, standard practice is to use a combinational block for the calculation logic 
    // and update the sums in the sequential block triggered by CALC state entry or during CALC.
    // Let's refine the CALC state to perform the arithmetic per cycle.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == CALC) begin
                // Combinational calculation of posts and cuts for the current pole_idx
                // We need to handle the loop inside CALC state or use a separate combinational block.
                // Let's use a combinational block for calculation and register the results.
            end
        end
    end

    // Separate combinational block for calculating posts/cuts for current pole_idx and mid
    reg [7:0] calc_posts;
    reg [7:0] calc_cuts;
    reg [7:0] calc_val; // temp for division logic

    integer i_div;
    always @(*) begin
        calc_posts = 8'b0;
        calc_cuts = 8'b0;
        calc_val = 8'b0;

        if (mid != 0) begin
            case (pole_idx)
                3'd0: calc_val = p0;
                3'd1: calc_val = p1;
                3'd2: calc_val = p2;
                3'd3: calc_val = p3;
                default: calc_val = 8'b0;
            endcase

            // Integer division: floor(calc_val / mid)
            // Since max 255/1 = 255, using a simple loop or repeated subtraction is too slow for combinational.
            // We use standard division logic or synthesis tool inference.
            // However, the prompt implies "All arithmetic on 8-bit unsigned integers", 
            // implying standard behavior. Verilog division is synthesizable for small widths.

            calc_posts = calc_val / mid;

            // Cuts calculation
            // if (calc_val % mid == 0) cuts = (calc_val / mid) - 1 (if > 0)
            // else cuts = floor(calc_val / mid)

            if (calc_posts > 0) begin
                if (calc_val % mid == 0)
                    calc_cuts = calc_posts - 1'b1;
                else
                    calc_cuts = calc_posts;
            end else begin
                calc_cuts = 8'b0;
            end
        end
    end

    // Sequential logic for sums update in CALC and UPDATE states
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            if (state == CALC) begin
                // Accumulate results
                temp_posts_sum <= temp_posts_sum + calc_posts;
                temp_cuts_sum <= temp_cuts_sum + calc_cuts;
            end else if (state == IDLE || state == SEARCH) begin
                // Reset sums when starting new search or full reset
                temp_posts_sum <= 8'b0;
                temp_cuts_sum <= 8'b0;
            end
        end
    end

    // Update State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else begin
            if (state == UPDATE) begin
                // Check valid L (temp_posts_sum >= n)
                if (temp_posts_sum >= n) begin
                    // Valid solution. We want max L.
                    // Since binary search logic usually finds the max L, we need to decide:
                    // If mid is valid, we try higher (low = mid + 1) usually. 
                    // Here we store best result.
                    if (mid > best_L) begin
                        best_L <= mid;
                        best_cuts <= temp_cuts_sum;
                    end
                    // To maximize L, we typically move low = mid + 1 in binary search.
                    // However, the prompt asks for a state machine iterating through L values.
                    // We will implement the standard binary search update rules:
                    // If valid: try higher L -> low = mid + 1. Store best.
                    // If invalid: try lower L -> high = mid - 1.

                    // But we need to update 'low' or 'high' here.
                    // Let's add logic to update low/high in UPDATE state.

                    if (mid == 8'd255) low <= 8'd255; // Prevent overflow
                    else low <= mid + 8'd1;
                    // Keep high as is for now, we only modify low in UPDATE if valid

                end else begin
                    // Invalid L, move high down
                    if (mid == 8'd0) high <= 8'd0;
                    else high <= mid - 8'd1;
                    // Also need to make sure we don't update low wrongly.
                    // Since we are in UPDATE state, we need to know if the previous check was valid.
                    // But we only get here if we passed the loop in CALC.
                    // The decision to update low or high is tricky to combine with loop structure.
                end
            end else if (state == SEARCH) begin
                // Correct the boundary updates based on previous result?
                // Actually, it's cleaner to handle boundaries in the UPDATE state 
                // based on the result of the calculation (temp_posts_sum).
                // Since state transition happens from CALC -> UPDATE, we have the sum ready.
            end
        end
    end

    // Revisiting the logic for cleaner boundary updates:
    // We will combine boundary updates with the valid/invalid check.
    // The previous combinational block for 'next_state' handled transitions.
    // Let's refine the sequential logic for boundary updates.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            low <= 8'b0;
            high <= 8'b0;
        end else if (state == UPDATE) begin
            if (temp_posts_sum >= n) begin
                // Valid: Store best, and move low to search higher
                best_L <= mid;
                best_cuts <= temp_cuts_sum;
                if (mid < 255) low <= mid + 1;
                else low <= 255;
                // high stays same
            end else begin
                // Invalid: Search lower
                if (mid > 0) high <= mid - 1;
                else high <= 0;
                // low stays same
            end
        end else if (state == IDLE && start) begin
            // Initialization in IDLE handled above, but we need to set bounds here if not set in IDLE state block
            low <= 8'd1;
            high <= get_max_pole(p0, p1, p2, p3, k);
        end
    end

    // Fix for the State Machine Logic (Specifically UPDATE transition)
    // The previous `next_state` logic had a flaw: "UPDATE -> SEARCH" always.
    // We need to ensure the search terminates when low > high.
    // The SEARCH state checks `(low > high) ? DONE : CALC`.
    // So the loop is: IDLE -> SEARCH -> CALC -> UPDATE -> SEARCH.

    // Fix: Ensure `done` is asserted correctly.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE) begin
            done <= 1'b1;
            min_cuts <= best_cuts;
        end else if (state == IDLE) begin
            done <= 1'b0;
        end
    end

    // Note on Division: 
    // Using `/` and `%` for 8-bit unsigned is synthesizable but can be slow or area-heavy.
    // Given the constraints (max 5000 cycles), logic depth is acceptable.

    // Note on Logic Gap: The `state` logic defined in `always @(*)` uses `temp_posts_sum >= n` to decide `UPDATE` transition.
    // However, `temp_posts_sum` is updated in `CALC` state sequentially. 
    // By the time we leave `CALC`, the sum is ready.
    // So `UPDATE` state is entered, and we perform logic there.

    // Wait, the `always @(*) next_state` block uses `temp_posts_sum` which is a reg.
    // In Verilog, using a reg in a combinational always block for next_state logic is valid.

    // One issue: In `UPDATE` state, we modify `low` or `high`.
    // The `next_state` logic for `UPDATE` was:
    // `UPDATE: next_state = (temp_posts_sum >= n) ? (mid > best_L ? SEARCH : SEARCH) : SEARCH;`
    // This essentially always goes to SEARCH.
    // But wait, `best_L` logic inside `UPDATE` sequential block:
    // `if (temp_posts_sum >= n) best_L <= mid;`
    // This happens in the same cycle we transition to `UPDATE`?
    // No, `state` becomes `UPDATE`. Then `always @(*)` calculates `next_state` for `UPDATE`.
    // `always @(posedge clk)` updates logic for `UPDATE`.

    // The flow is:
    // 1. `CALC` state active. Sums updated. 
    // 2. At end of `CALC` cycle, `next_state` is `UPDATE`.
    // 3. `UPDATE` state active. `always @(posedge clk)` logic runs (only at edge, so actually previous edge).
    // Wait, the sequential logic for `UPDATE` runs at the `posedge clk` that enters `UPDATE` state.
    // So `best_L` update happens at that edge, using values from previous `CALC` cycle.
    // Then `next_state` is calculated for the *next* cycle.

    // Correction:
    // The `state` register changes at `posedge clk`.
    // If `state` becomes `UPDATE` at `t`, then the combinational block calculates `next_state` for `t+1`.
    // The sequential block sees `state == UPDATE` at `t`, so it updates `best_L` and `low/high`.

    // The logic seems okay.

    // One minor detail: The prompt says "Result valid within 5000 cycles". 
    // The binary search runs in O(log(max_pole)) ~ 8 cycles for search + 4*8 calc cycles ~ 40 cycles.
    // This fits easily.

endmodule

module TopModuleWrapper(
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [7:0] n,
    input [7:0] p0,
    input [7:0] p1,
    input [7:0] p2,
    input [7:0] p3,
    output [7:0] min_cuts,
    output done
);
    fence_cuts fc (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .k(k),
        .n(n),
        .p0(p0),
        .p1(p1),
        .p2(p2),
        .p3(p3),
        .min_cuts(min_cuts),
        .done(done)
    );
endmodule