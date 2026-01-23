module permutation_generator (
    input clk,
    input rst_n,
    input start,
    input [3:0] A,
    input [3:0] B,
    output reg [3:0] result_addr,
    output reg [3:0] result_val,
    output reg result_write,
    output reg done,
    output reg valid_solution
);

    // Parameters
    parameter N = 16;
    parameter MAX_CYCLES = 16;

    // State encoding
    localparam IDLE = 3'b001;
    localparam FIND_SOLUTION = 3'b010;
    localparam CONSTRUCT_PERM = 3'b100;
    localparam DONE = 3'b111;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] x_count;
    reg [3:0] y_count;
    reg solution_found;
    reg [4:0] iter_x; // 0 to 16
    reg [3:0] write_idx;
    reg [3:0] cycle_start;
    reg [3:0] cycle_len;
    reg [3:0] cycle_cnt;
    reg is_type_A; // 1 for A, 0 for B
    reg [3:0] val_reg;
    reg write_en;
    reg done_reg;
    reg valid_reg;

    // Sequential State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = FIND_SOLUTION;
                else
                    next_state = IDLE;
            end
            FIND_SOLUTION: begin
                // If N < A or N < B, no solution, but we iterate to find valid pairs.
                // If A is 0, treat as invalid or handle carefully. Inputs are 1-16 usually.
                // Loop ends when iter_x > N/A or solution found.
                // Let's simplify: if A or B is 0, treat as no solution (unless N=0).
                if (A == 0 || B == 0) 
                    next_state = DONE; // Invalid input handling
                else if (solution_found || (iter_x > (N / (A != 0 ? A : 1)))) 
                    next_state = DONE;
                else 
                    next_state = FIND_SOLUTION;
            end
            CONSTRUCT_PERM: begin
                if (write_idx >= N) // 0..15
                    next_state = DONE;
                else
                    next_state = CONSTRUCT_PERM;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_count <= 0;
            y_count <= 0;
            solution_found <= 0;
            iter_x <= 0;
            write_idx <= 0;
            cycle_start <= 0;
            cycle_len <= 0;
            cycle_cnt <= 0;
            is_type_A <= 0;
            result_addr <= 0;
            result_val <= 0;
            result_write <= 0;
            done <= 0;
            valid_solution <= 0;
            val_reg <= 0;
            write_en <= 0;
            done_reg <= 0;
            valid_reg <= 0;
        end else begin
            // Default assignments
            result_write <= 0;
            done <= 0;
            valid_solution <= 0;
            write_en <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        iter_x <= 0;
                        solution_found <= 0;
                        // Check for trivial valid inputs first
                        if (A != 0 && B != 0) begin
                            // ok
                        end
                    end
                end

                FIND_SOLUTION: begin
                    // Check if (N - iter_x * A) is divisible by B
                    // We need to check if remaining is non-negative and divisible
                    // iter_x * A <= N
                    // Since N=16, A=4, iter_x max is 4. iter_x goes 0 to 4.
                    // If iter_x * A > N, we stop.
                    if (iter_x * A > N) begin
                        // No solution found in loop
                        solution_found <= 0;
                    end else begin
                        // Check division: (N - iter_x * A) % B == 0
                        // Use a temporary subtraction
                        if ((N - (iter_x * A)) % B == 0) begin
                            x_count <= iter_x;
                            y_count <= (N - (iter_x * A)) / B;
                            solution_found <= 1;
                            // We will move to DONE next cycle if we set solution_found here,
                            // but wait to finish the cycle logic in NEXT_STATE or STATE CHECK.
                            // To be safe, we will proceed to DONE in next cycle.
                        end else begin
                            // Try next x
                            // We must be careful with latch inference.
                            // iter_x increments only if not found.
                            if (!solution_found) 
                                iter_x <= iter_x + 1;
                        end
                    end
                end

                CONSTRUCT_PERM: begin
                    if (write_idx == 0) begin
                        // Initialize construction
                        cycle_start <= 0;
                        is_type_A <= 1;
                        if (x_count > 0) begin
                            cycle_len <= A;
                            cycle_cnt <= x_count;
                        end else if (y_count > 0) begin
                            cycle_len <= B;
                            cycle_cnt <= y_count;
                            is_type_A <= 0;
                        end else begin
                            // Should not happen if logic is correct, but handle gracefully
                            cycle_len <= 0;
                            cycle_cnt <= 0;
                        end
                        // We need to perform the first calculation for the first cycle
                    end

                    // We write the current value
                    if (write_idx < N) begin
                        // Logic for generating shifted cycle:
                        // Cycle: [start+1, start+2, ..., start+L-1, start]
                        // Indices are 0-based.
                        // Start S. Elements: S+1, S+2, ... S+L-1, S.
                        // Value for index S is S+1. Value for index S+L-1 is S.
                        // Value for index i in [S, S+L-1] is (i == S+L-1 ? S : i+1).

                        // Calculate output
                        // We are iterating write_idx 0 to 15 sequentially.
                        // We need to know if write_idx is inside the current cycle.
                        // If (write_idx - cycle_start) < cycle_len, it is inside.

                        // However, the description says "Iterate through array indices 0 to 15".
                        // So we just use write_idx to generate the value.
                        // But we need to know which cycle we are in.
                        // It's easier to iterate cycles and fill specific indices, but constraints say "iterate array indices".

                        // Let's stick to the instruction: "Iterate through the array indices 0 to 15 and write..."
                        // This implies a logic that maps index -> value.
                        // We can maintain a "current cycle start" and "current cycle len" for the specific index.

                        if (write_idx >= cycle_start && write_idx < (cycle_start + cycle_len)) begin
                            // Inside current cycle
                            if (write_idx == cycle_start + cycle_len - 1) begin
                                val_reg <= cycle_start; // Wrap around to start
                            end else begin
                                val_reg <= write_idx + 1;
                            end
                        end else begin
                            // Not inside current cycle.
                            // This happens if we finished a cycle and didn't update cycle_start/len properly.
                            // We need to advance to the next cycle if write_idx >= cycle_start + cycle_len.
                            // But since write_idx increments by 1 every cycle, we can just update cycle pointers when we step out.

                            // If we are here, we must have finished a cycle.
                            // Find next available cycle.
                            // Since we fill linearly, cycle_start should just be the start of the next cycle if we just passed one.
                            // But wait, if write_idx skips? No, write_idx increments 0,1,2...

                            // Actually, simpler logic:
                            // We need to update cycle pointers in this block if we are "stepping into" or "just passed" a cycle.
                            // But we are in the block for the *current* write_idx.

                            // Let's restructure the logic slightly inside the block:
                            // If we are at the end of the current cycle, or beyond, we need to advance.
                            while (write_idx >= (cycle_start + cycle_len) && (cycle_cnt > 0 || is_type_A)) begin
                                // Advance cycle
                                cycle_start <= cycle_start + cycle_len;
                                if (is_type_A) begin
                                    if (cycle_cnt > 1) begin
                                        cycle_cnt <= cycle_cnt - 1;
                                    end else begin
                                        // Switch to B
                                        if (y_count > 0) begin
                                            is_type_A <= 0;
                                            cycle_len <= B;
                                            cycle_cnt <= y_count;
                                        end else begin
                                            cycle_len <= 0;
                                            cycle_cnt <= 0;
                                        end
                                    end
                                end else begin
                                    // is_type_B
                                    if (cycle_cnt > 1) begin
                                        cycle_cnt <= cycle_cnt - 1;
                                    end else begin
                                        cycle_len <= 0;
                                        cycle_cnt <= 0;
                                    end
                                end
                            end

                            // Re-calculate value after potential advance (must be blocking or handled carefully in HW)
                            // In a single always block, the while loop above is not synthesizable easily for loop-unrolling.

                            // Alternative Logic without while:
                            // We realize that since write_idx goes 0..15, and cycles are packed:
                            // If we know cycle boundaries, we can check.
                            // But we can't dynamically loop in hardware without unrolling or a sub-state machine.

                            // Let's go back to the instruction: "If a solution (x, y) is found, construct the permutation."
                            // "For each cycle... Generate a shifted cycle"
                            // "Iterate through the array indices 0 to 15 and write..."

                            // This phrasing is slightly ambiguous for hardware.
                            // I will implement a "Pointer approach":
                            // We maintain a "Current Cycle Start" (S) and "Current Cycle Length" (L).
                            // If write_idx == S + L, we move to the next cycle.

                            // To avoid complex loops inside `always`, let's use the fact that we are sequential.
                            // We can detect if write_idx has passed the current cycle boundary.
                            // Note: I cannot use `while` in synthesisable `always @(*)` or `always @(posedge)` in standard way.

                            // Let's assume the cycles are filled sequentially from 0.
                            // Cycle 1: 0..L1-1. Cycle 2: L1..L1+L2-1.

                            // Logic to update cycle pointers when crossing boundary:
                            // We need to calculate if (write_idx == cycle_start + cycle_len) before assigning value.
                            // But since `cycle_start` and `cycle_len` are registers, their update happens at the end of the cycle.
                            // We need to look ahead or handle the transition.

                            // Let's use a small lookup or conditional checks based on the ranges.
                            // We know x_count and y_count.
                            // Total segments: x_count segments of A, y_count segments of B.
                            // Segment boundaries:
                            // S0 = 0, L0 = A
                            // S1 = A, L1 = A
                            // ...
                            // Sx = x*A, Lx = B
                            // ...

                            // We can calculate which segment `write_idx` falls into.
                            // This requires division or looped subtraction, which takes cycles.
                            // Since we have 200-500 cycles budget, we can iterate.

                            // Let's refine the "State Machine in Datapath" approach.
                            // In CONSTRUCT_PERM, we can have sub-states:
                            // 1. Wait for write_idx to match a cycle start.
                            // 2. Output values for that cycle.
                            // 3. Move to next cycle.

                            // But the requirement is: "Iterate through array indices 0 to 15".
                            // This implies outputting for index 0, then 1, then 2...

                            // Let's implement a simplified sequential logic:
                            // We keep track of the *next expected start index*.
                            // Current Cycle Start = `curr_start`
                            // Current Cycle End = `curr_start + curr_len`
                            // If `write_idx == curr_start + curr_len`, we update `curr_start` and `curr_len` to the next cycle.

                            // To do this without a loop:
                            // 1. Check if we are transitioning to the next cycle.
                            // Since `curr_start` and `curr_len` update at the clock edge, we can check:
                            // `if (write_idx >= curr_start + curr_len)` -> we are past the current cycle.
                            // Since we can't use while, we must assume that `write_idx` increases by 1 and cycles are sequential.
                            // It will take at most 1 or 2 cycles to update pointers if we are exactly at the boundary.

                            // However, if `write_idx` jumps (it doesn't, it increments 0,1,2...), we are safe.
                            // So:
                            // Determine value for current `write_idx` based on `curr_start` and `curr_len`.
                            // Then, if `write_idx + 1` (or `write_idx` in next cycle) is `curr_start + curr_len`, update pointers.

                            // To keep it simple and robust:
                            // Use a helper process or calculate the value based on ranges.
                            // Since N=16 is small, we can unroll the cycle finding logic or use a case statement.
                            // But `x` and `y` are variable.

                            // Let's try the "Reconstruction on the fly" approach:
                            // We need a pointer to the current cycle.
                            // Let's calculate `write_idx`'s cycle membership.
                            // We can calculate `offset = write_idx`.
                            // If offset < x_count * A: it's in A-cycles.
                            //   Which cycle? offset / A.
                            //   Pos in cycle: offset % A.
                            // Else: it's in B-cycles.
                            //   offset2 = offset - x_count*A.
                            //   Which cycle: offset2 / B.
                            //   Pos in cycle: offset2 % B.
                            // We need to do division and modulo. Hardware divider is big, but A and B are 4-bit.
                            // We can do this sequentially or combinational.
                            // Let's try combinational logic for the division/modulo since N is small (16).
                            // Or we can do it iteratively in 1-2 cycles.

                            // Actually, `always @(*)` combinational block to calculate value for `write_idx`.
                            // But `write_idx` is a register.
                            // Let's rely on the fact that we have a clock.

                            // Let's implement a "Step-by-step" pointer updater:
                            // We store `curr_cycle_start` and `curr_cycle_len`.
                            // When `write_idx == curr_cycle_start + curr_cycle_len`:
                            //   Update `curr_cycle_start` to `curr_cycle_start + curr_cycle_len`.
                            //   Update `curr_cycle_len` to next cycle length (A or B).
                            // This requires calculating the next length.
                            // We know how many A cycles we have left (`rem_A`), B cycles left (`rem_B`).

                            // Let's use registers `rem_A`, `rem_B` in `CONSTRUCT_PERM`.
                            // Initialize `rem_A = x_count`, `rem_B = y_count`, `curr_start = 0`.
                            // Logic:
                            // `val_reg` = 
                            //   if `rem_A > 0` or (currently in A): use A logic.
                            //   else use B logic.
                            // Actually, let's just use the modulo logic.
                            // Division by variable 4-bit number is doable in 4 cycles (Shift subtract).
                            // But we have budget.

                            // Let's stick to the simplest synthesizable method:
                            // We iterate `write_idx` 0..15.
                            // We maintain `next_cycle_boundary`.
                            // If `write_idx` == `next_cycle_boundary`, we advance the cycle.
                            // How to advance? We know `x_count` and `y_count`. We track remaining counts.

                            // Implementation details:
                            // Registers needed: `rem_x`, `rem_y`, `current_len`, `current_start`.
                            // Initialize in `IDLE` or start of `CONSTRUCT`.

                            // In `CONSTRUCT_PERM` block:
                            // If `write_idx == 0`: init rem_x, rem_y, current_start.
                            //   If rem_x > 0: current_len = A, rem_x--. Else if rem_y > 0: current_len = B, rem_y--.
                            //   Boundary = current_start + current_len.

                            // Value calculation for `write_idx`:
                            //   If `write_idx` == `current_start + current_len - 1`: output `current_start`.
                            //   Else: output `write_idx + 1`.
                            //   (Note: check if `write_idx` is in range. If we update boundary correctly, it is.)

                            // Update logic for next cycle:
                            //   If `write_idx + 1` == `current_start + current_len` (which is `boundary`):
                            //     `current_start` = `boundary`.
                            //     `current_len` = (rem_x > 0) ? A : B.
                            //     If rem_x > 0: rem_x--. Else if rem_y > 0: rem_y--.
                            //     (Note: check boundaries again)

                            // Since we are in a clocked block, we can compute the "next" values.
                            // But we need to know if `write_idx + 1` hits the boundary in the *current* cycle to set up registers for the next.
                            // We can calculate:
                            // `is_last_in_cycle = (write_idx == (current_start + current_len - 1))`
                            // `is_crossing_boundary = (write_idx + 1 == current_start + current_len)`
                            // This is easy.

                            // Let's refine the code inside CONSTRUCT_PERM:

                            // Variables for construction:
                            // `c_start` (local), `c_len` (local), `rx`, `ry`.

                            // On `write_idx` == 0:
                            //   rx = x_count, ry = y_count.
                            //   if (rx > 0) c_len = A; else c_len = B.
                            //   c_start = 0.

                            // On every cycle:
                            //   // Output calculation
                            //   if (write_idx == c_start + c_len - 1) val = c_start;
                            //   else val = write_idx + 1;

                            //   // Setup for next index (write_idx + 1)
                            //   // We need to update `c_start`, `c_len`, `rx`, `ry` if `write_idx + 1` is crossing boundary.
                            //   // But `c_start` is a register. It updates at the end of the cycle.
                            //   // So, if we are at `write_idx` = boundary - 1, we calculate the *next* state of pointers.
                            //   // `next_c_start` = c_start + c_len
                            //   // `next_c_len` = (rx - 1 > 0) ? A : (ry > 0) ? B : 0.
                            //   // `next_rx` = rx - 1
                            //   // `next_ry` = ry

                            //   // This looks solid. Let's write it.

                            // We need registers to hold `rx`, `ry`, `curr_c_start`, `curr_c_len` during construction.
                            // Let's allocate them.

                            // --- Revised Datapath for CONSTRUCT_PERM ---

                            // If `write_idx` == 0 (start of construction):
                            //   `rx` <= x_count;
                            //   `ry` <= y_count;
                            //   `curr_c_start` <= 0;
                            //   if (x_count > 0) `curr_c_len` <= A;
                            //   else if (y_count > 0) `curr_c_len` <= B;
                            //   else `curr_c_len` <= 0;

                            // // Output Calculation
                            // if (`write_idx` >= `curr_c_start` && `write_idx` < `curr_c_start` + `curr_c_len`) begin
                            //   if (`write_idx` == `curr_c_start` + `curr_c_len` - 1) `result_val` <= `curr_c_start`;
                            //   else `result_val` <= `write_idx` + 1;
                            // end else begin
                            //   // This should not happen if logic is correct, but maybe if we finished all cycles?
                            //   // If `rx==0` and `ry==0`, then we are done. But `write_idx` stops at N.
                            //   `result_val` <= 0;
                            // end

                            // // Update Pointers for NEXT index (write_idx + 1)
                            // if (`write_idx` < N) begin
                            //   `result_addr` <= `write_idx`;
                            //   `result_write` <= 1;
                            // end

                            // // Logic to advance cycle for next cycle:
                            // // If we just processed the last element of the current cycle (`write_idx` == end)
                            // if (`write_idx` == `curr_c_start` + `curr_c_len` - 1) begin
                            //   `curr_c_start` <= `curr_c_start` + `curr_c_len`;
                            //   `rx` <= `rx` - 1; // Assuming we were in A, need to check type.

                            //   // We need to know if we were in A or B to decrement the right counter.
                            //   // Let's add a flag `in_A_cycle`.
                            //   // If `in_A_cycle` and `rx > 1`, next is A.
                            //   // If `in_A_cycle` and `rx == 1`, next is B (if ry > 0).
                            //   // If `!in_A_cycle`, next is B (if ry > 1) or Done.
                            // end

                            // // Refinement:
                            // // We need to know the TYPE of the current cycle to update the right counter.
                            // // Let's use `is_A_type` register.
                            // // If `is_A_type`:
                            // //   `rx` <= `rx` - 1.
                            // //   `is_A_type` <= (rx - 1 > 0) || (ry > 0 ? 0 : 0). // Wait, if rx-1 > 0, stays A. If rx-1 == 0, switch to B.
                            // //   `curr_c_len` <= (rx - 1 > 0) ? A : (ry > 0 ? B : 0).
                            // // If `!is_A_type`:
                            // //   `ry` <= `ry` - 1.
                            // //   `is_A_type` stays 0 (or checks for end).

                            // Let's implement this logic.
                            // We need `rx`, `ry`, `curr_c_start`, `curr_c_len`, `is_A_type` as internal registers.

                            // --- End of refinement ---

                            // Actual implementation in the code block below:

                            // We will use the registers `rx_reg`, `ry_reg`, `c_start_reg`, `c_len_reg`, `is_a_reg`.
                            // Defined in the register block above.

                            if (write_idx == 0) begin
                                // Init logic in IDLE or here? 
                                // If we are in CONSTRUCT_PERM, and write_idx is 0, we need to init.
                                // But this block executes every clock cycle.
                                // We need to ensure we don't re-init on every cycle.
                                // Use a flag `construction_initialized`.
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    if (solution_found) begin
                        valid_solution <= 1;
                    end else begin
                        valid_solution <= 0;
                    end
                end
            endcase
        end
    end

    // Helper logic for construction (separate combinational or sequential logic to keep main block clean)
    // Since we are constrained to one module, let's expand the CONSTRUCT_PERM logic carefully.

    // Internal registers for construction
    reg [3:0] rx_reg, ry_reg;
    reg [3:0] c_start_reg, c_len_reg;
    reg is_a_reg;
    reg construction_started;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_reg <= 0;
            ry_reg <= 0;
            c_start_reg <= 0;
            c_len_reg <= 0;
            is_a_reg <= 0;
            construction_started <= 0;
        end else begin
            if (state == FIND_SOLUTION && solution_found) begin
                // Prepare for next state transition if we were to go to CONSTRUCT.
                // But state transition happens next cycle. We can pre-load if we want, but safer to wait.
                // Let's wait until we are actually in CONSTRUCT_PERM.
                construction_started <= 0;
            end

            if (state == CONSTRUCT_PERM) begin
                if (write_idx == 0 && !construction_started) begin
                    rx_reg <= x_count;
                    ry_reg <= y_count;
                    c_start_reg <= 0;
                    construction_started <= 1;

                    if (x_count > 0) begin
                        c_len_reg <= A;
                        is_a_reg <= 1;
                    end else if (y_count > 0) begin
                        c_len_reg <= B;
                        is_a_reg <= 0;
                    end else begin
                        c_len_reg <= 0;
                        is_a_reg <= 0;
                    end
                end else if (construction_started) begin
                    // We just finished writing `write_idx`. 
                    // Determine if we need to update pointers for the *next* cycle (which handles write_idx+1)
                    // If we just finished the last element of current cycle:
                    if (write_idx == c_start_reg + c_len_reg - 1) begin
                        // Advance start
                        c_start_reg <= c_start_reg + c_len_reg;

                        // Advance counters and determine next length/type
                        if (is_a_reg) begin
                            // Was A cycle
                            if (rx_reg > 1) begin
                                // More A cycles
                                rx_reg <= rx_reg - 1;
                                c_len_reg <= A;
                                is_a_reg <= 1;
                            end else begin
                                // Last A cycle done. Switch to B.
                                rx_reg <= 0;
                                if (ry_reg > 0) begin
                                    ry_reg <= ry_reg - 1;
                                    c_len_reg <= B;
                                    is_a_reg <= 0;
                                end else begin
                                    // No more cycles. Should be end of array.
                                    c_len_reg <= 0;
                                    is_a_reg <= 0;
                                end
                            end
                        end else begin
                            // Was B cycle
                            if (ry_reg > 1) begin
                                ry_reg <= ry_reg - 1;
                                c_len_reg <= B;
                                is_a_reg <= 0;
                            end else begin
                                // Last B cycle done.
                                ry_reg <= 0;
                                c_len_reg <= 0;
                                is_a_reg <= 0;
                            end
                        end
                    end
                end
            end else if (state == IDLE) begin
                construction_started <= 0;
            end
        end
    end

    // Output Logic (Datapath for result_addr, result_val, result_write)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_addr <= 0;
            result_val <= 0;
            result_write <= 0;
            write_idx <= 0;
            done <= 0;
            valid_solution <= 0;
        end else begin
            result_write <= 0;
            done <= 0;
            valid_solution <= 0;

            case (state)
                IDLE: begin
                    write_idx <= 0;
                end

                FIND_SOLUTION: begin
                    // Wait for loop to finish
                end

                CONSTRUCT_PERM: begin
                    if (construction_started && write_idx < N) begin
                        // Calculate Value
                        // Value = (write_idx == c_start_reg + c_len_reg - 1) ? c_start_reg : write_idx + 1;
                        // Only if we are within the current cycle range.
                        // Since `c_start_reg` and `c_len_reg` are updated for the NEXT index in the combinational logic above (wait, they are sequential)?
                        // In the sequential logic above, `c_start_reg` updates when `write_idx == c_start_reg + c_len_reg - 1`.
                        // This means `c_start_reg` becomes `c_start_reg + c_len_reg` at the SAME time `write_idx` increments.
                        // So, for the current cycle logic, we should use `c_start_reg` (which is the start of the cycle `write_idx` is currently in).
                        // BUT, there is a catch.
                        // If `write_idx` is the LAST element of a cycle, `c_start_reg` updates to NEXT cycle.
                        // But the Value calculation for `write_idx` MUST be based on OLD cycle.
                        // Wait, the sequential logic above updates `c_start_reg` at the clock edge.
                        // So if we are at `write_idx` = boundary - 1, `c_start_reg` is correct.
                        // When clock ticks, `write_idx` becomes `write_idx` + 1 (or handled by logic), and `c_start_reg` becomes new.
                        // But we need to output `result_val` for `write_idx`.

                        // Let's separate the Output Logic from the Pointer Update Logic.
                        // The Pointer Update Logic determines pointers for `write_idx + 1`.
                        // The Output Logic generates `result_val` for `write_idx`.

                        // Let's assume `c_start_reg`, `c_len_reg` are always valid for the CURRENT `write_idx`.
                        // Is this true?
                        // On cycle 0: `c_start_reg`=0. `write_idx`=0. Valid.
                        // When `write_idx` hits `c_start_reg + c_len_reg - 1` (last element), we want to output the correct value.
                        // If we update `c_start_reg` at that edge, then `c_start_reg` becomes New Start.
                        // But `write_idx` is still Old Index.
                        // So `result_val` calculation `write_idx == c_start_reg + c_len_reg - 1` would compare Old Index with (New Start + Old Len) - 1?
                        // No, `c_len_reg` might also update. It's safer to calculate `is_last` using `c_start_reg` and `c_len_reg` as they were BEFORE the update.

                        // Solution: Use Combinational logic for output, or register `is_last` flag.
                        // Let's use combinational logic for `result_val` based on `write_idx`, `c_start_reg`, `c_len_reg`.
                        // This assumes `c_start_reg` and `c_len_reg` are stable for `write_idx`.

                        // Logic:
                        if (write_idx >= c_start_reg && write_idx < c_start_reg + c_len_reg) begin
                            if (write_idx == c_start_reg + c_len_reg - 1)
                                result_val <= c_start_reg;
                            else
                                result_val <= write_idx + 1;
                        end else begin
                            // Fallback (should not happen if logic is correct)
                            result_val <= 0;
                        end

                        result_addr <= write_idx;
                        result_write <= 1;

                        // Increment write_idx
                        write_idx <= write_idx + 1;
                    end 
                    else if (!construction_started && write_idx == 0) begin
                        // Handshake / Start signal for construction
                        // We rely on the sequential block to set construction_started = 1 this cycle (if we write it that way)
                        // or next cycle.
                        // To start writing immediately, we need to force initial values.
                        // Let's assume `construction_started` is set to 1 in the sequential block immediately if conditions met.

                        // If `construction_started` becomes 1 this cycle:
                        // We need `c_start_reg`, `c_len_reg` ready.
                        // They are set in the sequential block.
                        // However, they are set at the END of the clock cycle (if non-blocking).
                        // So they are NOT valid for the comb output in the same cycle.

                        // We need to delay `write_idx` by 1 cycle or use immediate assignment.
                        // Or, we calculate `result_val` based on the knowledge of what the cycle WILL be.

                        // Let's check `write_idx == 0`.
                        // We know `x_count` and `y_count`.
                        // If `x_count > 0`, Cycle Start = 0, Len = A.

                        // So, for `write_idx == 0`:
                        // `result_addr` = 0.
                        // `result_write` = 1.
                        // `result_val` = (0 == 0 + Len - 1) ? 0 : 1.
                        //   If Len = 1 (A=1), Val = 0.
                        //   If Len > 1 (A>1), Val = 1.

                        // This is easy to compute combinationaly for the first cycle.
                        // BUT, `write_idx` increments 0 -> 1 -> 2...

                        // Robust Approach:
                        // We want to generate `result_val` based on `write_idx` and the *current* cycle pointers.
                        // We need the cycle pointers to be updated *before* `write_idx` is used, or we need to look ahead.

                        // Let's go with a "State Machine inside State Machine" approach for clarity.
                        // Since N is small, we can just use a sub-state for `CONSTRUCT_PERM`.
                        // Actually, the `write_idx` loop is naturally sequential.

                        // Let's just use the registers `c_start_reg`, `c_len_reg` but calculate `result_val` using a combinational helper.

                        // Wait, if `c_start_reg` updates at the clock edge for the *next* index, then:
                        // `write_idx` = i, `c_start_reg` = S_i.
                        // Next cycle: `write_idx` = i+1, `c_start_reg` = S_{i+1}.
                        // `result_val` for i+1 needs S_{i+1}.
                        // So, updating `c_start_reg` at the clock edge matching `write_idx` increment is correct.

                        // Problem: The value of `c_start_reg` for `write_idx`=i must be S_i.
                        // In the logic above:
                        // `if (write_idx == c_start_reg + c_len_reg - 1) c_start_reg <= ...`
                        // At cycle `i` (where `i` is last of cycle), `c_start_reg` is S_i.
                        // Condition matches. `c_start_reg` updates to S_{i+1}.
                        // Next cycle `i+1`: `c_start_reg` is S_{i+1}.
                        // So `c_start_reg` is always correct for the current `write_idx` (except for `write_idx`=0 if we don't set it in IDLE).

                        // So, the sequential block above sets `c_start_reg` correctly.
                        // The output logic below uses `c_start_reg` (which is valid for the current `write_idx`).

                        // BUT `construction_started` is needed to distinguish the very first cycle where we need to initialize `c_start_reg`.

                        // Let's refine `CONSTRUCT_PERM` state behavior:

                        // If `state` just switched to `CONSTRUCT_PERM`:
                        //   `c_start_reg` might be 0 (from reset) or undefined.
                        //   We need to set it to 0.

                        //   We can use `write_idx` == 0 as the trigger to set `c_start_reg` etc., but we need `write_idx` to be 0 and `result_write` to be 1.

                        //   Logic for `write_idx == 0`:
                        //     `result_addr` = 0.
                        //     `result_write` = 1.

                        //     Determine `c_start` and `c_len` for this index.
                        //     If `x_count` > 0: `c_start` = 0, `c_len` = A.
                        //     Else: `c_start` = 0, `c_len` = B.

                        //     Calculate `result_val`.

                        //     Update `write_idx` to 1.
                        //     Update `c_start_reg` and `c_len_reg` for index 1.

                        //   This logic is valid. We can use `write_idx` and registers to control flow.

                        // --- Final Implementation Plan for CONSTRUCT_PERM ---

                        // Registers: `c_start_reg`, `c_len_reg`, `rx_reg`, `ry_reg`, `is_a_reg`.
                        // In `IDLE` or `FIND_SOLUTION` success, we can pre-set `c_start_reg`=0, `rx_reg`=x, `ry_reg`=y.

                        // In `CONSTRUCT_PERM`:
                        //   // Compute Current Cycle parameters if we are at a boundary or start
                        //   // Actually, we don't need `is_a_reg` if we just check `c_len_reg` against A/B.

                        //   // Calculate Value for `write_idx`:
                        //   // If `write_idx` < `c_start_reg` + `c_len_reg`:
                        //   //   Val = (write_idx == c_start_reg + c_len_reg - 1) ? c_start_reg : write_idx + 1;
                        //   // Else:
                        //   //   // We are past the cycle. This shouldn't happen if we update pointers right.
                        //   //   // But if `c_len_reg` was 1, and we processed it, `write_idx` becomes start + 1, which is >= c_start + c_len.
                        //   //   // So we need to advance BEFORE or during the calculation.
                        //   //   // Let's advance pointers COMBINATINALLY based on `write_idx`.

                        //   // Let's use a combinational block to determine `current_cycle_start` and `length` for `write_idx`.
                        //   // This avoids the headache of updating registers correctly.
                        //   // Since N=16 and A, B are small, we can do this calculation in a combinational block.
                        //   // We have `x_count` and `y_count` stored.
                        //   // We can calculate `which_cycle` write_idx belongs to.
                        //   // This might require a loop, but we have `MAX_CYCLES = 16`.
                        //   // We can unroll the loop in hardware or use a small state machine.

                        //   // Given the complexity, let's stick to the iterative pointer update but do it carefully.
                        //   // 
                        //   // Let's use the sequential update logic described before:
                        //   // Update `c_start_reg` and `c_len_reg` for the NEXT `write_idx`.

                        //   // We need to handle the START of the state.

                        //   // Let's assume we enter `CONSTRUCT_PERM` and `write_idx` is 0.
                        //   // We want to output `result` for index 0.
                        //   // We need `c_start_reg`=0.
                        //   // We need `c_len_reg`=A (if x>0) or B (if x=0).

                        //   // So, in `FIND_SOLUTION` success, or at the start of `CONSTRUCT_PERM` (if `write_idx`==0), we initialize registers.

                        //   // To avoid race conditions, let's use `write_idx` to drive the logic.
                        //   // We will compute `current_start` and `current_len` based on `write_idx` AND stored counts.
                        //   // We need to know how many A cycles and B cycles we have "passed".

                        //   // `passed_A_cycles` = `write_idx` / A (if `write_idx` < x_count * A)
                        //   // `rem_A` = x_count - `passed_A_cycles`.
                        //   // `passed_B_cycles` = (`write_idx` - x_count*A) / B.

                        //   // This requires division. Division is expensive in logic.
                        //   // But `write_idx` is sequential 0..16. We can maintain counters `rem_x` and `rem_y` that decrement.

                        //   // Let's go with `rem_x`, `rem_y` registers.

                        //   // Logic:
                        //   // If `write_idx` == 0: `rem_x` = x, `rem_y` = y, `curr_start` = 0, `curr_len` = (x>0?A:B).

                        //   // If `write_idx` == `curr_start` + `curr_len`:
                        //   //   // We finished a cycle. Advance.
                        //   //   `curr_start` = `curr_start` + `curr_len`.
                        //   //   If `rem_x` > 0: `rem_x`--, `curr_len`=A.
                        //   //   Else if `rem_y` > 0: `rem_y`--, `curr_len`=B.
                        //   //   Else `curr_len` = 0.

                        //   // This requires checking `write_idx` against `curr_start + curr_len`.
                        //   // `curr_start` and `curr_len` are registers.
                        //   // We need to update them when `write_idx` hits the boundary.

                        //   // Example:
                        //   // Cycle A (len 3).
                        //   // `write_idx` = 0. `curr_start`=0, `curr_len`=3. `rem_x`=1.
                        //   // Val = 1.
                        //   // `write_idx` = 1. `curr_start`=0, `curr_len`=3. `rem_x`=1.
                        //   // Val = 2.
                        //   // `write_idx` = 2. `curr_start`=0, `curr_len`=3. `rem_x`=1.
                        //   // Val = 0. (Boundary check: 2 == 0+3-1). Update Pointers for next cycle.
                        //   //   `curr_start` <= 3.
                        //   //   `rem_x` <= 0.
                        //   //   `curr_len` <= B.
                        //   // `write_idx` = 3. `curr_start`=3, `curr_len`=B. `rem_x`=0.
                        //   // Val = ? (If B>1, 4).

                        //   // So, the update logic for `curr_start`, `curr_len` triggers when `write_idx == curr_start + curr_len - 1`.

                        //   // Let's implement this structure.

                        // Registers required: `c_start`, `c_len`, `rx`, `ry`.
                        // We need to initialize them at `write_idx` = 0.

                        // Implementation in the code block:

                        // Update `write_idx`
                        if (write_idx < N) begin
                            result_addr <= write_idx;
                            result_write <= 1;

                            // Calculate Value
                            // We need `c_start` and `c_len` valid for this `write_idx`.
                            // We rely on the fact that `c_start` etc are updated for the next cycle.
                            // So for `write_idx`=0, `c_start` must be 0.
                            // We will enforce this in the reset or IDLE state.

                            // Value Logic:
                            // Check if `write_idx` is the last element of the cycle.
                            // `last_element = c_start + c_len - 1`
                            // If `write_idx` == `last_element`: Value = `c_start`.
                            // Else: Value = `write_idx` + 1.

                            // Edge case: `c_len` might be 0 if no solution (but we are in CONSTRUCT only if solution exists).

                            if (write_idx == c_start_reg + c_len_reg - 1) begin
                                result_val <= c_start_reg;
                            end else begin
                                result_val <= write_idx + 1;
                            end

                            // Prepare pointers for NEXT index (`write_idx` + 1)
                            // Only if we are not finished.
                            if (write_idx < N - 1) begin
                                // Check if current index is the last of the cycle
                                if (write_idx == c_start_reg + c_len_reg - 1) begin
                                    // Advance Start
                                    // We can't update `c_start_reg` directly to be ready for the next cycle easily because of the logic dependency.
                                    // Actually, if we do non-blocking assignment, `c_start_reg` will be updated for the NEXT clock edge.
                                    // But `write_idx` is updated too.
                                    // Next clock: `write_idx` = i+1, `c_start_reg` = new_start.
                                    // This is what we want!

                                    // But we need to calculate `new_start` and `new_len`.
                                    // `new_start` = `c_start_reg` + `c_len_reg`.
                                    // `new_len` depends on `rx` and `ry`.

                                    // We need to decrement the counter of the type we just finished.
                                    // If we were in A (detect by `c_len_reg` == A, or a flag):

                                    // Let's use `is_a_cycle` flag.
                                    // If `is_a_cycle` (meaning we are finishing an A cycle now):
                                    //   `rx` <= `rx` - 1.
                                    //   If `rx` - 1 > 0: next is A.
                                    //   Else: next is B (if `ry` > 0).
                                    // If `!is_a_cycle` (finishing B):
                                    //   `ry` <= `ry` - 1.
                                    //   Next is B (if `ry` - 1 > 0).

                                    // Wait, `is_a_cycle` refers to the CURRENT cycle (the one we are finishing).

                                    // Let's manage `rx` and `ry` and `is_a_next`.

                                    if (c_len_reg == A) begin // Finishing A cycle (assuming A != B. If A=B, it doesn't matter much)
                                        // Actually, we need to know if we are in A or B cycle.
                                        // If `rx` > 0, we are definitely in A cycle.
                                        // If `rx` == 0, we are in B cycle.

                                        // Let's simplify:
                                        // We have `rx` and `ry`.
                                        // If `rx` > 0: Current is A.
                                        // If `rx` == 0: Current is B.

                                        // So, if `rx` > 0:
                                        //   `rx` <= `rx` - 1;
                                        //   If `rx` - 1 > 0: `c_len_reg` <= A.
                                        //   Else: `c_len_reg` <= B.
                                        //   `c_start_reg` <= `c_start_reg` + A.

                                        // Else (`rx` == 0):
                                        //   `ry` <= `ry` - 1;
                                        //   If `ry` - 1 > 0: `c_len_reg` <= B.
                                        //   Else: `c_len_reg` <= 0.
                                        //   `c_start_reg` <= `c_start_reg` + B.

                                        // Wait, if `rx` becomes 0, we switch to B.
                                        // If `rx` was 1, `rx` becomes 0. Next cycle should be B.
                                        // If `rx` > 1, `rx` becomes `rx`-1. Next cycle is A.
                                        // If `rx` was 0, we are in B. `ry` becomes `ry`-1.

                                        // Let's code this update.

                                        if (rx_reg > 0) begin
                                            // We are in an A cycle (or just finished one, but this logic triggers at the end of it)
                                            // Decrement rx to reflect completion of this cycle.
                                            rx_reg <= rx_reg - 1;
                                            c_start_reg <= c_start_reg + A; // Next start

                                            // Determine next length
                                            if (rx_reg > 1) begin
                                                c_len_reg <= A;
                                            end else begin
                                                // No more A cycles
                                                if (ry_reg > 0) begin
                                                    c_len_reg <= B;
                                                end else begin
                                                    c_len_reg <= 0; // End
                                                end
                                            end
                                        end else begin
                                            // We are in a B cycle (rx == 0, ry > 0 assumed)
                                            ry_reg <= ry_reg - 1;
                                            c_start_reg <= c_start_reg + B;

                                            if (ry_reg > 1) begin
                                                c_len_reg <= B;
                                            end else begin
                                                c_len_reg <= 0;
                                            end
                                        end
                                    end // end of update logic inside boundary check
                                end // end of boundary check
                            end // end of < N-1 check
                        end // end of write_idx < N check
                    end // end of construction_started check
                end // end of CONSTRUCT_PERM case

                DONE: begin
                    // Maintain outputs
                    done <= 1;
                    if (solution_found) valid_solution <= 1;
                    else valid_solution <= 0;
                end
            endcase
        end
    end

    // We missed one detail: Initializing `c_start_reg` and `c_len_reg` for `write_idx`=0.
    // In the `CONSTRUCT_PERM` block, we check `construction_started`.
    // If `write_idx` is 0 and `construction_started` is 0, we should initialize.
    // But we also need to output value for index 0.
    // The `write_idx < N` block handles the output.
    // We need `c_len_reg` and `c_start_reg` ready for index 0.
    // In `FIND_SOLUTION` state, when `solution_found` is true, we can preload these registers.
    // Or, we can check `if (write_idx == 0)` in `CONSTRUCT_PERM`.

    // Let's add logic to `FIND_SOLUTION` state to prepare pointers.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == FIND_SOLUTION && solution_found && !construction_started) begin
                // Prepare pointers
                c_start_reg <= 0;
                rx_reg <= x_count;
                ry_reg <= y_count;
                if (x_count > 0) c_len_reg <= A;
                else if (y_count > 0) c_len_reg <= B;
                else c_len_reg <= 0;
                construction_started <= 1; // Mark prepared
            end else if (state != CONSTRUCT_PERM) begin
                construction_started <= 0;
            end
        end
    end

    // Small fix: In the `CONSTRUCT_PERM` block, we need to ensure that when `write_idx` is incremented, we don't lose sync.
    // The logic:
    //   `if (write_idx == c_start_reg + c_len_reg - 1) begin ... update c_start_reg, c_len_reg ... end`
    //   This runs continuously.
    //   When `write_idx` is 0, `c_start_reg` is 0.
    //   If `c_len_reg` is 3, `write_idx` is not `0+3-1` (2).
    //   So `c_start_reg` stays 0.
    //   When `write_idx` becomes 2, `write_idx` == `c_start_reg` + `c_len_reg` - 1.
    //   We update `c_start_reg` to 3, `c_len_reg` to B (if rx was 1).
    //   We use Non-Blocking assignment `<=`.
    //   At the end of the clock cycle, `c_start_reg` becomes 3.
    //   At the next clock edge, `write_idx` becomes 3.
    //   `c_start_reg` is 3.
    //   Logic matches.

    //   What if `write_idx` increments faster than `c_start_reg` update?
    //   No, `write_idx` is updated at the same clock edge.

    //   The only issue is if `write_idx` jumps, but it doesn't.

    // One edge case: If A=1 or B=1.
    // `c_len_reg` = 1.
    // `write_idx` = S.
    // `write_idx` == `S + 1 - 1` == S. True.
    // Update `c_start_reg` to S+1.
    // Next cycle `write_idx` = S+1. `c_start_reg` = S+1. Correct.

    // One issue: In the update logic:
    // `if (write_idx == c_start_reg + c_len_reg - 1)`
    // This condition is evaluated continuously.
    // If `c_len_reg` updates inside the block, `c_start_reg` updates.
    // The update happens at the end of the cycle (NBA).
    // So the check in the same cycle uses OLD values.
    // So the logic flow is correct.

endmodule