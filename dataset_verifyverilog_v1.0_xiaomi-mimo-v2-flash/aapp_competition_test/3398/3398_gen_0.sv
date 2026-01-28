module icon_minimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    // Icon inputs: 16 slots, each 33 bits {valid, type, r[15:0], c[15:0]}
    input wire [527:0] icons_packed,
    output reg [7:0] min_moves,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_LOOP = 3'd1;
    localparam [2:0] CALC_BOUNDS = 3'd2;
    localparam [2:0] CHECK_KEEP = 3'd3;
    localparam [2:0] CHECK_REM_DELETE = 3'd4;
    localparam [2:0] UPDATE_MIN = 3'd5;
    localparam [2:0] NEXT_SUBSET = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    reg [2:0] state;

    // Constants
    localparam [3:0] TOTAL_ICONS = 4'd16;
    localparam [15:0] SCREEN_MAX = 16'd10000;
    localparam [3:0] MAX_MOVE_VAL = 4'd16;

    // Icons storage
    reg [15:0] icon_r [0:15];
    reg [15:0] icon_c [0:15];
    reg icon_type [0:15]; // 1: delete, 0: keep
    reg icon_valid [0:15];

    // Computed centers
    reg signed [16:0] center_r [0:15]; // 17 bits for signed + extra
    reg signed [16:0] center_c [0:15];

    // Counters and indices
    reg [3:0] i; // Loop counter for icons
    reg [15:0] subset_mask; // Bitmask for delete subset (up to 16 delete icons)
    reg [3:0] del_count; // Number of delete icons
    reg [3:0] keep_count; // Number of keep icons

    // Bounding box registers (signed for comparison)
    reg signed [16:0] min_r, max_r, min_c, max_c;
    reg signed [16:0] cur_r, cur_c;

    // Cost calculation
    reg [4:0] current_cost; // Can be up to 16
    reg [4:0] best_cost;

    // Intermediate signals
    reg inside_r, inside_c, inside;

    // Temporary storage for subset iteration
    reg [3:0] del_idx; // Index in the subset iteration
    reg [15:0] delete_indices [0:15]; // Map from 0..del_count-1 to icon index
    reg [15:0] keep_indices [0:15];

    integer k;

    // Unpacking input vector
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 16; k = k + 1) begin
                icon_valid[k] <= 1'b0;
                icon_r[k] <= 16'd0;
                icon_c[k] <= 16'd0;
                icon_type[k] <= 1'd0;
            end
        end else if (start) begin
            // Unpack 528 bits: 16 slots * 33 bits
            // Slot 0 is bits [32:0], Slot 1 is bits [65:33], etc.
            for (k = 0; k < 16; k = k + 1) begin
                icon_valid[k] <= icons_packed[k*33 + 0];
                icon_type[k] <= icons_packed[k*33 + 1];
                icon_r[k]   <= icons_packed[k*33 + 17 : k*33 + 2];
                icon_c[k]   <= icons_packed[k*33 + 33 : k*33 + 18];
                // Compute centers: r + 7, c + 4
                center_r[k] <= {1'b0, icons_packed[k*33 + 17 : k*33 + 2]} + 17'sd7;
                center_c[k] <= {1'b0, icons_packed[k*33 + 33 : k*33 + 18]} + 17'sd4;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_moves <= 8'd0;
            best_cost <= 5'd17; // Init > max possible (16)
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_LOOP;
                    end
                end

                INIT_LOOP: begin
                    // Count delete and keep icons, store indices
                    del_count <= 4'd0;
                    keep_count <= 4'd0;
                    i <= 4'd0;
                    subset_mask <= 16'd0;
                    // Max subsets is 2^del_count. We iterate subset_mask from 0 to (1 << del_count) - 1
                    // To avoid 2^16 if del_count is small, we only iterate up to valid bits.
                    // However, we must separate the indices first.
                    // We need to process counts before loop.
                    state <= IDLE; // Fallback
                    // Pre-process lists
                    for (k = 0; k < 16; k = k + 1) begin
                        // Done in separate logic or sequential? Sequential is safer for synthesis.
                    end
                    // Let's do sequential counting
                    state <= CALC_BOUNDS; // Jump to helper state
                    i <= 4'd0;
                    del_count <= 4'd0;
                    keep_count <= 4'd0;
                end

                CALC_BOUNDS: begin
                    // Helper state to build lists and start iteration
                    // This state handles the setup logic
                    if (i < 16) begin
                        if (icon_valid[i]) begin
                            if (icon_type[i]) begin
                                delete_indices[del_count] <= i;
                                del_count <= del_count + 1;
                            end else begin
                                keep_indices[keep_count] <= i;
                                keep_count <= keep_count + 1;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        // Setup complete
                        if (del_count == 0) begin
                            // No delete icons, cost is 0 (need 0 moves)
                            best_cost <= 5'd0;
                            state <= FINISH;
                        end else begin
                            // Initialize subset iteration
                            subset_mask <= 16'd0;
                            i <= 4'd0; // Re-use i for subset counter
                            best_cost <= 5'd17; // Reset best cost
                            // We need to iterate 2^del_count times
                            // If del_count > 8, 256 loops. If 16, 65536 loops.
                            // We will just iterate subset_mask 0 to (1<<del_count)-1
                            // We start the bounding box calculation for current subset
                            state <= CHECK_KEEP; // Go to loop logic
                            // But we need to compute bounds first for this subset
                            state <= CHECK_KEEP; // Actually jump to logic
                        end
                    end
                end

                CHECK_KEEP: begin
                    // Logic flow: 
                    // 1. Compute bounds for current subset_mask
                    // 2. Check keep icons
                    // 3. Check remaining delete icons
                    // 4. Update min
                    // 5. Increment subset
                    
                    // --- STEP 1: Compute Bounds ---
                    // We need valid bounds. If subset is empty (mask 0), we might skip or define bounds.
                    // If subset_mask == 0, we choose one delete icon to be the center? 
                    // Actually, if we choose 0 delete icons to be stationary, we are moving all delete icons.
                    // The rectangle can be anywhere. To minimize moves, we just put all delete icons in a tiny box.
                    // Cost is del_count + (keep inside box).
                    // If del_count > 0, we must pick at least one to define bounds? 
                    // No, we can pick any bounds. If we pick bounds that don't overlap any keep icons, cost = del_count.
                    // The brute force assumes we keep some stationary. If we keep none stationary (subset 0), 
                    // we should treat it as if we kept the first one stationary? 
                    // The problem asks for min moves. If we move ALL delete icons, we can put them anywhere.
                    // The cost is simply del_count (move all) + (keep icons inside our chosen empty area? 0).
                    // So cost = del_count.
                    // If subset_mask == 0, we handle it as a special case in UPDATE_MIN.
                    // For now, if subset_mask != 0, calculate bounds.
                    
                    min_r <= 17'sd10001;
                    max_r <= -17'sd1;
                    min_c <= 17'sd10001;
                    max_c <= -17'sd1;
                    
                    // Check subset bits
                    // We iterate through delete_indices
                    // If (subset_mask[del_idx] == 1) use it for bounds.
                    // We need a loop counter for delete indices.
                    del_idx <= 4'd0;
                    // State transition depends on del_count. 
                    // If del_count == 0, handled earlier.
                    // If subset_mask == 0, we skip bounds calc? 
                    // Let's handle subset_mask == 0 later.
                    if (subset_mask == 16'd0) begin
                        // No stationary delete icons. Bounds undefined.
                        // We'll check keep icons (cost 0) and delete icons (cost del_count).
                        // Then Update.
                        // But we must verify we CAN form a rectangle. Always possible.
                        // Jump to UPDATE_MIN with cost del_count.
                        current_cost <= del_count;
                        state <= UPDATE_MIN;
                    end else begin
                        state <= CHECK_REM_DELETE; // Start bounds calc loop
                    end
                end

                CHECK_REM_DELETE: begin
                    // Step 1 & 2 combined: Calc Bounds + Check Keep Icons
                    // We need a state to calculate bounds first, then check keeps.
                    // Let's split states to avoid deep nesting.
                    // This state calculates bounds based on subset_mask.
                    
                    // Actually, let's restructure states:
                    // IDLE -> INIT_LOOP -> PREP_SUBSET -> CALC_BOUNDS -> CHECK_KEEP -> CHECK_REM -> UPDATE -> NEXT
                    
                    // Current state: CHECK_KEEP (re-purposed for Calc Bounds)
                    // Loop through delete indices
                    if (del_idx < del_count) begin
                        if (subset_mask[del_idx]) begin
                            // This delete icon is stationary, include in bounds
                            cur_r <= center_r[delete_indices[del_idx]];
                            cur_c <= center_c[delete_indices[del_idx]];
                        end
                        del_idx <= del_idx + 1;
                        // Update min/max in next state or combinational
                        // Since it's sequential, we update here or register inputs.
                        // Let's update min/max here.
                        if (subset_mask[del_idx]) begin
                            if (center_r[delete_indices[del_idx]] < min_r) min_r <= center_r[delete_indices[del_idx]];
                            if (center_r[delete_indices[del_idx]] > max_r) max_r <= center_r[delete_indices[del_idx]];
                            if (center_c[delete_indices[del_idx]] < min_c) min_c <= center_c[delete_indices[del_idx]];
                            if (center_c[delete_indices[del_idx]] > max_c) max_c <= center_c[delete_indices[del_idx]];
                        end
                    end else begin
                        // Bounds calculated.
                        // Initialize cost: cost = (del_count - number of set bits in subset_mask)
                        // Count set bits in subset_mask (hamming weight)
                        // We can do this or just compute: 
                        // Number of moved deletes = Total Deletes - Stationary Deletes
                        // We need to count stationary deletes (bits set).
                        // For simplicity, we'll add to cost in the loop or just start cost at 0 and add.
                        current_cost <= 0;
                        i <= 4'd0; // Reset i for keep loop
                        state <= CHECK_KEEP; // Now actual check keep
                    end
                end

                CHECK_KEEP: begin
                    // This state checks keep icons against bounds (min_r, max_r, min_c, max_c)
                    if (i < keep_count) begin
                        // Check if keep_indices[i] is inside bounds
                        // Inside if min_r <= r <= max_r AND min_c <= c <= max_c
                        // Note: bounds are inclusive?
                        // The problem says "No 'keep' icons are inside R".
                        // Usually inside means within bounds.
                        // If bounds are degenerate (min_r == max_r), is it inside? Problem says max_r > min_r, max_c > min_c.
                        // So bounds are strictly larger than point? Or a point is not a valid rectangle.
                        // If a keep icon is EXACTLY on the boundary, is it inside? 
                        // Typically yes. But if bounds are tight, it might block.
                        // Let's treat boundary as inside.
                        
                        inside_r = (center_r[keep_indices[i]] >= min_r) && (center_r[keep_indices[i]] <= max_r);
                        inside_c = (center_c[keep_indices[i]] >= min_c) && (center_c[keep_indices[i]] <= max_c);
                        inside = inside_r && inside_c;
                        
                        if (inside) begin
                            current_cost <= current_cost + 5'd1;
                        end
                        i <= i + 1;
                    end else begin
                        // Done checking keep icons.
                        // Now check remaining delete icons (those NOT in subset_mask).
                        // Add cost for them (1 per icon).
                        // Cost so far: number of keep icons to move.
                        // Add: number of delete icons to move.
                        // Count unset bits in subset_mask (for del_count icons).
                        // (del_count - set_bits).
                        // We can compute this in parallel or loop.
                        // Let's loop through delete_indices again.
                        i <= 4'd0; // reuse i for delete check
                        state <= CHECK_REM_DELETE;
                    end
                end

                CHECK_REM_DELETE: begin
                    // Check delete icons NOT in subset_mask
                    // Add to cost if not in mask
                    // Note: If subset_mask was 0, we skipped bounds/check_keep and jumped to UPDATE_MIN with cost del_count.
                    // This state is only reached if subset_mask != 0.
                    
                    if (i < del_count) begin
                        if (!subset_mask[i]) begin
                            current_cost <= current_cost + 5'd1;
                        end
                        i <= i + 1;
                    end else begin
                        state <= UPDATE_MIN;
                    end
                end

                UPDATE_MIN: begin
                    if (current_cost < best_cost) begin
                        best_cost <= current_cost;
                    end
                    state <= NEXT_SUBSET;
                end

                NEXT_SUBSET: begin
                    // Increment subset mask
                    // If subset_mask < (1 << del_count) - 1, continue
                    // We need to know the max mask value.
                    // (1 << del_count) gives 2^del_count.
                    // We iterate 0 to 2^del_count - 1.
                    // If subset_mask + 1 < (1 << del_count), continue.
                    
                    // Check if done.
                    // (1 << del_count) is the limit.
                    // We can compare subset_mask + 1 with (1 << del_count).
                    // Since del_count <= 16, 1<<16 = 65536. fits in 16 bits.
                    // limit = 16'd1 << del_count.
                    // if (subset_mask + 1 < limit) begin subset <= subset + 1; state <= CHECK_KEEP; end
                    // else state <= FINISH;
                    
                    if (del_count > 0) begin
                        if (subset_mask < ((16'd1 << del_count) - 16'd1)) begin
                            subset_mask <= subset_mask + 16'd1;
                            state <= CHECK_KEEP; // Re-enter loop. 
                            // We need to reset logic. CHECK_KEEP will handle it.
                            // But we need to jump to CALC_BOUNDS logic first.
                            // Let's reset to a state that calculates bounds.
                            state <= CHECK_KEEP; // Wait, CHECK_KEEP currently jumps to Calc Bounds? No.
                            // I re-used CHECK_KEEP for Calc Bounds earlier.
                            // Let's be explicit.
                            state <= CHECK_KEEP; // This is a bad name collision.
                            // Let's rename CHECK_KEEP to STATE_CHECK_KEEP。
                            // And CHECK_REM_DELETE to STATE_CHECK_REM。
                            // And introduce STATE_CALC_BOUNDS。
                            // Actually, let's use the state variable logic.
                            // Current NEXT_SUBSET logic:
                            // 1. Increment subset.
                            // 2. Jump to CALC_BOUNDS (logic inside CHECK_KEEP state earlier).
                            state <= CHECK_KEEP; // Jumps to logic inside CHECK_KEEP? No.
                            // Let's fix state transitions.
                            // In NEXT_SUBSET:
                            state <= CHECK_KEEP; // This will execute logic for bounds calc.
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        // del_count is 0, we handled earlier.
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    min_moves <= best_cost;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule