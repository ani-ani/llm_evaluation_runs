module scavenger_hunt(
    input clk,
    input rst_n,
    input start,
    input [2:0] task_idx,
    input [7:0] p_in,
    input [7:0] t_in,
    input [7:0] d_in,
    input [7:0] dist_in,
    input [3:0] dist_src,
    input [3:0] dist_dst,
    output reg [7:0] max_points,
    output reg [5:0] best_mask,
    output reg done
);
    localparam MAX_TASKS = 6;
    localparam START_NODE = 6;
    localparam END_NODE = 7;
    localparam MAX_TIME = 255;
    localparam NO_DEADLINE = 8'hFF;
    localparam NUM_LOCATIONS = 8;

    reg [7:0] dist_mem [0:NUM_LOCATIONS-1][0:NUM_LOCATIONS-1];
    reg [7:0] p_mem [0:MAX_TASKS-1];
    reg [7:0] t_mem [0:MAX_TASKS-1];
    reg [7:0] d_mem [0:MAX_TASKS-1];

    reg [3:0] current_state, next_state;
    reg [6:0] mask_cnt;
    reg [9:0] perm_cnt;
    reg [5:0] active_mask;
    reg [2:0] task_count;
    reg [9:0] perm_limit;
    reg [2:0] sub_perm_state;
    reg [2:0] k_idx_loc;
    reg [2:0] l_val;
    reg [2:0] fill_idx;
    reg [5:0] found_bits;

    reg [2:0] p_arr [0:5];

    reg [7:0] sim_time;
    reg [7:0] sim_pts;
    reg [2:0] sim_pos;
    reg [2:0] sim_prev_node;
    reg sim_valid_flag;

    integer i, j;

    // State encoding
    localparam S_IDLE = 4'd0;
    localparam S_LOAD = 4'd1;
    localparam S_ITER = 4'd2;
    localparam S_PREP = 4'd3;
    localparam S_SIM = 4'd4;
    localparam S_UPD = 4'd5;
    localparam S_DONE = 4'd6;

    // Helper combinational logic for bit count (simple LUT logic)
    wire [2:0] bit_count;
    assign bit_count = (active_mask[0]?1:0) + (active_mask[1]?1:0) + (active_mask[2]?1:0) + 
                      (active_mask[3]?1:0) + (active_mask[4]?1:0) + (active_mask[5]?1:0);

    // Factorial Limit
    wire [9:0] fact_limit;
    assign fact_limit = (bit_count <= 1) ? 0 : (bit_count == 2) ? 1 : (bit_count == 3) ? 5 : 
                        (bit_count == 4) ? 23 : (bit_count == 5) ? 119 : 719;

    // Initial Permutation Generator (Combinational)
    reg [2:0] init_p [0:5];
    always @(*) begin
        j = 0;
        for (i = 0; i < 6; i = i + 1) begin
            init_p[i] = 0;
        end
        for (i = 0; i < 6; i = i + 1) begin
            if (active_mask[i]) begin
                init_p[j] = i;
                j = j + 1;
            end
        end
    end

    // Next State Logic & Output Logic (Single Block)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            done <= 0;
            max_points <= 0;
            best_mask <= 0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    done <= 0;
                    if (start) current_state <= S_LOAD;
                end

                S_LOAD: begin
                    // Config loading is handled in a separate always block or here.
                    // We assume external setup. Move to Iteration.
                    max_points <= 0;
                    best_mask <= 0;
                    mask_cnt <= 0;
                    current_state <= S_ITER;
                end

                S_ITER: begin
                    if (mask_cnt >= 64) begin
                        current_state <= S_DONE;
                    end else begin
                        active_mask <= mask_cnt[5:0];
                        perm_limit <= fact_limit;
                        perm_cnt <= 0;
                        if (bit_count == 0) begin
                            mask_cnt <= mask_cnt + 1;
                        end else begin
                            sub_perm_state <= 0;
                            fill_idx <= 0;
                            found_bits <= 0;
                            current_state <= S_PREP;
                        end
                    end
                end

                S_PREP: begin
                    if (perm_cnt == 0) begin
                        // Build Initial Permutation
                        if (fill_idx < task_count) begin
                            // Find next bit to fill
                            // We need to find the smallest bit not in found_bits and in active_mask
                            // This takes logic. We can do it in 1 cycle if we use the combinational block `init_p`.
                            // Let's use `init_p`.
                            p_arr[0] <= init_p[0];
                            p_arr[1] <= init_p[1];
                            p_arr[2] <= init_p[2];
                            p_arr[3] <= init_p[3];
                            p_arr[4] <= init_p[4];
                            p_arr[5] <= init_p[5];
                            // Just jump to simulation
                            current_state <= S_SIM;
                            sim_pos <= 0;
                            sim_time <= 0;
                            sim_pts <= 0;
                            sim_prev_node <= START_NODE;
                            sim_valid_flag <= 1;
                        end else begin
                            // Should not happen if task_count > 0
                            current_state <= S_ITER;
                            mask_cnt <= mask_cnt + 1;
                        end
                    end else begin
                        // Next Permutation
                        case (sub_perm_state)
                            0: begin // Find k
                                k_idx_loc <= 3'd7;
                                if (task_count >= 2) begin
                                    if (p_arr[task_count-2] < p_arr[task_count-1]) k_idx_loc <= task_count-2;
                                    else if (task_count >= 3 && p_arr[task_count-3] < p_arr[task_count-2]) k_idx_loc <= task_count-3;
                                    else if (task_count >= 4 && p_arr[task_count-4] < p_arr[task_count-3]) k_idx_loc <= task_count-4;
                                    else if (task_count >= 5 && p_arr[task_count-5] < p_arr[task_count-4]) k_idx_loc <= task_count-5;
                                    else if (task_count >= 6 && p_arr[task_count-6] < p_arr[task_count-5]) k_idx_loc <= task_count-6;
                                end
                                sub_perm_state <= 1;
                            end
                            1: begin // Find l
                                l_val <= 3'd7;
                                if (k_idx_loc < 3'd7) begin
                                    if (task_count >= 1 && p_arr[task_count-1] > p_arr[k_idx_loc]) l_val <= task_count-1;
                                    else if (task_count >= 2 && p_arr[task_count-2] > p_arr[k_idx_loc] && l_val==3'd7) l_val <= task_count-2;
                                    else if (task_count >= 3 && p_arr[task_count-3] > p_arr[k_idx_loc] && l_val==3'd7) l_val <= task_count-3;
                                    else if (task_count >= 4 && p_arr[task_count-4] > p_arr[k_idx_loc] && l_val==3'd7) l_val <= task_count-4;
                                    else if (task_count >= 5 && p_arr[task_count-5] > p_arr[k_idx_loc] && l_val==3'd7) l_val <= task_count-5;
                                    else if (task_count >= 6 && p_arr[task_count-6] > p_arr[k_idx_loc] && l_val==3'd7) l_val <= task_count-6;
                                end
                                sub_perm_state <= 2;
                            end
                            2: begin // Swap
                                if (k_idx_loc < 3'd7 && l_val < 3'd7) begin
                                    p_arr[k_idx_loc] <= p_arr[l_val];
                                    p_arr[l_val] <= p_arr[k_idx_loc];
                                end
                                sub_perm_state <= 3;
                            end
                            3: begin // Reverse
                                if (k_idx_loc < 3'd7) begin
                                    // Swap pairs: (k+1, end), (k+2, end-1), ...
                                    if (k_idx_loc + 1 < task_count - 1) begin p_arr[k_idx_loc+1] <= p_arr[task_count-1]; p_arr[task_count-1] <= p_arr[k_idx_loc+1]; end
                                    if (k_idx_loc + 2 < task_count - 2) begin p_arr[k_idx_loc+2] <= p_arr[task_count-2]; p_arr[task_count-2] <= p_arr[k_idx_loc+2]; end
                                    if (k_idx_loc + 3 < task_count - 3) begin p_arr[k_idx_loc+3] <= p_arr[task_count-3]; p_arr[task_count-3] <= p_arr[k_idx_loc+3]; end
                                end
                                current_state <= S_SIM;
                                sim_pos <= 0;
                                sim_time <= 0;
                                sim_pts <= 0;
                                sim_prev_node <= START_NODE;
                                sim_valid_flag <= 1;
                                sub_perm_state <= 0;
                            end
                        endcase
                    end
                end

                S_SIM: begin
                    // Simulation Step
                    if (sim_pos < task_count && sim_valid_flag) begin
                        // Travel to task
                        // Check deadline (on accumulated time + travel)
                        // Time update: time + travel + duration
                        // Points update: points + points
                        // Note: sim_time is updated in steps.

                        // Step 1: Add Travel
                        sim_time <= sim_time + dist_mem[sim_prev_node][p_arr[sim_pos]];

                        // Check deadline (combinational check on the result of adding travel)
                        // We need to check immediately? Or next cycle?
                        // We can check next cycle, but we need to update sim_time correctly.
                        // Let's check next cycle (register deadline check).

                        // Step 2: Check Deadline (This happens in next cycle? No, let's try to do it here)
                        // We need to know if sim_time + travel > deadline.
                        // But we just updated sim_time = sim_time + travel.
                        // So we can check now.
                        if (d_mem[p_arr[sim_pos]] != NO_DEADLINE) begin
                            if (sim_time + dist_mem[sim_prev_node][p_arr[sim_pos]] > d_mem[p_arr[sim_pos]]) begin // Wait, we updated sim_time to include travel.
                                // So sim_time is now old_time + travel.
                                // Correct check: old_time + travel > deadline.
                                // We can't access old_time easily.
                                // Let's use a temp variable logic or check on the clock edge.
                                // Actually, we can check `sim_time + travel` if we haven't updated yet, but we did update.
                                // Let's reverse order: Check, then Update.
                                // But we need `sim_time` for the check.
                                // Let's change logic:
                                // Before update, check. Then update.
                                // Since this is sequential, we can't check old value easily.
                                // Let's use a combinational signal `travel_time`.
                                // But let's just check next cycle.
                                // Wait, if we update sim_time to include travel, then check, it's correct.
                                // The check is: current_sim_time > deadline.
                                // But current_sim_time is old_time + travel.
                                // So it checks (old + travel) <= deadline. Correct.
                                // Then we add duration.

                                if (sim_time > d_mem[p_arr[sim_pos]]) sim_valid_flag <= 0;
                            end
                        end

                        // Add Duration
                        sim_time <= sim_time + t_mem[p_arr[sim_pos]];

                        // Add Points
                        sim_pts <= sim_pts + p_mem[p_arr[sim_pos]];

                        // Update prev node
                        sim_prev_node <= p_arr[sim_pos];

                        // Increment pos
                        sim_pos <= sim_pos + 1;

                    end else if (sim_valid_flag) begin
                        // Finished tasks, check travel to End
                        // Check Total Time <= MAX_TIME
                        // We can do this check now.
                        // sim_time currently holds time up to last task duration.
                        // We need to add travel to end.
                        // Total = sim_time + dist_mem[sim_prev_node][END_NODE]
                        if (sim_time + dist_mem[sim_prev_node][END_NODE] > MAX_TIME) sim_valid_flag <= 0;

                        current_state <= S_UPD;
                    end else begin
                        // Invalid simulation
                        current_state <= S_UPD;
                    end
                end

                S_UPD: begin
                    // Update Max Points
                    if (sim_valid_flag) begin
                        if (sim_pts > max_points) begin
                            max_points <= sim_pts;
                            best_mask <= active_mask;
                        end else if (sim_pts == max_points) begin
                            if (active_mask < best_mask || best_mask == 0) begin
                                // Handle tie-break: smaller mask value
                                // Note: best_mask=0 is initial state with 0 points.
                                // If we find 0 points with mask 0, keep 0.
                                // If we find 0 points with mask 5, keep 0.
                                // If we find >0 points, update.
                                // If we find == max_points > 0, update if smaller mask.
                                if (best_mask == 0 && max_points == 0) begin
                                    // Keep 0 (smallest)
                                end else begin
                                    best_mask <= active_mask;
                                end
                            end
                        end
                    end

                    // Next Permutation or Next Subset
                    if (perm_cnt < perm_limit) begin
                        perm_cnt <= perm_cnt + 1;
                        current_state <= S_PREP;
                        sub_perm_state <= 0; // Next perm sequence
                    end else begin
                        mask_cnt <= mask_cnt + 1;
                        current_state <= S_ITER;
                    end
                end

                S_DONE: begin
                    done <= 1;
                    if (start) begin
                        current_state <= S_IDLE;
                    end
                end
            endcase
        end
    end

    // Config Loading
    always @(posedge clk) begin
        if (current_state == S_IDLE || current_state == S_LOAD) begin
            if (task_idx < 6) begin
                p_mem[task_idx] <= p_in;
                t_mem[task_idx] <= t_in;
                d_mem[task_idx] <= d_in;
            end
            if (dist_src < 8 && dist_dst < 8) begin
                dist_mem[dist_src][dist_dst] <= dist_in;
            end
        end
    end

endmodule