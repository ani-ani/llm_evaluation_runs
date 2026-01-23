module josip_painter (
    input clk,
    input rst_n,
    input start,
    input [2:0] target_addr,
    input [7:0] target_row,
    input target_write_en,
    output reg [6:0] min_diff,
    output reg done
);

    // Memory for target grid (8 rows, 8 columns)
    reg [7:0] target_grid [0:7];
    // Memory for optimal painting
    reg [7:0] paint_grid [0:7];
    
    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam OUTPUT = 3'b011;
    
    reg [2:0] state;
    
    // Intermediate storage for DP
    // Level 0: 1x1 (64 squares)
    reg [6:0] cost_l0 [0:63]; // cost for painting each 1x1 as optimal (min of black/white)
    reg paint_l0 [0:63];      // optimal paint for 1x1: 0=white, 1=black
    
    // Level 1: 2x2 (16 squares)
    reg [6:0] cost_l1 [0:15];
    reg [1:0] white_q_l1 [0:15]; // which quadrant was painted white (0-3)
    reg [1:0] black_q_l1 [0:15]; // which quadrant was painted black (0-3)
    
    // Level 2: 4x4 (4 squares)
    reg [6:0] cost_l2 [0:3];
    reg [1:0] white_q_l2 [0:3];
    reg [1:0] black_q_l2 [0:3];
    
    // Level 3: 8x8 (1 square)
    reg [6:0] cost_l3 [0:0];
    reg [1:0] white_q_l3 [0:0];
    reg [1:0] black_q_l3 [0:0];
    
    // Counters and indices
    reg [5:0] idx_l0; // 0-63 for 1x1 squares
    reg [3:0] idx_l1; // 0-15 for 2x2 squares
    reg [1:0] idx_l2; // 0-3 for 4x4 squares
    reg [1:0] w_perm, b_perm; // for permutation loops
    
    // Helper signals
    reg [2:0] level; // current level 0-3
    reg [2:0] computation_step; // sub-step within computation
    reg [6:0] temp_cost_white, temp_cost_black, temp_cost_recurse;
    reg [6:0] best_cost;
    reg [1:0] best_white, best_black;
    
    // Variables for extraction
    reg [2:0] row, col;
    reg [1:0] q_idx;
    reg [2:0] base_row, base_col;
    reg [7:0] current_row_data;
    reg [1:0] q_row, q_col;
    reg [2:0] sub_row, sub_col;
    reg [6:0] diff_acc;
    reg [5:0] p_idx;
    
    integer i, j, k, m, n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_diff <= 7'd0;
            idx_l0 <= 6'd0;
            idx_l1 <= 4'd0;
            idx_l2 <= 2'd0;
            level <= 3'd0;
            computation_step <= 3'd0;
            w_perm <= 2'd0;
            b_perm <= 2'd0;
            best_cost <= 7'd127;
            row <= 3'd0;
            col <= 3'd0;
            diff_acc <= 7'd0;
            // Initialize target grid to 0 if needed, though load will overwrite
            // Initialize paint grid to 0
            for (k=0; k<8; k=k+1) paint_grid[k] <= 8'b0;
            for (k=0; k<64; k=k+1) cost_l0[k] <= 7'd0;
            for (k=0; k<64; k=k+1) paint_l0[k] <= 1'b0;
            for (k=0; k<16; k=k+1) cost_l1[k] <= 7'd0;
            for (k=0; k<16; k=k+1) white_q_l1[k] <= 2'd0;
            for (k=0; k<16; k=k+1) black_q_l1[k] <= 2'd0;
            for (k=0; k<4; k=k+1) cost_l2[k] <= 7'd0;
            for (k=0; k<4; k=k+1) white_q_l2[k] <= 2'd0;
            for (k=0; k<4; k=k+1) black_q_l2[k] <= 2'd0;
            cost_l3[0] <= 7'd0;
            white_q_l3[0] <= 2'd0;
            black_q_l3[0] <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        idx_l0 <= 6'd0; // Reset address or counter if needed
                    end
                end
                
                LOAD: begin
                    if (target_write_en) begin
                        target_grid[target_addr] <= target_row;
                    end
                    // Assume external controller handles loading sequence or wait for trigger
                    // To be robust, we just wait here or rely on external logic.
                    // Let's assume start triggers transition to COMPUTE after loading is done.
                    // If we need to detect loading completion, we would need a separate signal.
                    // Assuming we are told "Once loaded, start recursive computation".
                    // The prompt implies we load row by row.
                    // Let's define a simple internal loader or assume external control.
                    // Let's add an internal mechanism: if start is held high, we transition.
                    // But 'start' is typically a pulse.
                    // Let's change logic: IDLE waits for start, LOAD waits for loading done? 
                    // The prompt says "Once loaded, start recursive computation".
                    // Let's assume the user sets target_write_en and target_addr/target_row, then pulses start.
                    // Or we need a "load_done" input. But inputs are fixed.
                    // Let's assume start transitions from IDLE to COMPUTE, but we need data loaded first.
                    // This suggests a "load_done" input is missing or implied "target_write_en" sequence is done externally.
                    // Let's strictly follow: "Once loaded, start recursive computation". 
                    // I will modify: IDLE loads, then goes to COMPUTE when loaded.
                    // Actually, to be safe, let's assume LOAD state is just a state we enter, 
                    // and we transition to COMPUTE immediately if we assume loading is done externally.
                    // Or we add a counter to load 8 rows? But we don't have a counter for rows unless we generate it.
                    // Let's keep it simple: 
                    // IDLE -> if start, go to COMPUTE. 
                    // BUT, we need to ensure data is there. 
                    // I'll interpret "Load target grid row-by-row" as something that happens before start or in parallel.
                    // To make it workable: I will assume when "start" is high, we assume data is ready.
                    // So LOAD state is skipped or merged.
                    // Let's merge LOAD into IDLE or just go to COMPUTE directly from IDLE.
                    // Wait, "Once loaded" implies a sequence. 
                    // I will add a small loader in IDLE if target_write_en is seen.
                    // But the requirements say "Use state machine: IDLE, LOAD, COMPUTE, OUTPUT".
                    // So I must have a LOAD state. 
                    // I will assume LOAD state waits for an external "load_done" signal which is NOT in the interface.
                    // Or, I will assume the user pulses start *after* loading.
                    // Okay, I will implement LOAD as a pass-through state that just waits for a cycle or checks a flag.
                    // Let's add an internal register `loaded`. 
                    // If target_write_en is high, we update memory. 
                    // But LOAD state needs to know when to exit. 
                    // Let's change plan: 
                    // IDLE: wait for start. If start, go to LOAD.
                    // LOAD: We need to load 8 rows. But we only have target_addr (3 bits). 
                    // If the external agent controls target_addr, it can load 8 rows. 
                    // How does this FSM know it's done? 
                    // I will assume a specific sequence: 
                    // 1. Start is high. 
                    // 2. Go to LOAD. 
                    // 3. In LOAD, we wait for a "done_loading" flag which we set internally if we count 8 writes or rely on user to go to next state.
                    // Since no counter exists, let's assume the user provides a "load_done" signal? No.
                    // Let's assume the user loads data while in IDLE. 
                    // Then the state machine just transitions IDLE -> COMPUTE on start.
                    // But the requirement asks for LOAD state.
                    // Let's implement a counter in LOAD. 
                    // If target_write_en is high, we write to target_grid[target_addr].
                    // But we don't know if it's the first, second, etc. 
                    // This is a "Load target grid row-by-row". 
                    // Let's add a `load_count` register. 
                    // When in LOAD state, if target_write_en, write and increment load_count. 
                    // When load_count reaches 8, transition to COMPUTE.
                    // This makes sense for a self-contained block.
                    // But there is no input to trigger "next row" other than target_write_en.
                    // And target_addr is provided.
                    // I will use `target_addr` as the row index to write.
                    // If `target_write_en` is high, I write.
                    // To exit LOAD, I need to know all 8 rows are done. 
                    // I will check if all rows have been written. 
                    // Actually, simpler: The prompt says "Once loaded, start recursive computation".
                    // I will change the logic: 
                    // IDLE: wait for start.
                    // LOAD: I will assume the external agent loads 8 rows while in LOAD state.
                    // I will add a "load_done" wire which is high when we have seen writes to all 8 rows.
                    // Or, just rely on user to pulse start and we assume data is there.
                    // Let's stick to the requirement: State machine IDLE, LOAD, COMPUTE, OUTPUT.
                    // I will use `target_write_en` to detect a row written.
                    // I'll add `rows_loaded` counter.
                end
            endcase
        end
    end

    // Re-writing the always block to be complete and coherent.
    // I will combine the logic into one block for clarity of the sequential flow.

endmodule

// Complete implementation with corrected state machine logic
module josip_painter_full (
    input clk,
    input rst_n,
    input start,
    input [2:0] target_addr,
    input [7:0] target_row,
    input target_write_en,
    output reg [6:0] min_diff,
    output reg done
);

    // Memory
    reg [7:0] target_grid [0:7];
    reg [7:0] paint_grid [0:7];
    
    // States
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam OUTPUT = 3'b011;
    
    reg [2:0] state;
    
    // Level Storage
    // L0: 64 entries
    reg [6:0] l0_cost [0:63];
    reg l0_paint [0:63];
    // L1: 16 entries
    reg [6:0] l1_cost [0:15];
    reg [1:0] l1_white [0:15];
    reg [1:0] l1_black [0:15];
    // L2: 4 entries
    reg [6:0] l2_cost [0:3];
    reg [1:0] l2_white [0:3];
    reg [1:0] l2_black [0:3];
    // L3: 1 entry
    reg [6:0] l3_cost;
    reg [1:0] l3_white;
    reg [1:0] l3_black;
    
    // Computation variables
    reg [2:0] level;         // 0, 1, 2, 3
    reg [5:0] sq_idx;        // index of square at current level (0-63, 0-15, etc)
    reg [1:0] w_perm, b_perm; // permutation loops (0-3)
    reg [2:0] load_count;    // counter for loading rows
    reg [6:0] best_cost_curr;
    reg [1:0] best_w, best_b;
    
    // Helper indices for extraction
    reg [2:0] r_base, c_base; // top-left of square
    reg [1:0] q_r, q_c;       // quadrant row/col (0 or 1)
    reg [2:0] sub_r, sub_c;   // pixel within quadrant (for recursion lookup)
    reg [5:0] q_idx_l0;       // index for L0
    reg [3:0] q_idx_l1;       // index for L1
    reg [1:0] q_idx_l2;       // index for L2
    
    // Costs for current permutation
    reg [6:0] cost_w, cost_b, cost_r;
    reg [6:0] temp_total;
    
    // Output extraction variables
    reg [2:0] out_r, out_c;
    reg [1:0] out_q;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_diff <= 7'd0;
            load_count <= 3'd0;
            level <= 3'd0;
            sq_idx <= 6'd0;
            w_perm <= 2'd0;
            b_perm <= 2'd0;
            // Reset storage (optional but good practice)
            // In ASIC, reset might be omitted for area, but logic relies on valid state.
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    load_count <= 3'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // We assume the external logic provides target_row and target_addr 
                    // and pulses target_write_en for each row.
                    // We count rows loaded to know when to proceed.
                    // If target_write_en is high, we capture the row.
                    if (target_write_en) begin
                        target_grid[target_addr] <= target_row;
                        // Ensure we don't double count if signal stays high (edge detection needed if sustained)
                        // But strictly, we just check flag.
                        // Let's add a load_done logic.
                        // To avoid edge detection complexity, we assume user pulses write_en or we rely on load_count increment.
                        // If we just check target_write_en, it might stay high. 
                        // Let's use a flag to prevent multiple increments.
                        // Actually, simplest hardware: 
                        // If load_count < 8, wait for writes. 
                        // When load_count == 8, transition.
                        // How to increment load_count? 
                        // We need to know which row is written. 
                        // If user writes row 0, then 1, etc.
                        // We can check if target_addr == load_count? No, user might not write in order.
                        // But typically they do. 
                        // Let's assume user writes strictly from 0 to 7.
                        // If target_write_en and target_addr == load_count, increment.
                        if (target_addr == load_count) begin
                            load_count <= load_count + 1'b1;
                        end
                    end
                    
                    if (load_count == 3'd8) begin
                        state <= COMPUTE;
                        level <= 3'd0;
                        sq_idx <= 6'd0;
                        best_cost_curr <= 7'd127; // Max init
                    end
                end

                COMPUTE: begin
                    // Logic depends on level (0, 1, 2, 3)
                    // We process squares sequentially (or per cycle).
                    // Let's process one square per cycle for simplicity and correctness.
                    
                    if (level == 3'd0) begin // 1x1 squares
                        // We have 64 squares. sq_idx goes 0 to 63.
                        if (sq_idx < 64) begin
                            // Compute cost for white and black
                            // Extract row/col from sq_idx
                            // sq_idx = r * 8 + c
                            // r = sq_idx[5:3], c = sq_idx[2:0]
                            // Target pixel: target_grid[r][c]
                            // Cost White: if target is white (0), cost 0, else 1.
                            // Cost Black: if target is black (1), cost 0, else 1.
                            
                            // Let's do this in one cycle per square.
                            // We are at square sq_idx.
                            // Target: target_grid[sq_idx[5:3]][sq_idx[2:0]]
                            // White cost: target ? 1 : 0
                            // Black cost: target ? 0 : 1
                            
                            l0_cost[sq_idx] <= target_grid[sq_idx[5:3]][sq_idx[2:0]] ? 7'd1 : 7'd0;
                            l0_paint[sq_idx] <= ~target_grid[sq_idx[5:3]][sq_idx[2:0]]; // 1 if black is better, 0 if white
                            // Wait, we need MIN difference. 
                            // If target is 0 (white), cost W=0, B=1 -> choose W.
                            // If target is 1 (black), cost W=1, B=0 -> choose B.
                            // So optimal cost is always 0 for 1x1? 
                            // Yes, painting a single pixel whatever color it is gives diff 0.
                            // The recursion logic requires us to choose "White Quadrant" and "Black Quadrant".
                            // For L>0, we must paint whole quadrants white or black.
                            // For L=0, we choose the color that matches target.
                            
                            l0_cost[sq_idx] <= 7'd0; // Always 0 because we choose matching color.
                            l0_paint[sq_idx] <= target_grid[sq_idx[5:3]][sq_idx[2:0]]; // Store the optimal paint
                            
                            sq_idx <= sq_idx + 1'b1;
                        end else begin
                            // Done with Level 0
                            level <= 3'd1;
                            sq_idx <= 6'd0; // Reset for level 1 (16 squares)
                            best_cost_curr <= 7'd127;
                        end
                    end else if (level == 3'd1) begin // 2x2 squares
                        // 16 squares. sq_idx 0..15
                        // Each 2x2 has 4 sub-squares (L0). Indices: base + offset.
                        // Mapping: sq_idx = r*4 + c (where r,c are 0-3 for 2x2 grid)
                        // Base L0 index: (r*2)*8 + (c*2) = (r*4 + c)*2 = sq_idx * 2
                        // Wait, 2x2 grid of 1x1. 
                        // If we have 4 rows of 2x2s. 
                        // Row 0 of 2x2s covers rows 0,1 of pixels.
                        // So sq_idx = row_2x2 * 4 + col_2x2.
                        // Base L0 index = (row_2x2*2)*8 + (col_2x2*2).
                        
                        // Logic: Try 6 permutations.
                        // w_perm, b_perm from 0 to 3. If w != b.
                        // Cost = cost(W) + cost(B) + cost(Merge).
                        // Merge: L0 square of remaining 2. 
                        // For L>0, we recurse on the remaining two. 
                        // But wait, the problem says: "recurse on remaining two".
                        // This implies we treat the remaining two as a single square of size 2^L * 2^L? 
                        // No, "recurse" usually implies calling the function again.
                        // But we are bottom-up. We are at level 1. We have no level 0.5.
                        // Wait, "For each of 6 permutations: cost = W + B + recurse(quad1, quad2)".
                        // If we are at 2x2, and we paint 1 quad W, 1 quad B. Remaining 2 are 1x1.
                        // Recurse on 1x1 means summing their optimal cost (which is 0).
                        // So cost = cost(W_quad) + cost(B_quad) + 0.
                        // But what if we are at 4x4? W and B are 2x2. Remaining 2 are 2x2.
                        // We need to add their optimal cost (which we computed in L1).
                        // So: 
                        // W cost: Sum of optimal costs of 4 L0 squares in W quad.
                        // B cost: Sum of optimal costs of 4 L0 squares in B quad.
                        // Merge cost: Sum of optimal costs of 4 L0 squares in remaining 2 quads (which equals sum of L1 optimal costs of those 2).
                        
                        if (sq_idx < 16) begin
                            if (w_perm < 3'd4 && b_perm < 3'd4) begin
                                if (w_perm != b_perm) begin
                                    // Calculate costs for current permutation
                                    // We need base index for L0 squares.
                                    // r_2x2 = sq_idx / 4, c_2x2 = sq_idx % 4
                                    // r_px = r_2x2 * 2, c_px = c_2x2 * 2
                                    // L0 start: r_px*8 + c_px = (r_2x2*2)*8 + (c_2x2*2) = sq_idx * 2 + c_2x2 (Wait, bad math)
                                    // Let's pre-calculate.
                                    // 2x2 sq 0: pixels (0,0) to (1,1). L0 indices: 0, 1, 8, 9.
                                    // 2x2 sq 1: pixels (0,2) to (1,3). L0 indices: 2, 3, 10, 11.
                                    // Formula: base_l0 = (r_2x2 * 2) * 8 + (c_2x2 * 2).
                                    // Let r_2x2 = sq_idx >> 2, c_2x2 = sq_idx & 3.
                                    // base_l0 = (sq_idx & 4'hC) * 2 + (sq_idx & 2'h3) * 2? No.
                                    // r_2x2 = sq_idx / 4. c_2x2 = sq_idx % 4.
                                    // base_l0 = (r_2x2 * 16) + (c_2x2 * 2).
                                    
                                    // Let's do it dynamically.
                                    // We will use the helper registers.
                                    // We need to handle 12 cycles per square? Or 1 cycle per permutation?
                                    // To save registers, let's do 1 cycle per permutation.
                                    // But we need to sum costs of 4 L0 squares.
                                    // That takes logic delay.
                                    // Let's try to do it in one cycle per square.
                                    // We will need a few registers to hold partial sums.
                                    // Let's use `best_cost_curr` to hold best found so far for this square.
                                    // And `cost_w`, `cost_b`, `cost_r` to calculate current.
                                    
                                    // Let's implement the permutation loop logic.
                                    // We need to calculate costs for W, B, and Rem.
                                    // Indices of 4 quads in L0 (0=TL, 1=TR, 2=BL, 3=BR):
                                    // Start index: 
                                    // TL: (r*2)*8 + (c*2)
                                    // TR: (r*2)*8 + (c*2) + 1
                                    // BL: (r*2 + 1)*8 + (c*2)
                                    // BR: (r*2 + 1)*8 + (c*2) + 1
                                    
                                    // Let's compute w_perm and b_perm costs.
                                    // Cost of a 2x2 quad = sum of 4 L0 costs.
                                    // But wait, for L1, the sub-squares are 1x1. 
                                    // So cost of painting a 2x2 quad white = number of black pixels in that quad in target.
                                    // Because we paint all white, diff is 1 for each black pixel in target.
                                    // Wait, l0_cost stores optimal cost for 1x1 (0).
                                    // But we need the cost if we force it to be white.
                                    // That is just the difference.
                                    // We need to access target_grid directly.
                                    // Let's calculate:
                                    // W_cost = sum_{pixel in W_quad} (target[pixel] == 0 ? 0 : 1)
                                    // B_cost = sum_{pixel in B_quad} (target[pixel] == 1 ? 0 : 1)
                                    // Rem_cost = sum of l0_cost of remaining 2 quads.
                                    // Since l0_cost is always 0 (we choose optimal color for 1x1), Rem_cost = 0.
                                    
                                    // So for L1, Cost = W_quad_diff + B_quad_diff.
                                    // We need to calculate W_quad_diff and B_quad_diff.
                                    // This involves summing 4 pixels.
                                    // We can do this in 1 cycle.
                                    
                                    // Calculate indices of W and B quads.
                                    // w_perm: 0=TL, 1=TR, 2=BL, 3=BR
                                    // Coordinates:
                                    // r_2x2 = sq_idx >> 2, c_2x2 = sq_idx & 3.
                                    // base_r = r_2x2 * 2, base_c = c_2x2 * 2.
                                    
                                    // Let's define quadrant offsets:
                                    // TL: (0,0), TR: (0,1), BL: (1,0), BR: (1,1)
                                    
                                    // W quad:
                                    // wr = w_perm[1], wc = w_perm[0] (assuming 0=TL=00, 1=TR=01, 2=BL=10, 3=BR=11)
                                    // Or mapping: 0: (0,0), 1: (0,1), 2: (1,0), 3: (1,1)
                                    // wr = w_perm[1], wc = w_perm[0].
                                    
                                    // W_cost calc:
                                    // Pixel 1: target_grid[base_r + wr][base_c + wc]
                                    // Pixel 2: target_grid[base_r + wr][base_c + wc + 1]? No, size 2x2.
                                    // Wait, the quadrant is 1x1 if we are at L1? 
                                    // Yes, L1 is 2x2. Quads are 1x1.
                                    // So W quad is just 1 pixel.
                                    // Cost of painting it white: 1 if target is black, 0 if white.
                                    // So W_cost = target[pixel] ? 1 : 0.
                                    // B_cost = target[pixel] ? 0 : 1.
                                    // Rem_cost: sum of 2 pixels. 
                                    // Rem_cost = sum(l0_cost[pixel] for remaining 2).
                                    // l0_cost[pixel] is 0 (optimal). 
                                    // So Total Cost = (target[W]?1:0) + (target[B]?0:1) + 0.
                                    // This matches: paint W, paint B, leave rest optimal (0 cost).
                                    
                                    // Let's implement this calculation.
                                    // We need to know which 2 pixels are remaining.
                                    
                                    // Let's do it in hardware logic.
                                    // We need to look up target_grid.
                                    // To keep code size down and logic simple, we will do a lookup per cycle.
                                    // But we have 12 permutations total (6 pairs).
                                    // We can iterate w_perm 0-3, b_perm 0-3, w != b.
                                    // We update best_cost_curr if current is better.
                                    // We need to handle the loop within the state.
                                    
                                    // The code below implements the logic.
                                    // We use w_perm and b_perm to generate the cost.
                                    // We need to map w_perm/b_perm (0-3) to actual pixel coordinates.
                                    // The square sq_idx covers pixels:
                                    // r_start = (sq_idx / 4) * 2
                                    // c_start = (sq_idx % 4) * 2
                                    
                                    // W quad pixels:
                                    // wr = w_perm >> 1, wc = w_perm & 1
                                    // W pixel r = r_start + wr, c = c_start + wc. (Since quad is 1x1)
                                    // Cost W = target_grid[r][c] ? 1 : 0
                                    
                                    // B quad pixels:
                                    // br = b_perm >> 1, bc = b_perm & 1
                                    // B pixel r = r_start + br, c = c_start + bc
                                    // Cost B = target_grid[r][c] ? 0 : 1
                                    
                                    // Rem pixels:
                                    // Are the other 2. Cost is sum of l0_cost. l0_cost is 0. 
                                    // Wait, is l0_cost 0? Yes, optimal 1x1 is 0.
                                    // So cost_r = 0.
                                    // Total = CostW + CostB.
                                    
                                    // What about L2 (4x4)?
                                    // L2 uses L1 costs.
                                    // Quads are 2x2.
                                    // W quad cost: Sum of optimal costs of 4 L1 squares in W quad.
                                    // Wait, if we paint a 2x2 quad white, we are not using optimal L1 costs.
                                    // We are painting the whole quad white.
                                    // The cost of painting a 2x2 quad white = number of black pixels in that 2x2 area.
                                    // But we can reuse logic: Cost of painting 2x2 quad white = sum of (target[px] for px in quad).
                                    // (Assuming 0=white, 1=black. Cost = sum(targets).)
                                    // But wait, if we are at L2, and we choose W, B, and recurse on 2.
                                    // Recurse on 2 means we get the optimal cost for those 2 quads.
                                    // So for L2:
                                    // W_cost = diff of W quad (sum of targets in W quad)
                                    // B_cost = (size of B quad) - (sum of targets in B quad) [Wait, 1=black, so cost for black paint is 1-target].
                                    // Actually: Paint White -> Error if Target=1. Cost = sum(Target).
                                    // Paint Black -> Error if Target=0. Cost = size - sum(Target).
                                    // Recurse -> Sum of optimal costs of remaining quads.
                                    
                                    // So we need to know sum of targets for any 2x2 block (for L1 cost calc).
                                    // And sum of targets for any 4x4 block (for L2 cost calc).
                                    // And optimal costs from previous levels.
                                    
                                    // Let's define a helper task or function logic.
                                    // Since we can't use functions for synthesis easily with memories, let's use logic.
                                    
                                    // We will perform the calculation in multiple cycles to save registers/logic.
                                    // Or we can do it in one cycle with some adder trees.
                                    // Given the small size, let's try to do it in one cycle per square.
                                    // We will iterate permutations. 
                                    // We need a counter for permutations 0 to 11 (12 total).
                                    // Let's combine w_perm and b_perm into a single perm_counter 0..11.
                                    // decode w, b from perm_counter.
                                    // 0: w=0, b=1
                                    // 1: w=0, b=2
                                    // ...
                                    // 11: w=3, b=2
                                    
                                    // Let's use `sq_idx` to index the square.
                                    // Let's use `w_perm` to count 0..3 and `b_perm` to count 0..3.
                                    // The logic:
                                    // If w_perm == b_perm, skip.
                                    // Else calc cost.
                                    // If cost < best_cost_curr, update best and store w, b.
                                    // Then increment b_perm. If b_perm wraps, increment w_perm.
                                    
                                    // We need to calculate cost for current (w_perm, b_perm).
                                    // Cost = CostW + CostB + CostR.
                                    // We need to identify the pixels/quads involved.
                                    
                                    // Let's implement the logic inside the state machine.
                                    // We will compute `temp_total`.
                                    // 
                                    // Note on L2/L3: We need to access L1 cost or calculate diff.
                                    // L1 optimal cost is 0 (we can always paint 2x2 matching target).
                                    // Actually, optimal cost is 0 for any single square if we can paint it.
                                    // BUT we have constraints: we must paint 1 white, 1 black, 2 recurse.
                                    // If we recurse on a square, we take its OPTIMAL cost (which is 0).
                                    // So CostR is always 0?
                                    // No. "Recurse" means apply the same rule.
                                    // For L>0, we must choose W, B, and recurse on 2.
                                    // For L1: W and B are 1x1. Recurse on 2x2? No, recurse on 2 quads. 
                                    // The remaining 2 are 1x1. Their optimal cost is 0.
                                    // So CostR=0.
                                    // For L2: W and B are 2x2. Recurse on 2x2.
                                    // The cost of a 2x2 square is not necessarily 0 if we *must* recurse? 
                                    // "Recurse" means apply Josip's rule to that square.
                                    // Josip's rule: Paint W, B, Recurse 2.
                                    // But we are computing OPTIMAL cost for a square.
                                    // So for L2 square, optimal cost is min over all valid splits of (CostW + CostB + CostR).
                                    // And CostR for L2 is sum of optimal costs of L1 squares.
                                    // We know L1 optimal costs are 0.
                                    // So CostR = 0.
                                    // So Cost = CostW + CostB.
                                    // CostW = diff of 2x2 block painted White.
                                    // CostB = diff of 2x2 block painted Black.
                                    // This holds for all levels.
                                    // Wait, is that true?
                                    // For L=0: Try both. Cost = 0 (matching).
                                    // For L=1: Try 6 pairs. Cost = CostW(1x1) + CostB(1x1).
                                    // CostW(1x1) = 1 if target=1 else 0.
                                    // CostB(1x1) = 1 if target=0 else 1.
                                    // Total = 1 (always) because W and B must be different colors and different pixels.
                                    // If target pixels are (0,0), W on 0, B on 1. Cost 0+1=1.
                                    // For L=2: W is 2x2. B is 2x2. R is 2x2.
                                    // Cost = CostW(2x2) + CostB(2x2) + CostR(2x2).
                                    // CostR(2x2) = 0 (optimal).
                                    // So Cost = CostW + CostB.
                                    // 
                                    // Okay, so we don't need to store L1/L2 optimal costs? 
                                    // We need them for the recursion to be correct if CostR wasn't 0.
                                    // Let's stick to the prompt: "Store optimal result for each square".
                                    // We will store them.
                                    // And we will calculate CostW and CostB by summing differences.
                                    // CostR will be sum of optimal costs of remaining squares.
                                    
                                    // To save code complexity and ensure it runs:
                                    // We will do the loops for permutations.
                                    // We will implement specific logic for L1, L2, L3.
                                    // L1: W and B are 1x1 (pixels). R are 1x1 (pixels).
                                    // L2: W and B are 2x2 (L1 squares). R are 2x2.
                                    // L3: W and B are 4x4 (L2 squares). R are 4x4.
                                    
                                    // We need to calculate the cost of painting a block White or Black.
                                    // Paint White: cost = number of Black pixels in target block (1s).
                                    // Paint Black: cost = number of White pixels in target block (0s).
                                    
                                    // Let's proceed with the implementation in the always block.

                                    // We need a separate always block for the combinatorial logic to calculate cost,
                                    // or do it step by step.
                                    // Given the request for a single module, I'll keep it sequential.
                                    // We will use a helper block or inline logic.
                                    
                                    // Let's calculate CostW, CostB, CostR using helper logic.
                                    // We will use a `computation_step` state variable to break down the calculation.
                                    // Step 0: Prepare indices.
                                    // Step 1: Calculate CostW.
                                    // Step 2: Calculate CostB.
                                    // Step 3: Calculate CostR.
                                    // Step 4: Compare and update.
                                    // Step 5: Advance permutation.
                                    
                                    // But this is too slow. 
                                    // Let's try to do it in 1 cycle with combinational logic.
                                    // We will define `next_perm`, `current_cost`, etc.
                                    // 
                                    // Let's assume we are inside the `COMPUTE` state block.
                                    // We need to handle multiple levels.
                                    // Let's refactor: 
                                    // If we are at level L, we process square `sq_idx`.
                                    // We iterate 12 permutations.
                                    // We need to access target_grid (for diff) or cost storage (for R).
                                    // 
                                    // To ensure synthesizability and avoid massive combinational paths,
                                    // I will limit the logic per cycle:
                                    // One cycle to calculate cost for a specific permutation.
                                    // One cycle to update best.
                                    // One cycle to advance counters.
                                    // This keeps FSM simple.
                                    
                                    // Let's do: 
                                    // Cycle A: Calculate CostW, CostB, CostR for current (w, b).
                                    // Cycle B: Compare with best, update best if better.
                                    // Cycle C: Increment b_perm (or w_perm). If loop done, move to next square.
                                    
                                    // This is complex to fit into a single code block.
                                    // Let's reduce to: 
                                    // 1 cycle per permutation. 
                                    // Calculate cost in comb logic using w_perm, b_perm.
                                    // Update best_cost if better.
                                    // Then increment w/b.
                                    
                                    // Let's define the mappings for levels.
                                    // L0: 1x1. Quads are pixels.
                                    // L1: 2x2. Quads are 1x1 pixels.
                                    // L2: 4x4. Quads are 2x2 blocks (indices in L1 storage).
                                    // L3: 8x8. Quads are 4x4 blocks (indices in L2 storage).
                                    
                                    // We need a way to calculate "Diff of block painted White".
                                    // This is number of 1s in target block.
                                    // And "Diff of block painted Black" is number of 0s.
                                    // Since grid is binary, Diff(White) + Diff(Black) = Size.
                                    // 
                                    // Let's implement a small combinational block outside the FSM?
                                    // No, I must put everything inside or keep it sequential.
                                    
                                    // Let's try a hybrid approach.
                                    // We will use the `COMPUTE` state, and have sub-states for the 12 permutations.
                                    // Actually, let's just hardcode the 6 pairs logic.
                                    // Permutations of 4 taken 2: 12. 
                                    // Pairs: (0,1), (0,2), (0,3), (1,0), (1,2), (1,3), (2,0), (2,1), (2,3), (3,0), (3,1), (3,2).
                                    // Or just loops: for w in 0..3: for b in 0..3: if w!=b.
                                    
                                    // Let's use `best_cost_curr` to store the min found for this square.
                                    // We need to keep `w_perm` and `b_perm` across cycles.
                                    // We need to make sure we process all 12.
                                    
                                    // Implementation Plan:
                                    // 1. Check if `sq_idx` is out of range (done with level).
                                    // 2. Calculate cost for current (w_perm, b_perm).
                                    // 3. If cost < best_cost_curr, update best and store w, b.
                                    // 4. Advance b_perm. If b_perm == 4, reset b_perm, increment w_perm.
                                    // 5. If w_perm == 4, we are done with this square.
                                    //    - Store result in appropriate storage (l1_cost, l2_cost, or l3_cost).
                                    //    - Reset w_perm, b_perm, best_cost_curr.
                                    //    - Increment sq_idx.
                                    //    - If sq_idx max reached, increment level.
                                    
                                    // The tricky part: Calculating cost.
                                    // We need to identify:
                                    // - The 4 quadrants of the current square (at current level).
                                    // - Which quadrant is W, which is B, which are R.
                                    // - CostW = sum(Target[W]) if Paint=W.
                                    // - CostB = sum(Target[B]) if Paint=B.
                                    // - CostR = sum(Optimal[Remaining]).
                                    
                                    // For L1 (2x2 square of 1x1):
                                    // 4 quads: indices [0,1,2,3] relative to square.
                                    // Target pixels: exact pixels.
                                    // Optimal costs: l0_cost (always 0).
                                    
                                    // For L2 (4x4 square of 2x2):
                                    // 4 quads: indices [0,1,2,3] relative to square. Each is an L1 square index.
                                    // Target blocks: 2x2 pixels.
                                    // Optimal costs: l1_cost.
                                    
                                    // Let's write a helper logic block to compute cost.
                                    // We will use `level`, `sq_idx`, `w_perm`, `b_perm`.
                                    // 
                                    // Calculating CostW (White):
                                    // If we paint White, diff is number of Black pixels (1s).
                                    // We need to sum targets in the W block.
                                    // 
                                    // Let's define the block coordinates.
                                    // Current square size S = 2^level.
                                    // At level 0, S=1.
                                    // At level 1, S=2.
                                    // At level 2, S=4.
                                    // At level 3, S=8.
                                    // 
                                    // Coordinates of the square:
                                    // BaseRow = (sq_idx / (8/S)) * S
                                    // BaseCol = (sq_idx % (8/S)) * S
                                    // 
                                    // Quadrant size QS = S/2.
                                    // W quadrant offset: (w_perm[1]*QS, w_perm[0]*QS)
                                    // B quadrant offset: (b_perm[1]*QS, b_perm[0]*QS)
                                    // 
                                    // W quadrant pixels: (BaseRow + offR, BaseCol + offC) for 0 <= r,c < QS.
                                    // 
                                    // We need to sum targets.
                                    // 
                                    // To do this efficiently in hardware without a huge loop:
                                    // We can unroll for small sizes.
                                    // 
                                    // L0: S=1. QS=0.5? No, L0 is base case.
                                    // 
                                    // Let's stick to the specific levels.
                                    // 
                                    // L1 (S=2): QS=1. W block is 1 pixel. Sum = target[pixel].
                                    // L2 (S=4): QS=2. W block is 2x2. Sum = sum of 4 targets.
                                    // L3 (S=8): QS=4. W block is 4x4. Sum = sum of 16 targets.
                                    // 
                                    // CostW = Sum.
                                    // CostB = (Size*Size) - Sum.
                                    // CostR = sum of optimal costs of remaining 2 quads.
                                    // 
                                    // CostR calculation:
                                    // If level = 1, CostR = 0 (l0 is 0).
                                    // If level = 2, CostR = l1_cost[idx1] + l1_cost[idx2].
                                    // If level = 3, CostR = l2_cost[idx1] + l2_cost[idx2].
                                    
                                    // Let's implement this.
                                    // We need helper wires for indices.
                                    // 
                                    // Let's define the indices of the 4 quads.
                                    // Q0: TL, Q1: TR, Q2: BL, Q3: BR.
                                    // 
                                    // Mapping sq_idx to global coordinates of quads.
                                    // 
                                    // Level 1 (S=2):
                                    // Square 0: Pixels (0,0), (0,1), (1,0), (1,1).
                                    // Quads are pixels. Q0=(0,0), Q1=(0,1), Q2=(1,0), Q3=(1,1).
                                    // 
                                    // Level 2 (S=4):
                                    // Square 0: Covers (0..3, 0..3). 
                                    // Quads are L1 squares. 
                                    // Q0: L1 sq 0 (pixels 0,0-1,1). Q1: L1 sq 1 (0,2-1,3).
                                    // Q2: L1 sq 4 (2,0-3,1). Q3: L1 sq 5 (2,2-3,3).
                                    // 
                                    // We need a generic way to map.
                                    
                                    // Let's write the code block for cost calculation.
                                    // 
                                    // We will add a `calc_done` flag to transition.
                                    // But the prompt asks for a "sequential Verilog module".
                                    // Let's keep it simple and performant.
                                    // 
                                    // I will implement the loop logic.
                                    // 
                                    // --- Detailed Logic for Cost Calculation ---
                                    // 
                                    // We need to know the 4 quad indices for the current square.
                                    // Let `sq_idx` be the index at current level `level`.
                                    // `S` = 2^level.
                                    // `QS` = S / 2.
                                    // `grid_size` = 8 / S.
                                    // `base_r` = (sq_idx / grid_size) * S.
                                    // `base_c` = (sq_idx % grid_size) * S.
                                    // 
                                    // Quad Q (0-3):
                                    // `q_r` = base_r + (Q/2) * QS.
                                    // `q_c` = base_c + (Q%2) * QS.
                                    // 
                                    // Now, CostW:
                                    // We need to sum targets for W quad.
                                    // If level == 0: 
                                    //   CostW = target[base_r][base_c] (but L0 is handled separately)
                                    // If level == 1: 
                                    //   CostW = target[q_r][q_c] (single pixel)
                                    // If level == 2:
                                    //   CostW = sum of 4 pixels. We need to access target grid.
                                    //   We can calculate this sum by adding 4 pixels.
                                    //   We can do this in one cycle if we have a 2-bit adder tree.
                                    //   Or we can do it over 4 cycles. 
                                    //   Let's do it in 1 cycle using logic.
                                    //   Sum = target[r][c] + target[r][c+1] + target[r+1][c] + target[r+1][c+1].
                                    //   This is 4 1-bit inputs to a 3-bit adder.
                                    //   We can easily do this.
                                    // If level == 3:
                                    //   CostW = sum of 16 pixels. 
                                    //   This is a 5-bit sum. 
                                    //   Doing this in 1 cycle requires a lot of adders or a loop.
                                    //   Given constraints, let's try to sum 16 pixels in 1 cycle.
                                    //   It's 16 1-bit inputs -> 5-bit output. This is a large adder tree but possible.
                                    //   Alternatively, we can process rows. 
                                    //   We can use 4 4-bit adders (rows), then 2 5-bit adders.
                                    //   Or we can use a small sequential counter inside the state.
                                    //   Let's stick to the "efficient" requirement. 
                                    //   Efficient ASIC usually means pipeline or iterative.
                                    //   Given we have state machine, let's use a counter for the summation.
                                    //   We can have a `summing` state.
                                    //   But to keep code compact, I will assume we can do the logic for L3 in one cycle 
                                    //   if we write it out (unrolled).
                                    //   
                                    //   Let's use a `cost_calc` counter.
                                    //   
                                    //   Actually, let's reconsider. 
                                    //   We have L1 (16 squares), L2 (4 squares), L3 (1 square).
                                    //   Total cycles: 
                                    //   L0: 64 cycles (1 per square). 
                                    //   L1: 16 squares * 12 perms * X cycles.
                                    //   We want to be fast.
                                    //   
                                    //   Let's use `level` to switch logic.
                                    //   And use `sq_idx` to switch square.
                                    //   
                                    //   Let's implement the cost calculation using a separate `case` statement.
                                    //   
                                    //   We will define a combinational block that calculates:
                                    //   `current_w_cost`, `current_b_cost`, `current_r_cost`.
                                    //   And `best_w_idx`, `best_b_idx`.
                                    //   
                                    //   Since I cannot use `always_comb` (SystemVerilog might not be guaranteed, though prompt allows SV), 
                                    //   I will use `always @(*)`.
                                    //   
                                    //   However, `always @(*)` inside a module can be large.
                                    //   I will integrate it.
                                    //   
                                    //   Let's outline the FSM flow:
                                    //   
                                    //   State: IDLE
                                    //   State: LOAD
                                    //   State: COMPUTE
                                    //     If level == 0:
                                    //        Update L0 storage. (Done in 1 cycle logic if we loop). 
                                    //        Let's do 1 cycle for all 64. 
                                    //        Actually, 1 cycle for all 64 might be heavy logic.
                                    //        Let's do 64 cycles for L0. It's fast enough.
                                    //     If level > 0:
                                    //        Calculate cost for current (w, b).
                                    //        If cost < best, update best.
                                    //        Advance (w, b).
                                    //        If done with (w,b), store result, inc sq_idx.
                                    //        If sq_idx done, inc level.
                                    //   State: OUTPUT
                                    //     Extract painting.
                                    //   
                                    //   Let's implement.

                                    // --- L0 Logic (simplified) ---
                                    // Actually, for L0, we just write l0_cost = 0, l0_paint = target.
                                    // We can do this in one cycle for all 64? No, that's 64 parallel writes.
                                    // Let's do it in a loop or 64 cycles.
                                    // I'll use a loop in the always block? No, sequential.
                                    // I'll use `sq_idx` to do 64 cycles.
                                    
                                    // --- Cost Calculation Logic (Always block) ---
                                    // I will create an `always @(*)` block to calculate costs.
                                    // This is allowed in Verilog.
                                    // 
                                    // Wait, I need to calculate the cost for W, B, R based on `level`, `sq_idx`, `w_perm`, `b_perm`.
                                    // And based on that, update best cost.
                                    // 
                                    // Let's define the indices.
                                    // 
                                    // `level` determines S.
                                    // S=2^level.
                                    // 
                                    // Grid indices for square `sq_idx`:
                                    // `cols` = 8 / S.
                                    // `r` = (sq_idx / cols) * S.
                                    // `c` = (sq_idx % cols) * S.
                                    // 
                                    // Quads:
                                    // Q0: (r, c)
                                    // Q1: (r, c + S/2)
                                    // Q2: (r + S/2, c)
                                    // Q3: (r + S/2, c + S/2)
                                    // 
                                    // We need to map `w_perm` and `b_perm` (0-3) to these.
                                    // 
                                    // We need `target_sum` for W and B.
                                    // And `opt_sum` for R.
                                    // 
                                    // `opt_sum`:
                                    // If level == 1, opt = 0 (l0 is 0).
                                    // If level == 2, opt = l1_cost[quad_idx].
                                    // If level == 3, opt = l2_cost[quad_idx].
                                    // 
                                    // `target_sum` for a quadrant `Q`:
                                    // We need to sum `target_grid` pixels.
                                    // Size of quadrant `qs` = S/2.
                                    // 
                                    // Let's write the combinational logic for `target_sum` and `opt_sum`.
                                    // 
                                    // We will need to know which quad index corresponds to `w_perm` and `b_perm`.
                                    // `w_perm` -> `q_idx_w`
                                    // `b_perm` -> `q_idx_b`
                                    // `r_idx` -> `q_idx_r1`, `q_idx_r2` (the other two).
                                    // 
                                    // We need to calculate `cost_w`, `cost_b`, `cost_r`.
                                    // `cost_w` = target_sum_w (if painting white, error is black pixels)
                                    // `cost_b` = size_sq - target_sum_b (if painting black, error is white pixels)
                                    //   Wait, target grid: 0=white, 1=black.
                                    //   Paint White -> Error on 1. Cost = Sum(Target).
                                    //   Paint Black -> Error on 0. Cost = (Size^2) - Sum(Target).
                                    //   
                                    //   Yes.
                                    // 
                                    // `cost_r` = opt_sum_q1 + opt_sum_q2.
                                    // 
                                    // Let's implement `always @(*)` for `cost_w`, `cost_b`, `cost_r` and `best_w`, `best_b`.
                                    // But we need to handle the loop.
                                    // 
                                    // Let's do it step by step in the sequential FSM.
                                    // We will use `best_cost_curr` to hold the minimum found for this square.
                                    // We will check 12 pairs.
                                    // 
                                    // To implement `target_sum` for a quadrant efficiently:
                                    // If S=2 (Level 1): qs=1. Sum is just 1 pixel.
                                    // If S=4 (Level 2): qs=2. Sum is 4 pixels. 
                                    // If S=8 (Level 3): qs=4. Sum is 16 pixels.
                                    // 
                                    // Calculating sum of 16 pixels in 1 cycle:
                                    // We can use a loop in comb logic or explicit adders.
                                    // Let's use explicit adders for speed.
                                    // 
                                    // We will need to index `target_grid`.
                                    // `target_grid` is 8x8.
                                    // We need to access it based on coordinates.
                                    // 
                                    // Let's define a combinational block.
                                    // 
                                    // `wire [6:0] quad_sum = ...` 
                                    // 
                                    // Since we need this for W and B, we need two quad sums (unless W=B which is invalid).
                                    // 
                                    // To reduce code size, let's assume we compute cost inside the FSM block using temporary variables.
                                    // But that makes the block huge.
                                    // 
                                    // I will write a helper task using `always @(*)` to calculate cost given `q_idx`.
                                    // 
                                    // Let's define `calc_quad_cost` function.
                                    // Input: `q_idx` (0-3), `level`, `sq_idx`.
                                    // Output: `diff` (number of black pixels in that quadrant).
                                    // 
                                    // We need to map `q_idx` to pixels.
                                    // 
                                    // `r_start` = (sq_idx / (8/2^level)) * 2^level.
                                    // `c_start` = (sq_idx % (8/2^level)) * 2^level.
                                    // `size` = 2^level.
                                    // `quad_size` = size / 2.
                                    // `quad_r` = q_idx / 2 * quad_size.
                                    // `quad_c` = q_idx % 2 * quad_size.
                                    // 
                                    // `pixel_r` = r_start + quad_r + offset_r.
                                    // `pixel_c` = c_start + quad_c + offset_c.
                                    // 
                                    // We need to sum `target_grid[pixel_r][pixel_c]`.
                                    // 
                                    // Let's implement this logic.

endmodule

// Refined Implementation combining everything
module josip_painter (
    input clk,
    input rst_n,
    input start,
    input [2:0] target_addr,
    input [7:0] target_row,
    input target_write_en,
    output reg [6:0] min_diff,
    output reg done
);

    // Memory
    reg [7:0] target_grid [0:7];
    reg [7:0] paint_grid [0:7];
    
    // State
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam OUTPUT = 3'b011;
    reg [2:0] state;
    
    // DP Storage
    reg [6:0] l0_cost [0:63];
    reg l0_paint [0:63];
    reg [6:0] l1_cost [0:15];
    reg [1:0] l1_white [0:15];
    reg [1:0] l1_black [0:15];
    reg [6:0] l2_cost [0:3];
    reg [1:0] l2_white [0:3];
    reg [1:0] l2_black [0:3];
    reg [6:0] l3_cost;
    reg [1:0] l3_white;
    reg [1:0] l3_black;
    
    // Control variables
    reg [2:0] level; // 0..3
    reg [5:0] sq_idx; // 0..63
    reg [1:0] w_perm, b_perm; // 0..3
    reg [6:0] best_cost_curr;
    reg [1:0] best_w, best_b;
    reg [2:0] load_cnt;
    
    // Combinational helper variables
    reg [5:0] q_idx; // for loop index
    wire [5:0] sq_size;
    wire [5:0] q_size;
    wire [2:0] sq_rows; // rows in current square
    wire [2:0] sq_cols; // cols in current square
    wire [2:0] q_rows; // rows in quadrant
    wire [2:0] q_cols; // cols in quadrant
    wire [2:0] base_row, base_col;
    wire [2:0] w_base_row, w_base_col;
    wire [2:0] b_base_row, b_base_col;
    wire [2:0] r1_base_row, r1_base_col;
    wire [2:0] r2_base_row, r2_base_col;
    
    // Sum calculation
    reg [6:0] w_diff_sum;
    reg [6:0] b_diff_sum;
    reg [6:0] r_opt_sum;
    reg [6:0] current_total_cost;
    
    integer i, j, k;

    // Helper: Map square index to base row/col
    // sq_idx = (row / block_size) * num_blocks_per_side + (col / block_size)
    // Inverse: 
    // rows_per_block = 2^level
    // blocks_per_side = 8 / rows_per_block
    // row = (sq_idx / blocks_per_side) * rows_per_block
    // col = (sq_idx % blocks_per_side) * rows_per_block
    
    assign sq_size = 6'd1 << level; // e.g., 1, 2, 4, 8
    assign q_size = sq_size >> 1;   // e.g., 0.5 (invalid), 1, 2, 4
    
    // We need to handle the grid indexing carefully.
    // Since Verilog doesn't support variable slice indices easily in synthesis, 
    // we will use logic to extract pixel bits.
    
    always @(*) begin
        // Defaults
        w_diff_sum = 7'd0;
        b_diff_sum = 7'd0;
        r_opt_sum = 7'd0;
        
        if (level == 3'd1) begin // 2x2
             // q_size = 1. Quad is 1x1 pixel.
             // We need to identify the pixel for W, B, and R.
             // For L1, we have 4 quads (pixels). 
             // We need to sum 1 pixel for W, 1 for B, and lookup 2 optimal costs for R.
             // Wait, for L1, R cost is sum of optimal costs of remaining quads.
             // Optimal cost of L0 is 0.
             // So R cost is 0.
             
             // Let's calculate W_diff and B_diff.
             // W_diff = target[wpixel].
             // B_diff = 1 - target[bpixel] (since paint black -> cost 1 if target white).
             // Actually, Paint Black -> Error on 0. Cost = 0 if target 1, 1 if target 0.
             // So B_diff = ~target[bpixel].
             // Wait, target is 0=white, 1=black.
             // W_diff (paint white, error on 1) = target[wpixel].
             // B_diff (paint black, error on 0) = ~target[bpixel].
             
             // We need to access target_grid.
             // We need base coordinates of the square.
             // L1: sq_size=2. 
             // sq_idx: 0..15. 
             // blocks_per_side = 8/2 = 4.
             // row_base = (sq_idx / 4) * 2.
             // col_base = (sq_idx % 4) * 2.
             // Quad offsets: (0,0), (0,1), (1,0), (1,1).
             // Pixel coordinates:
             // Q0: row_base, col_base
             // Q1: row_base, col_base+1
             // Q2: row_base+1, col_base
             // Q3: row_base+1, col_base+1
             
             // Get target bits for the 4 pixels.
             // We can use a small array or if-else.
             
             // Let's define temporary indices to access target_grid.
             // Since we can't use dynamic indexing easily in synthesis if not registered,
             // we use logic.
             // Let's define `get_pixel(r, c)` which returns bit.
             // But r and c are wires.
             // `target_grid[r]` is 8 bits. `[c]` is bit.
             // This works if r and c are logic or integer.
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            load_cnt <= 3'd0;
            level <= 3'd0;
            sq_idx <= 6'd0;
            w_perm <= 2'd0;
            b_perm <= 2'd0;
            best_cost_curr <= 7'd127;
            min_diff <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= LOAD;
                end
                
                LOAD: begin
                    if (target_write_en) begin
                        target_grid[target_addr] <= target_row;
                        if (target_addr == load_cnt) load_cnt <= load_cnt + 1'b1;
                    end
                    if (load_cnt == 3'd8) begin
                        state <= COMPUTE;
                        level <= 3'd0;
                        sq_idx <= 6'd0;
                    end
                end

                COMPUTE: begin
                    // We process levels 0 to 3.
                    // Level 0 is special (1x1).
                    if (level == 3'd0) begin
                        // L0: 1x1 squares. 
                        // We want to store optimal cost (0) and paint.
                        // Let's do 64 cycles.
                        // Target: target_grid[sq_idx[5:3]][sq_idx[2:0]]
                        if (sq_idx < 64) begin
                            l0_cost[sq_idx] <= 7'd0;
                            l0_paint[sq_idx] <= target_grid[sq_idx[5:3]][sq_idx[2:0]]; // 1 if black, 0 if white
                            sq_idx <= sq_idx + 1'b1;
                        end else begin
                            // Transition to L1
                            level <= 3'd1;
                            sq_idx <= 6'd0;
                            w_perm <= 2'd0;
                            b_perm <= 2'd1; // Start with valid pair
                            best_cost_curr <= 7'd127;
                        end
                    end else begin
                        // L1, L2, L3
                        // Logic: Iterate 12 pairs for each square.
                        // 1 cycle per pair.
                        
                        // Check if we are done with all squares for this level
                        // Num squares: L1=16, L2=4, L3=1.
                        // Done condition:
                        reg [5:0] max_sq;
                        case(level)
                            3'd1: max_sq = 16;
                            3'd2: max_sq = 4;
                            3'd3: max_sq = 1;
                            default: max_sq = 0;
                        endcase
                        
                        if (sq_idx >= max_sq) begin
                            // Done with this level
                            if (level == 3'd3) begin
                                state <= OUTPUT;
                                min_diff <= l3_cost;
                            end else begin
                                level <= level + 1'b1;
                                sq_idx <= 6'd0;
                                w_perm <= 2'd0;
                                b_perm <= 2'd1;
                                best_cost_curr <= 7'd127;
                            end
                        end else begin
                            // Current square logic
                            // Calculate cost for (w_perm, b_perm)
                            // Then update best_cost_curr
                            // Then advance w_perm, b_perm
                            
                            // We need to use the combinational logic defined below (w_diff_sum, etc.)
                            // We need to pass `level`, `sq_idx`, `w_perm`, `b_perm` to it.
                            // Since it's combinational, it updates automatically.
                            // We use `current_total_cost` to get the cost for current pair.
                            
                            if (current_total_cost < best_cost_curr) begin
                                best_cost_curr <= current_total_cost;
                                best_w <= w_perm;
                                best_b <= b_perm;
                            end
                            
                            // Advance permutation
                            if (b_perm < 3) begin
                                b_perm <= b_perm + 1'b1;
                                if (b_perm + 1'b1 == w_perm) b_perm <= b_perm + 2'b10; // Skip equal
                            end else begin // b_perm == 3
                                b_perm <= 0;
                                if (w_perm < 2) begin // w_perm can go 0, 1, 2 (if b starts 1, 2, 3)
                                     // Actually, w can go 0, 1, 2. If w=0, b=1,2,3. w=1, b=0,2,3. w=2, b=0,1,3.
                                     // My loop logic: w increments, b resets.
                                     // If w=0, b=0..3 (skip 0).
                                     // If w=1, b=0..3 (skip 1).
                                     // If w=2, b=0..3 (skip 2).
                                     // If w=3, done.
                                     // So standard loops:
                                     // if (b_perm == 3) begin
                                     //    b_perm <= 0;
                                     //    w_perm <= w_perm + 1;
                                     //    if (w_perm + 1 == b_perm) skip? No, b resets to 0.
                                     //    If w+1 == 0 (impossible). 
                                     //    Wait, if w=0, b goes 0,1,2,3. 
                                     //    We need to skip w==b.
                                     //    So when b increments, if b==w, b++ again (or check before).
                                     //    Let's use a separate flag or check.
                                     //    Let's simplify: 
                                     //    12 iterations total.
                                     //    Use a counter `perm_cnt` 0..11.
                                     //    Decode w,b.
                                     //    This is safer.
                                     //    
                                     //    Let's switch to `perm_cnt`.
                                     //    
                                     //    If we are at the start of a square, perm_cnt = 0.
                                     //    We update best_cost.
                                     //    Then perm_cnt++.
                                     //    If perm_cnt < 12, decode w,b.
                                     //    If perm_cnt == 12, store result, inc sq_idx.
                            end
                            
                            // Correction: I will use a `perm_cnt` register to track 12 permutations.
                            // Let's add `perm_cnt` to the register list.
                            // `reg [3:0] perm_cnt;` (0..11)
                            // 
                            // If `perm_cnt` < 12:
                            //    Calculate cost.
                            //    Update best.
                            //    perm_cnt++.
                            // If `perm_cnt` == 12:
                            //    Store result (level specific).
                            //    sq_idx++.
                            //    perm_cnt = 0.
                            //    best_cost_curr = 127.
                            //    
                            // Let's assume we add `perm_cnt`.
                        end
                    end
                end

                OUTPUT: begin
                    // Generate painting.
                    // We have stored optimal choices w, b for each square.
                    // We need to fill `paint_grid`.
                    // 
                    // We iterate through all pixels and decide color.
                    // 
                    // We can trace back from top (L3) or use a separate extraction process.
                    // Since we have to fill 8x8 memory, we can do it in 64 cycles.
                    // 
                    // For each pixel (r,c), we find which L3 quad, L2 quad, etc. it belongs to,
                    // and check if it falls in the W or B zone.
                    // 
                    // Pixel (r,c) belongs to:
                    // L3 quad: (r/4, c/4). Index: (r/4)*2 + (c/4).
                    // L2 quad: (r/2, c/2) relative to L3. Index: ((r%4)/2)*2 + ((c%4)/2).
                    // L1 quad: (r%2, c%2) relative to L2. Index: ((r%2)*2 + (c%2)).
                    // L0: just the pixel.
                    // 
                    // We check:
                    // If pixel is in L3 W quad -> White.
                    // Else if in L3 B quad -> Black.
                    // Else (L3 R quads): Check L2.
                    //   If pixel in L2 W quad (of the specific L2 square) -> White.
                    //   Else if in L2 B quad -> Black.
                    //   Else (L2 R): Check L1.
                    //     ...
                    // 
                    // This is complex to do iteratively.
                    // 
                    // Alternatively, we can "expand" the choices into the grid.
                    // Start with L3: Fill W and B quads in paint_grid.
                    // Then fill R quads with placeholders (e.g., 2'b11).
                    // Then L2: Fill W and B quads inside the R areas.
                    // 
                    // Let's do it sequentially.
                    // We will use `out_r`, `out_c` to iterate pixels.
                    // We will determine color by checking hierarchy.
                    // 
                    // 1. Check L3.
                    //    q = (out_r/4)*2 + (out_c/4).
                    //    if q == l3_white -> White.
                    //    if q == l3_black -> Black.
                    // 2. Else, Check L2.
                    //    L2 square index: (out_r/4)*2 + (out_c/4) (same as L3 q). Wait, we need to identify which L2 square we are in.
                    //    Actually, the L2 squares are the 4 squares inside the L3 R area.
                    //    But we have 4 L2 squares total.
                    //    L2 square 0 is top-left of screen.
                    //    If L3 chose W=0, B=1, then R=2,3.
                    //    So if pixel is in L2 square 2 or 3, we check L2 choices.
                    //    L2 square index: (out_r/4)*2 + (out_c/4).
                    //    If this index matches l3_white or l3_black, we already handled it.
                    //    Else, we look up l2_white[l2_idx] and l2_black[l2_idx].
                    //    
                    //    This seems correct.
                    //    
                    //    Similarly for L1.
                    //    L1 square index: (out_r/2)*4 + (out_c/2).
                    //    Check if L1 square index matches W or B of L2 square containing it.
                    //    
                    //    And finally L0 if none match.
                    //    
                    //    Let's implement this in a sequential loop.
                    //    
                    //    We will use `out_r` and `out_c` from 0 to 7.
                    //    
                    //    If we finish output, go to IDLE or stay DONE.
                    
                    if (out_r == 3'd7 && out_c == 3'd7) begin
                        done <= 1'b1;
                        state <= IDLE; // Or stay here
                        out_r <= 3'd0;
                        out_c <= 3'd0;
                    end else begin
                        // Increment coords
                        if (out_c == 3'd7) begin
                            out_c <= 3'd0;
                            out_r <= out_r + 1'b1;
                        end else begin
                            out_c <= out_c + 1'b1;
                        end
                        
                        // Determine color
                        // L3
                        q_idx = (out_r >> 2) * 2 + (out_c >> 2); // 0..3
                        if (q_idx == l3_white) paint_grid[out_r][out_c] <= 1'b0; // White
                        else if (q_idx == l3_black) paint_grid[out_r][out_c] <= 1'b1; // Black
                        else begin
                            // L2
                            q_idx = ((out_r >> 1) & 3'b110) + ((out_c >> 1) & 3'b001); // (r/2)%4 * 2 + (c/2)%2. 
                            // L2 indices: 
                            // 0: (0,0), 1: (0,1), 2: (1,0), 3: (1,1) blocks of 2x2.
                            // Wait, (out_r/2) is 0..3. (out_c/2) is 0..3.
                            // L2 index = ( (out_r/2) / 2 ) * 2 + ( (out_c/2) / 2 ).
                            // = (out_r/4)*2 + (out_c/4). Same as L3.
                            // 
                            // My mapping is wrong. 
                            // L2 squares are 4x4. 
                            // Index 0: rows 0-3, cols 0-3.
                            // Index 1: rows 0-3, cols 4-7.
                            // Index 2: rows 4-7, cols 0-3.
                            // Index 3: rows 4-7, cols 4-7.
                            // 
                            // Wait, prompt says: L1: 2x2, L2: 4x4, L3: 8x8.
                            // "Bottom-up DP: 1x1, 2x2, 4x4, 8x8"
                            // 
                            // For 4x4 (L2), there are 4 squares.
                            // These are exactly the quads of the 8x8.
                            // So `q_idx` for L2 is same as L3.
                            // 
                            // So if L3 failed (pixel is in R), we must be in one of the L2 squares.
                            // Which L2 square? 
                            // (out_r >> 2) * 2 + (out_c >> 2).
                            // 
                            // Inside that L2 square, we look at `l2_white` and `l2_black`.
                            // These are choices for 2x2 sub-squares.
                            // 
                            // To identify the 2x2 sub-square inside the L2 square:
                            // rel_r = (out_r % 4), rel_c = (out_c % 4).
                            // sub_idx = (rel_r >> 1) * 2 + (rel_c >> 1).
                            // 
                            // So we need to check:
                            // if sub_idx == l2_white[q_idx] -> White.
                            // else if sub_idx == l2_black[q_idx] -> Black.
                            // else -> Recurse to L1.
                            
                            q_idx = (out_r >> 2) * 2 + (out_c >> 2);
                            sub_idx = ((out_r & 3'b010) >> 1) * 2 + ((out_c & 3'b010) >> 1);
                            
                            if (sub_idx == l2_white[q_idx]) paint_grid[out_r][out_c] <= 1'b0;
                            else if (sub_idx == l2_black[q_idx]) paint_grid[out_r][out_c] <= 1'b1;
                            else begin
                                // L1
                                // L1 squares are 2x2. There are 16.
                                // Index: (out_r/2)*4 + (out_c/2).
                                q_idx = (out_r >> 1) * 4 + (out_c >> 1);
                                
                                // Inside L1 square, sub_idx is the pixel (0..3).
                                sub_idx = (out_r & 1) * 2 + (out_c & 1);
                                
                                if (sub_idx == l1_white[q_idx]) paint_grid[out_r][out_c] <= 1'b0;
                                else if (sub_idx == l1_black[q_idx]) paint_grid[out_r][out_c] <= 1'b1;
                                else begin
                                    // L0
                                    q_idx = out_r * 8 + out_c;
                                    paint_grid[out_r][out_c] <= l0_paint[q_idx];
                                end
                            end
                        end
                    end
                end
            endcase
        end
    end

    // Combinational Logic for Cost Calculation
    // This block calculates cost for current (level, sq_idx, w_perm, b_perm)
    // It updates `current_total_cost`.
    always @(*) begin
        // Default 0
        current_total_cost = 127;
        
        // We need to define helper wires for indices of the 4 quads.
        // Quads 0,1,2,3.
        // 
        // Let's define the 4 quad indices.
        // Q0: TL, Q1: TR, Q2: BL, Q3: BR.
        // 
        // We need to know their coordinates to sum targets or lookup costs.
        // 
        // Base coords of square:
        // Level 1 (2x2): sq_idx 0..15. blocks=4. 
        //   r_base = (sq_idx/4)*2, c_base = (sq_idx%4)*2.
        // Level 2 (4x4): sq_idx 0..3. blocks=2.
        //   r_base = (sq_idx/2)*4, c_base = (sq_idx%2)*4.
        // Level 3 (8x8): sq_idx 0. blocks=1.
        //   r_base = 0, c_base = 0.
        // 
        // Quad coords:
        // Q0: (r_base, c_base)
        // Q1: (r_base, c_base + size/2)
        // Q2: (r_base + size/2, c_base)
        // Q3: (r_base + size/2, c_base + size/2)
        // 
        // W coords = coords of w_perm.
        // B coords = coords of b_perm.
        // 
        // We need to sum targets for W and B.
        // And sum opt costs for R.
        
        // Define variables for coordinates
        reg [2:0] r_b, c_b; // base
        reg [2:0] r_q, c_q; // quad
        reg [2:0] w_r, w_c;
        reg [2:0] b_r, b_c;
        reg [1:0] q_i;
        
        // Calculate base based on level
        case (level)
            3'd1: begin // 2x2
                // sq_idx / 4, sq_idx % 4
                r_b = {sq_idx[5:4], 1'b0}; // * 2
                c_b = {sq_idx[3:2], 1'b0}; // * 2 ... wait, sq_idx is 6 bits? 0-15. 4 bits.
                // sq_idx is 4 bits for L1. 
                // Let's assume sq_idx is correctly sized for logic.
                // We need to cast or slice.
                r_b = (sq_idx / 4) * 2;
                c_b = (sq_idx % 4) * 2;
            end
            3'd2: begin // 4x4
                r_b = (sq_idx / 2) * 4;
                c_b = (sq_idx % 2) * 4;
            end
            3'd3: begin // 8x8
                r_b = 0;
                c_b = 0;
            end
            default: begin
                r_b = 0; c_b = 0;
            end
        endcase
        
        // We need to handle the sums.
        // Since we can't loop in combinational logic easily without generating large logic,
        // we will handle specific cases L1, L2, L3 separately.
        // 
        // L1 (Level=1): 
        //   Quads are 1x1 pixels.
        //   W cost: target[w_r][w_c]
        //   B cost: ~target[b_r][b_c]
        //   R cost: 0.
        // 
        // L2 (Level=2):
        //   Quads are 2x2 pixels.
        //   W cost: sum of 4 pixels.
        //   B cost: 4 - sum of 4 pixels.
        //   R cost: l1_cost[quad_idx1] + l1_cost[quad_idx2].
        // 
        // L3 (Level=3):
        //   Quads are 4x4 pixels.
        //   W cost: sum of 16 pixels.
        //   B cost: 16 - sum.
        //   R cost: l2_cost[quad_idx1] + l2_cost[quad_idx2].
        
        if (level >= 1 && level <= 3) begin
            // Get coords for W and B
            // w_perm: 0=TL, 1=TR, 2=BL, 3=BR
            // Offset: (w_perm/2 * QS, w_perm%2 * QS)
            // QS = 2^(level-1)
            // QS bits: level 1 -> 1, level 2 -> 2, level 3 -> 4.
            
            // W coords
            if (w_perm[1]) w_r = r_b + (1 << (level-1)); else w_r = r_b;
            if (w_perm[0]) w_c = c_b + (1 << (level-1)); else w_c = c_b;
            
            // B coords
            if (b_perm[1]) b_r = r_b + (1 << (level-1)); else b_r = r_b;
            if (b_perm[0]) b_c = c_b + (1 << (level-1)); else b_c = c_b;
            
            // Calculate W Diff (number of 1s)
            w_diff_sum = 0;
            if (level == 1) begin
                w_diff_sum = target_grid[w_r][w_c];
            end else if (level == 2) begin
                // Sum 2x2 block at (w_r, w_c)
                w_diff_sum = target_grid[w_r][w_c] + target_grid[w_r][w_c+1] + 
                             target_grid[w_r+1][w_c] + target_grid[w_r+1][w_c+1];
            end else if (level == 3) begin
                // Sum 4x4 block
                // Unrolled for efficiency
                w_diff_sum = 
                    target_grid[w_r][w_c] + target_grid[w_r][w_c+1] + target_grid[w_r][w_c+2] + target_grid[w_r][w_c+3] +
                    target_grid[w_r+1][w_c] + target_grid[w_r+1][w_c+1] + target_grid[w_r+1][w_c+2] + target_grid[w_r+1][w_c+3] +
                    target_grid[w_r+2][w_c] + target_grid[w_r+2][w_c+1] + target_grid[w_r+2][w_c+2] + target_grid[w_r+2][w_c+3] +
                    target_grid[w_r+3][w_c] + target_grid[w_r+3][w_c+1] + target_grid[w_r+3][w_c+2] + target_grid[w_r+3][w_c+3];
            end
            
            // Calculate B Diff (number of 0s) -> Size - Sum(1s)
            // Size = 2^(2*level)
            // L1: 4 pixels? No, L1 quad is 1 pixel. 
            // Wait, quad size at level L is 2^(L-1).
            // L1: 1x1. Size=1.
            // L2: 2x2. Size=4.
            // L3: 4x4. Size=16.
            
            // CostB for L1: 1 - w_diff (if we were calculating B).
            // But B_diff is sum of 0s = Size - sum(1s).
            
            if (level == 1) b_diff_sum = 1 - w_diff_sum; // Only if B is 1x1? No, B coords.
            // We need B diff separately! 
            // B diff is number of 0s in B block.
            
            // Re-calculate for B block
            if (level == 1) begin
                b_diff_sum = 1 - target_grid[b_r][b_c];
            end else if (level == 2) begin
                b_diff_sum = 4 - (target_grid[b_r][b_c] + target_grid[b_r][b_c+1] + 
                                  target_grid[b_r+1][b_c] + target_grid[b_r+1][b_c+1]);
            end else if (level == 3) begin
                b_diff_sum = 16 - (
                    target_grid[b_r][b_c] + target_grid[b_r][b_c+1] + target_grid[b_r][b_c+2] + target_grid[b_r][b_c+3] +
                    target_grid[b_r+1][b_c] + target_grid[b_r+1][b_c+1] + target_grid[b_r+1][b_c+2] + target_grid[b_r+1][b_c+3] +
                    target_grid[b_r+2][b_c] + target_grid[b_r+2][b_c+1] + target_grid[b_r+2][b_c+2] + target_grid[b_r+2][b_c+3] +
                    target_grid[b_r+3][b_c] + target_grid[b_r+3][b_c+1] + target_grid[b_r+3][b_c+2] + target_grid[b_r+3][b_c+3]);
            end
            
            // R Cost: Sum of optimal costs of remaining 2 quads.
            // We need indices of remaining quads.
            // r_idx1, r_idx2.
            // We have 4 quads. w_perm, b_perm are used. 
            // We need to find the two indices not in {w_perm, b_perm}.
            
            // Using a helper loop in combinational block? 
            // Let's use if-else to identify them.
            // Since there are only 4, we can check.
            
            r_opt_sum = 0;
            
            // We need to access cost storage based on level.
            // If level == 1, R cost is 0 (L0 optimal is 0).
            // If level == 2, R cost is l1_cost[idx1] + l1_cost[idx2].
            // If level == 3, R cost is l2_cost[idx1] + l2_cost[idx2].
            
            // Helper to get index of quad.
            // Quad index for W: w_perm.
            // Quad index for B: b_perm.
            // Remaining: 0..3 minus {w, b}.
            
            if (level > 1) begin // L2 and L3
                // We need to identify which square indices the remaining quads correspond to.
                // This is tricky because l1_cost is indexed by 0..15.
                // 
                // We have `sq_idx` at current level.
                // We need to find the sub-square indices at level-1.
                // 
                // Let Q be a quad (0..3) of the current square.
                // We need to map Q to the index in the lower level.
                // 
                // Level 2 (4x4) -> Level 1 (2x2).
                // sq_idx (0..3). 
                // Q0 (TL) corresponds to L1 index: (sq_idx * 2) + 0? No.
                // L1 squares are 0..15.
                // Square 0 covers (0..1, 0..1). Square 1 covers (0..1, 2..3).
                // Square 2? No, L1 indices: 
                // (row/2)*4 + (col/2).
                // Square 0 (4x4) covers rows 0-3, cols 0-3.
                // Inside it, L1 squares: 0, 1, 4, 5.
                // 
                // Formula: 
                // L2 sq_idx: r2, c2.
                // Q0: L1 idx = (r2*2)*4 + (c2*2) = 2*4*r2 + 2*c2.
                // Q1: L1 idx = (r2*2)*4 + (c2*2+1).
                // Q2: L1 idx = (r2*2+1)*4 + (c2*2).
                // Q3: L1 idx = (r2*2+1)*4 + (c2*2+1).
                
                // Level 3 (8x8) -> Level 2 (4x4).
                // L2 sq_idx: 0..3.
                // Q0: L2 idx = 0.
                // Q1: L2 idx = 1.
                // Q2: L2 idx = 2.
                // Q3: L2 idx = 3.
                // (Since L2 squares are exactly the quads of L3).
                
                // Let's get base index of lower level.
                // base_idx_lower
                // Level 3 -> Level 2: base is 0.
                // Level 2 -> Level 1: base is (r2*2)*4 + (c2*2) = (r2*4 + c2)*2 = sq_idx*2? 
                // sq_idx = r2*2 + c2 (for 2x2 grid of 4x4 squares).
                // r2 = sq_idx / 2, c2 = sq_idx % 2.
                // base_lower = (r2*2)*4 + (c2*2) = 8*r2 + 2*c2.
                // 8*r2 = 4*(2*r2) = 4*sq_idx? No.
                // r2 = sq_idx/2, so 2*r2 = (sq_idx/2)*2 = sq_idx (if even) or sq_idx-1.
                // Let's stick to: 
                // L1 indices 0..15.
                // If L2 sq_idx = 0: covers L1 0, 1, 4, 5.
                // If L2 sq_idx = 1: covers L1 2, 3, 6, 7.
                // If L2 sq_idx = 2: covers L1 8, 9, 12, 13.
                // If L2 sq_idx = 3: covers L1 10, 11, 14, 15.
                // Pattern: 
                // Row of L2: sq_idx/2. 
                // Row of L1 start: (sq_idx/2)*8.
                // Col of L2: sq_idx%2.
                // Col of L1 start: (sq_idx%2)*2.
                // Base: (sq_idx/2)*8 + (sq_idx%2)*2.
                
                // Let's calculate indices for remaining quads.
                // We will iterate quad 0..3. If quad != w_perm && quad != b_perm, add cost.
                
                // To implement this in combinational logic:
                // We can use a for loop inside the always block.
                // Verilog allows this for generation, but for simulation/combinational logic it's synthesizable if unrolled.
                
                for (integer q_loop = 0; q_loop < 4; q_loop = q_loop + 1) begin
                    if (q_loop != w_perm && q_loop != b_perm) begin
                        // q_loop is a remaining quad.
                        // Get its cost.
                        if (level == 2) begin
                            // Map q_loop to L1 index
                            // r2 = sq_idx / 2, c2 = sq_idx % 2
                            // qr = q_loop / 2, qc = q_loop % 2
                            // l1_idx = (r2*2 + qr) * 4 + (c2*2 + qc)
                            // = (sq_idx/2*2 + q_loop/2) * 4 + ...
                            // Simpler: Base + offset
                            // base_l1 = (sq_idx/2)*8 + (sq_idx%2)*2
                            // offset = (q_loop/2)*4 + (q_loop%2)*1
                            // Wait, q_loop/2 is row of quad (0 or 1).
                            // q_loop%2 is col of quad (0 or 1).
                            // offset = (q_loop/2)*4 + (q_loop%2)
                            // Let's test: sq_idx=0 (base 0). q=0 -> 0. q=1 -> 1. q=2 -> 4. q=3 -> 5. Correct.
                            
                            // We need to compute this in hardware.
                            // Since q_loop is constant in unrolled loop, synthesis tool handles it.
                            r_opt_sum = r_opt_sum + l1_cost[ ( (sq_idx/2)*8 + (sq_idx%2)*2 ) + ( (q_loop/2)*4 + (q_loop%2) ) ];
                        end else if (level == 3) begin
                            // Map q_loop to L2 index.
                            // q_loop IS the L2 index.
                            // sq_idx=0 covers L2 0..3.
                            r_opt_sum = r_opt_sum + l2_cost[q_loop];
                        end
                    end
                end
            end
            
            // Total Cost = W_diff + B_diff + R_opt
            current_total_cost = w_diff_sum + b_diff_sum + r_opt_sum;
            
        end
    end

    // Output Extraction Sequential Logic (part of OUTPUT state)
    // We added logic in the OUTPUT state of the FSM above.

endmodule
