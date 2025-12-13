module arrow_reconstruction(
    input clk,
    input rst_n,
    input start,
    input [15:0] K,
    input [3:0] a[15:0],
    output reg [3:0] arrows[15:0],
    output reg done
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE            = 2'b00,
        FIND_CYCLES     = 2'b01,
        COMPUTE_BACK_STEPS = 2'b10,
        DONE            = 2'b11
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg visited[15:0];            // track visited indices for cycle finding
    reg [3:0] cycle_id[15:0];     // cycle id for each index
    reg [3:0] pos_in_cycle[15:0]; // position within its cycle
    reg [4:0] cycle_len[15:0];    // length of each cycle (index by cycle id), up to 16

    reg [3:0] cur_idx;            // current starting index in FIND_CYCLES
    reg [3:0] walk_idx;           // walking index while traversing a cycle
    reg [3:0] walk_start;         // start index for current cycle

    reg in_cycle_walk;            // flag: currently walking a cycle
    reg [3:0] current_cycle_id;   // current cycle id
    reg [4:0] current_cycle_len;  // current cycle length counter

    reg error_flag;               // set if invalid permutation or cycle verification fails

    integer i;                    // loop variable for generate/for procedural

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = FIND_CYCLES;
            end
            FIND_CYCLES: begin
                // Transition to COMPUTE_BACK_STEPS when all indices processed or error
                if (error_flag)
                    next_state = DONE;
                else if (cur_idx == 4'd16 && !in_cycle_walk)
                    next_state = COMPUTE_BACK_STEPS;
            end
            COMPUTE_BACK_STEPS: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error_flag <= 1'b0;
            cur_idx <= 4'd0;
            walk_idx <= 4'd0;
            walk_start <= 4'd0;
            in_cycle_walk <= 1'b0;
            current_cycle_id <= 4'd0;
            current_cycle_len <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                visited[i] <= 1'b0;
                cycle_id[i] <= 4'd0;
                pos_in_cycle[i] <= 4'd0;
                cycle_len[i] <= 5'd0;
                arrows[i] <= 4'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        error_flag <= 1'b0;
                        cur_idx <= 4'd0;
                        walk_idx <= 4'd0;
                        walk_start <= 4'd0;
                        in_cycle_walk <= 1'b0;
                        current_cycle_id <= 4'd0;
                        current_cycle_len <= 5'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            visited[i] <= 1'b0;
                            cycle_id[i] <= 4'd0;
                            pos_in_cycle[i] <= 4'd0;
                            cycle_len[i] <= 5'd0;
                        end
                    end
                end

                FIND_CYCLES: begin
                    if (!error_flag) begin
                        if (!in_cycle_walk) begin
                            // Find next unvisited index
                            if (cur_idx < 4'd16) begin
                                if (!visited[cur_idx]) begin
                                    // Start a new cycle from cur_idx
                                    in_cycle_walk <= 1'b1;
                                    walk_start <= cur_idx;
                                    walk_idx <= cur_idx;
                                    current_cycle_len <= 5'd0;
                                end else begin
                                    // Move to next index
                                    cur_idx <= cur_idx + 4'd1;
                                end
                            end
                            // when cur_idx reaches 16 and no in_cycle_walk, next_state will move on
                        end else begin
                            // Walking current cycle one step per cycle
                            if (walk_idx > 4'd15) begin
                                // Out-of-range mapping -> invalid permutation
                                error_flag <= 1'b1;
                                in_cycle_walk <= 1'b0;
                            end else if (visited[walk_idx]) begin
                                // If we returned to start, cycle complete; otherwise invalid
                                if (walk_idx == walk_start) begin
                                    // close cycle: record length for this cycle id
                                    cycle_len[current_cycle_id] <= current_cycle_len;
                                    // prepare for next cycle search
                                    in_cycle_walk <= 1'b0;
                                    cur_idx <= cur_idx + 4'd1;
                                    current_cycle_id <= current_cycle_id + 4'd1;
                                end else begin
                                    // encountered previously visited different index inside walk => invalid
                                    error_flag <= 1'b1;
                                    in_cycle_walk <= 1'b0;
                                end
                            end else begin
                                // visit this index, assign cycle id and position
                                visited[walk_idx] <= 1'b1;
                                cycle_id[walk_idx] <= current_cycle_id;
                                pos_in_cycle[walk_idx] <= current_cycle_len[3:0];
                                // increment length
                                current_cycle_len <= current_cycle_len + 5'd1;
                                // follow permutation: next index is a[walk_idx]
                                walk_idx <= a[walk_idx];
                            end
                        end
                    end
                end

                COMPUTE_BACK_STEPS: begin
                    // Only compute if no error in cycle detection
                    if (!error_flag) begin
                        // For each cycle, compute shift = (cycle_length - (K % cycle_length)) % cycle_length
                        // Then arrows[i] = index whose pos_in_cycle == (pos_in_cycle[i] + shift) % cycle_length
                        // Implemented combinationally within this clock using the stored structures.
                        integer ci, cj, ck;
                        reg [4:0] k_mod;
                        reg [4:0] len;
                        reg [4:0] shift;
                        reg [4:0] target_pos;
                        reg [3:0] cid;
                        reg found;

                        for (ci = 0; ci < 16; ci = ci + 1) begin
                            arrows[ci] <= 4'd0;
                        end

                        for (ci = 0; ci < 16; ci = ci + 1) begin
                            cid = cycle_id[ci];
                            len = cycle_len[cid];
                            if (len == 0) begin
                                // if any element has zero-length cycle, invalid
                                error_flag <= 1'b1;
                            end else begin
                                k_mod = K % len;
                                shift = (len - k_mod) % len;
                                target_pos = (pos_in_cycle[ci] + shift) % len;
                                found = 1'b0;
                                for (cj = 0; cj < 16; cj = cj + 1) begin
                                    if (!found && cycle_id[cj] == cid) begin
                                        if (pos_in_cycle[cj] == target_pos[3:0]) begin
                                            arrows[ci] <= cj[3:0];
                                            found = 1'b1;
                                        end
                                    end
                                end
                                if (!found) begin
                                    // failed to find appropriate predecessor in cycle
                                    error_flag <= 1'b1;
                                end
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (error_flag) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            arrows[i] <= 4'd0;
                        end
                    end
                    // Wait for start deassertion per next_state logic; reset happens in IDLE
                end

                default: begin
                    // should not occur
                end
            endcase
        end
    end

endmodule