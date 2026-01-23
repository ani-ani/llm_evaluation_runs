module card_game_solver #(
    parameter N_ATK = 2,
    parameter N_DEF = 2,
    parameter M = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N_ATK-1:0] jatk_en,
    input wire [N_ATK-1:0][7:0] jatk_str,
    input wire [N_DEF-1:0] jdef_en,
    input wire [N_DEF-1:0][7:0] jdef_str,
    input wire [M-1:0][7:0] ciel_str,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam IDLE = 5'b00001;
    localparam LOAD = 5'b00010;
    localparam SORT = 5'b00011;
    localparam STRATEGY1_CHECK = 5'b00100;
    localparam STRATEGY1_MATCH_DEF = 5'b00101;
    localparam STRATEGY1_MATCH_ATK = 5'b00110;
    localparam STRATEGY1_DIRECT = 5'b00111;
    localparam STRATEGY2_MATCH = 5'b01000;
    localparam STORE_RESULT = 5'b01001;
    localparam DONE = 5'b01010;

    reg [4:0] state;
    
    // Internal Registers for inputs and intermediate values
    reg [N_ATK-1:0] jatk_en_reg;
    reg [N_ATK-1:0][7:0] jatk_str_reg [0:N_ATK-1]; // Flattened handling in logic
    reg [N_DEF-1:0] jdef_en_reg;
    reg [N_DEF-1:0][7:0] jdef_str_reg [0:N_DEF-1];
    reg [M-1:0][7:0] ciel_str_reg;
    
    // Sorting/Merging Buffers
    reg [7:0] sorted_ciel [0:M-1];
    reg [7:0] jatk_sorted [0:N_ATK-1];
    reg [7:0] jdef_sorted [0:N_DEF-1];
    
    // Strategy 1 Registers
    reg [15:0] dmg_strat1;
    reg [15:0] ciel_sum_total; // Sum of all Ciel cards initially
    reg [15:0] ciel_sum_used;  // Sum of Ciel cards used in destruction
    reg [3:0] used_count_strat1; // Number of cards used in strat1
    
    // Strategy 2 Registers
    reg [15:0] dmg_strat2;
    
    // Sorting Indices
    reg [3:0] i_sort, j_sort; // Max M=8, so 4 bits
    
    // Matching Indices
    reg [3:0] idx_ciel;
    reg [3:0] idx_jdef;
    reg [3:0] idx_jatk;
    
    // Loop counters for Strategy 2
    reg [3:0] k; 
    
    // Helper: Count valid cards
    integer valid_atk_cnt;
    integer valid_def_cnt;
    
    // Bubble Sort Logic Helpers
    integer x, y;
    reg [7:0] temp_swap;
    
    // Combinatorial helper: Sum of Ciel cards (for direct damage calculation)
    reg [15:0] sum_remaining_ciel;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'b0;
            done <= 1'b0;
            // Clear internal regs
            jatk_en_reg <= 'b0;
            jdef_en_reg <= 'b0;
            // Arrays usually not cleared explicitly in HW unless needed, but good practice
            for (integer i=0; i<M; i=i+1) sorted_ciel[i] <= 8'b0;
            for (integer i=0; i<N_ATK; i=i+1) jatk_sorted[i] <= 8'b0;
            for (integer i=0; i<N_DEF; i=i+1) jdef_sorted[i] <= 8'b0;
            dmg_strat1 <= 16'b0;
            dmg_strat2 <= 16'b0;
            ciel_sum_total <= 16'b0;
            ciel_sum_used <= 16'b0;
            used_count_strat1 <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load inputs into internal registers
                    jatk_en_reg <= jatk_en;
                    jdef_en_reg <= jdef_en;
                    
                    // Flattened array assignment logic is tricky in always block if not supported directly
                    // We assume Verilog-2001/SV compatible handling or manual unpacking
                    // To be safe, we use a loop for loading if direct packed access isn't guaranteed by tool
                    for (integer i = 0; i < N_ATK; i = i + 1) begin
                        jatk_str_reg[i] <= jatk_str[i];
                    end
                    for (integer i = 0; i < N_DEF; i = i + 1) begin
                        jdef_str_reg[i] <= jdef_str[i];
                    end
                    
                    // Load Ciel cards and sort them directly into sorting buffer
                    // We copy ciel_str to sorted_ciel to prepare for sort
                    for (integer i = 0; i < M; i = i + 1) begin
                        sorted_ciel[i] <= ciel_str[i];
                    end
                    
                    // Initialize counters
                    i_sort <= 4'd1; 
                    j_sort <= 4'd0;
                    
                    state <= SORT;
                end

                SORT: begin
                    // Bubble Sort Network Logic
                    // We unroll the loops manually or use a counter-based state machine
                    // Given M=8, we can do this sequentially to save area, or partially unrolled.
                    // Here we do a standard bubble sort iteration over the array.
                    
                    // Logic: 
                    // Outer loop: i from 1 to M-1
                    // Inner loop: j from 0 to M-i-1
                    // If arr[j] > arr[j+1], swap
                    
                    // Since this is a single clock cycle per comparison/swap, we iterate indices.
                    
                    if (i_sort < M) begin
                        if (j_sort < M - i_sort) begin
                            // Compare and Swap
                            if (sorted_ciel[j_sort] > sorted_ciel[j_sort + 1]) begin
                                temp_swap <= sorted_ciel[j_sort];
                                sorted_ciel[j_sort] <= sorted_ciel[j_sort + 1];
                                sorted_ciel[j_sort + 1] <= temp_swap; 
                            end
                            j_sort <= j_sort + 1;
                            state <= SORT;
                        end else begin
                            // Inner loop done
                            i_sort <= i_sort + 1;
                            j_sort <= 0;
                            state <= SORT;
                        end
                    end else begin
                        // Sorting Complete
                        // Now we need to sort Jiro's cards too for matching logic
                        // We reuse i_sort and j_sort for sorting Jiro ATK and DEF
                        // Let's sort ATK first. Use i_sort for outer, j_sort for inner.
                        // Reset indices for ATK sort
                        i_sort <= 4'd1;
                        j_sort <= 4'd0;
                        state <= STRATEGY1_CHECK; // We will transition to specific sorting sub-states or do it inline
                        
                        // Actually, let's calculate sums here to save state count
                        ciel_sum_total <= 0;
                        // We need a cycle to sum up ciel cards
                        // Let's go to a specific sub-state for prep
                        state <= 5'b11111; // Temporary State for Prep
                    end
                end

                // Intermediate Prep State to sort Jiro cards and sum Ciel cards
                5'b11111: begin 
                    // 1. Sum Ciel Cards (comb logic might be safer but sequential is explicit)
                    // Since sorted_ciel is updated in previous cycle, we sum here.
                    ciel_sum_total <= 0;
                    for (integer k=0; k<M; k=k+1) begin
                        ciel_sum_total <= ciel_sum_total + sorted_ciel[k];
                    end
                    
                    // 2. Sort Jiro ATK Cards
                    // We can do this in 1 cycle if M is small (M=2 here), but let's be generic
                    // Using comb logic inside sequential block is risky for latches. 
                    // Let's just copy to jatk_sorted and sort via a few cycles or comb logic.
                    // Since N_ATK=2, we can just sort manually:
                    jatk_sorted[0] <= (jatk_str_reg[0] > jatk_str_reg[1] && jdef_en_reg[1]) ? jatk_str_reg[1] : jatk_str_reg[0]; // Wait, jdef_en doesn't apply here
                    // Correct logic: Just sort valid ones.
                    // Let's just copy unsorted first, then sort in separate states if N_ATK > 2.
                    // For N_ATK=2, it's easy.
                    
                    // To be generic for N_ATK=2, let's assume unsorted order matters only for valid bits.
                    // We will extract valid cards into a contiguous array for easier processing in STRATEGY1_CHECK.
                    
                    // Let's use a 'PACKING' state to pack valid cards into jatk_sorted/jdef_sorted arrays.
                    // This avoids complex sorting networks for small parameters.
                    state <= 5'b11010; // PACKING STATE
                end

                5'b11010: begin // PACKING STATE
                    // Pack valid ATK cards
                    integer idx = 0;
                    for (integer p=0; p<N_ATK; p=p+1) begin
                        if (jatk_en_reg[p]) begin
                            jatk_sorted[idx] <= jatk_str_reg[p];
                            idx = idx + 1;
                        end
                    end
                    // Sort the packed ATK cards (Bubble sort 1 pass for N_ATK=2)
                    if (N_ATK == 2 && jatk_en_reg[0] && jatk_en_reg[1]) begin
                        if (jatk_sorted[0] > jatk_sorted[1]) begin
                            jatk_sorted[0] <= jatk_sorted[1];
                            jatk_sorted[1] <= jatk_sorted[0];
                        end
                    end
                    
                    // Pack valid DEF cards
                    idx = 0;
                    for (integer p=0; p<N_DEF; p=p+1) begin
                        if (jdef_en_reg[p]) begin
                            jdef_sorted[idx] <= jdef_str_reg[p];
                            idx = idx + 1;
                        end
                    end
                    // Sort the packed DEF cards
                    if (N_DEF == 2 && jdef_en_reg[0] && jdef_en_reg[1]) begin
                        if (jdef_sorted[0] > jdef_sorted[1]) begin
                            jdef_sorted[0] <= jdef_sorted[1];
                            jdef_sorted[1] <= jdef_sorted[0];
                        end
                    end
                    
                    // Initialize Strategy 1 State Machine
                    idx_ciel <= 4'd0;
                    idx_jdef <= 4'd0;
                    used_count_strat1 <= 4'd0;
                    ciel_sum_used <= 16'd0;
                    dmg_strat1 <= 16'd0; // Reset damage
                    
                    // Count valids
                    valid_atk_cnt = 0;
                    for (int i=0; i<N_ATK; i=i+1) if (jatk_en_reg[i]) valid_atk_cnt = valid_atk_cnt + 1;
                    valid_def_cnt = 0;
                    for (int i=0; i<N_DEF; i=i+1) if (jdef_en_reg[i]) valid_def_cnt = valid_def_cnt + 1;
                    
                    // If no cards, skip to strategy 2 check logic (or set flag)
                    // We proceed to STRATEGY1_CHECK
                    state <= STRATEGY1_CHECK;
                end

                STRATEGY1_CHECK: begin
                    // Determine if we need to match DEF or ATK
                    // If DEF exists and we haven't processed them yet (idx_jdef < valid_def_cnt), go to MATCH_DEF
                    // Else go to MATCH_ATK
                    if (valid_def_cnt > 0 && idx_jdef < valid_def_cnt) begin
                        state <= STRATEGY1_MATCH_DEF;
                    end else begin
                        state <= STRATEGY1_MATCH_ATK;
                    end
                end

                STRATEGY1_MATCH_DEF: begin
                    // Try to destroy current DEF card (jdef_sorted[idx_jdef])
                    // Find smallest Ciel card > DEF_STR
                    // sorted_ciel is ascending. We need the first card > DEF_STR that is not used.
                    // Since we consume from the front (smallest) for DEF, we iterate idx_ciel.
                    
                    // Logic: Scan from current idx_ciel to find match
                    // If found: consume it, add to used sum, inc used_count, inc idx_jdef
                    // If end of list reached: fail match (but we continue to next DEF or ATK)
                    
                    // To keep state simple, we do one comparison per cycle or loop in state.
                    // Let's iterate idx_ciel.
                    
                    if (idx_ciel < M) begin
                        if (sorted_ciel[idx_ciel] > jdef_sorted[idx_jdef]) begin
                            // Match found
                            ciel_sum_used <= ciel_sum_used + sorted_ciel[idx_ciel];
                            used_count_strat1 <= used_count_strat1 + 1;
                            idx_jdef <= idx_jdef + 1;
                            // Move idx_ciel forward to consume card
                            idx_ciel <= idx_ciel + 1;
                            // We need to mark this card as used. 
                            // To avoid reusing, we can shift the array or just advance idx_ciel.
                            // Since we always pick the smallest matching card, advancing idx_ciel is correct.
                            state <= STRATEGY1_CHECK; // Check if more DEF or move to ATK
                        end else begin
                            // Too weak, discard and try next Ciel card
                            idx_ciel <= idx_ciel + 1;
                            state <= STRATEGY1_MATCH_DEF; // Stay in DEF state, checking next Ciel
                        end
                    end else begin
                        // Ran out of Ciel cards to match this DEF card (or any DEF)
                        // Move to ATK phase
                        state <= STRATEGY1_MATCH_ATK;
                    end
                end

                STRATEGY1_MATCH_ATK: begin
                    // Try to destroy current ATK card
                    // Find smallest Ciel card >= ATK_STR (using remaining cards)
                    // Remaining cards start from idx_ciel
                    
                    // Count valid ATKs to know when to stop
                    integer valid_atk_cnt_local = 0;
                    for (int i=0; i<N_ATK; i=i+1) if (jatk_en_reg[i]) valid_atk_cnt_local = valid_atk_cnt_local + 1;
                    
                    // We need a counter for which ATK we are processing.
                    // Let's reuse idx_jdef logic for ATK. But wait, idx_jdef is for DEF.
                    // We need a separate index for ATK processing.
                    // Let's use a new register idx_jatk_process to track how many ATKs destroyed.
                    // Actually, we can just scan jatk_sorted.
                    
                    // Let's implement the loop: For each ATK, find match.
                    // We need a loop counter for ATK index.
                    // We'll use a dedicated 'k' register for ATK loop, or reuse idx_jdef if we are careful.
                    // Let's use k for ATK loop. Initialize k=0 in packing state.
                    // Wait, I didn't initialize k in packing state. Let's do it here.
                    // Fix: In PACKING state, add k <= 0.
                    
                    // Logic: if (k < valid_atk_cnt)
                    //   if (idx_ciel < M)
                    //     if (sorted_ciel[idx_ciel] >= jatk_sorted[k]) match -> use card, k++, idx_ciel++, dmg += (ciel - atk)
                    //     else idx_ciel++
                    //   else fail for this atk (no damage), k++
                    // else go to direct attack
                    
                    // Check valid_atk_cnt logic
                    if (k < valid_atk_cnt) begin
                        if (idx_ciel < M) begin
                            if (sorted_ciel[idx_ciel] >= jatk_sorted[k]) begin
                                // Match
                                ciel_sum_used <= ciel_sum_used + sorted_ciel[idx_ciel];
                                used_count_strat1 <= used_count_strat1 + 1;
                                dmg_strat1 <= dmg_strat1 + (sorted_ciel[idx_ciel] - jatk_sorted[k]);
                                k <= k + 1;
                                idx_ciel <= idx_ciel + 1;
                            end else begin
                                // Weak card, skip
                                idx_ciel <= idx_ciel + 1;
                            end
                        end else begin
                            // No more cards to match
                            k <= k + 1; // Skip this ATK (or done if no more)
                        end
                    end else begin
                        // All ATKs matched (or skipped)
                        state <= STRATEGY1_DIRECT;
                    end
                end

                STRATEGY1_DIRECT: begin
                    // If we used cards to destroy everything, remaining cards deal direct damage.
                    // Direct damage = Sum of all cards - Sum of used cards.
                    // But wait, if we failed to destroy a card (DEF or ATK), direct damage is 0.
                    // The problem says "If all Jiro cards destroyed, sum remaining Ciel cards as direct damage".
                    // We need to know if all cards were destroyed.
                    // valid_def_cnt + valid_atk_cnt should equal used_count_strat1.
                    
                    if (used_count_strat1 == (valid_def_cnt + valid_atk_cnt)) begin
                        // All destroyed. 
                        // But we also need to subtract cards used for damage from the 'Direct' pool?
                        // No, "Direct damage = remaining Ciel cards sum".
                        // Remaining sum = Total sum - Used sum.
                        dmg_strat1 <= dmg_strat1 + (ciel_sum_total - ciel_sum_used);
                    end else begin
                        // Failed to clear board. Strategy 1 damage remains what we got from kills (if any)
                        // Or strictly 0 if we require full clear for damage? 
                        // "Try to destroy all Jiro's cards, then attack directly".
                        // Usually implies if you can't destroy, you deal 0.
                        // Let's assume we only get damage from kills here if full clear isn't met?
                        // Actually, usually in these games, if you don't clear, you can't hit face.
                        // But we already added kill damage.
                        // Let's keep the kill damage, but no direct damage bonus.
                        // Wait, if we didn't clear, we shouldn't have attacked face at all.
                        // But we already calculated (Ciel - ATK) for ATK kills. 
                        // Let's assume standard rules: If full clear, add remaining. 
                        // If not full clear, we get 0 (or just kill damage?).
                        // Let's strictly follow "If all Jiro cards destroyed...".
                        // So if not all destroyed, direct damage is 0. We might have some kill damage.
                        // Actually, usually Strategy 1 implies "Kill everything then face".
                        // If we fail to kill one, we stop.
                        // So `dmg_strat1` currently holds kill damage. 
                        // If `used_count_strat1` is full, add `total - used`.
                    end
                    
                    // Initialize Strategy 2
                    // Strategy 2: Match Largest Ciel with Smallest ATK.
                    // Since sorted_ciel is ascending, largest are at the end.
                    // jatk_sorted is ascending.
                    
                    // We need to iterate ATKs from smallest, and for each, pick largest available Ciel.
                    // This is easier: Iterate ATKs. For each ATK, pick largest remaining Ciel > ATK.
                    // Or just: Sort Ciel descending temporarily? No.
                    // Standard greedy: Sort Ciel Descending. Sort ATK Ascending.
                    // Pair: (Ciel[0], ATK[0]), (Ciel[1], ATK[1]), etc.
                    // If Ciel[i] > ATK[i], add diff.
                    
                    // Let's reverse sorted_ciel to get descending order for Strategy 2.
                    // We can just access indices from M-1 downwards.
                    
                    dmg_strat2 <= 16'd0;
                    k <= 0; // Reuse k for ATK index in Strategy 2
                    valid_atk_cnt = 0;
                    for (int i=0; i<N_ATK; i=i+1) if (jatk_en_reg[i]) valid_atk_cnt = valid_atk_cnt + 1;
                    
                    state <= STRATEGY2_MATCH;
                end

                STRATEGY2_MATCH: begin
                    // Loop through valid ATKs (k index in jatk_sorted)
                    // Loop through Ciel cards (from largest index downwards: M-1, M-2, ...)
                    // We need to keep track of which Ciel cards are used.
                    // Since we use the largest available Ciel for each ATK, we iterate Ciel from end.
                    // Let's maintain an index for Ciel: `idx_ciel_desc` starting at M-1.
                    // But wait, if Ciel cards are smaller than ATKs, we skip them.
                    // Greedy: Sort Ciel Desc. Sort ATK Asc.
                    // Iterate i from 0 to N_ATK-1. 
                    // If Ciel_desc[i] > ATK[i], add diff.
                    
                    // Let's use `k` for ATK index.
                    // We need to count valid ATKs.
                    if (k < valid_atk_cnt) begin
                        // We need to pick the k-th largest Ciel card that is valid.
                        // Since sorted_ciel is ascending, the k-th largest is at index M-1-k.
                        // However, we must check if that card is "used".
                        // Actually, Strategy 2 is usually simpler: 
                        // 1. Take all Ciel cards.
                        // 2. Take all ATK cards.
                        // 3. Sort Ciel Desc.
                        // 4. Sort ATK Asc.
                        // 5. For i=0 to min(N_ATK, N_Ciel)-1, if Ciel[i] > ATK[i], sum += Ciel[i] - ATK[i].
                        
                        // So we just need the k-th largest Ciel card.
                        // Index = M - 1 - k.
                        // We also need to ensure we don't use non-existent cards.
                        
                        int c_idx = M - 1 - k;
                        
                        // Since M=8 and k is small, we can compute index. 
                        // In Verilog, we need to be careful with array indexing.
                        // We can use a register to hold the index.
                        // Or just compute it: idx = M - 1 - k.
                        
                        // We need to handle cases where we have fewer Ciel cards than ATKs.
                        // If c_idx < 0, then no Ciel cards left.
                        // Since k increments, if k >= M, then c_idx < 0.
                        
                        if (k < M) begin // If we have enough Ciel cards in total (pool)
                            if (sorted_ciel[c_idx] > jatk_sorted[k]) begin
                                dmg_strat2 <= dmg_strat2 + (sorted_ciel[c_idx] - jatk_sorted[k]);
                            end
                            // If sorted_ciel[c_idx] <= jatk_sorted[k], we get 0 damage for this pair (or we might skip this pair entirely?
                            // Standard rules usually just sum positive differences, or skip pair).
                            // "Sum (Ciel - ATK) for valid matches". If diff is negative, usually 0.
                            // So we add max(0, diff). Since we don't have max(), we conditionally add.
                        end
                        
                        k <= k + 1;
                        state <= STRATEGY2_MATCH;
                    end else begin
                        state <= STORE_RESULT;
                    end
                end

                STORE_RESULT: begin
                    // Compare dmg_strat1 and dmg_strat2
                    if (dmg_strat1 > dmg_strat2) begin
                        result <= dmg_strat1;
                    end else begin
                        result <= dmg_strat2;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to reset? Or wait for new start?
                        // Usually done stays high until new start.
                        state <= DONE;
                        if (start) state <= IDLE; // Handle restart
                    end
                    if (start) state <= IDLE; // Actually if start is high here, we restart.
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for internal loop variables used in packing state
    // Note: Verilog requires loop variables to be automatic or defined outside.
    // We used 'int' inside always block which is SystemVerilog.
    // If strictly Verilog 2001, we use integer.
    
endmodule