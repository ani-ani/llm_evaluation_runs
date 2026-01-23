module lcs_without_virus (
    input clk,
    input rst_n,
    input start,
    input [4:0] s1_char,
    input [4:0] s2_char,
    input [4:0] virus_char,
    input [2:0] idx_s1,
    input [2:0] idx_s2,
    input [2:0] idx_virus,
    input input_valid,
    output reg [3:0] max_length,
    output reg [63:0] result_string,
    output reg done,
    output reg valid
);

    // Parameters
    parameter S1_LEN = 8;
    parameter S2_LEN = 8;
    parameter VIRUS_LEN = 3;
    parameter CHAR_WIDTH = 5;

    // Internal memory
    reg [CHAR_WIDTH-1:0] s1_mem [0:S1_LEN-1];
    reg [CHAR_WIDTH-1:0] s2_mem [0:S2_LEN-1];
    reg [CHAR_WIDTH-1:0] virus_mem [0:VIRUS_LEN-1];

    // KMP Next array
    reg [2:0] kmp_next [0:VIRUS_LEN-1];
    reg [2:0] kmp_idx_reg;

    // DP State Buffers
    reg [3:0] dp_cur_len [0:VIRUS_LEN];
    reg [3:0] dp_next_len [0:VIRUS_LEN];
    reg [3:0] left_len [0:VIRUS_LEN];
    
    // Parent pointers
    reg [3:0] dp_cur_pi [0:VIRUS_LEN];
    reg [3:0] dp_cur_pj [0:VIRUS_LEN];
    reg [2:0] dp_cur_pk [0:VIRUS_LEN];

    reg [3:0] dp_next_pi [0:VIRUS_LEN];
    reg [3:0] dp_next_pj [0:VIRUS_LEN];
    reg [2:0] dp_next_pk [0:VIRUS_LEN];

    reg [3:0] left_pi [0:VIRUS_LEN];
    reg [3:0] left_pj [0:VIRUS_LEN];
    reg [2:0] left_pk [0:VIRUS_LEN];

    // Trace Memory
    reg [9:0] trace_mem [0:323];
    wire [8:0] trace_addr;
    reg [9:0] trace_data_in;
    reg trace_wr;
    wire [9:0] trace_read_data;

    // Counters & Registers
    reg [3:0] i_cnt, j_cnt;
    reg [2:0] k_cnt;
    reg [2:0] load_cnt;
    reg [3:0] backtrack_i, backtrack_j;
    reg [2:0] backtrack_k;
    reg [3:0] result_len;
    reg max_found;

    // FSM
    typedef enum logic [3:0] {
        IDLE, LOAD, BUILD_KMP, INIT_DP, 
        DP_LOOP, NEXT_J, NEXT_I, 
        FIND_MAX, SETUP_BT, BACKTRACK, OUTPUT, DONE
    } state_t;
    state_t current_state, next_state;

    // Combinational Logic
    assign trace_addr = (current_state == BACKTRACK || current_state == OUTPUT) ? 
                        (backtrack_i * (S2_LEN + 1) * (VIRUS_LEN + 1) + backtrack_j * (VIRUS_LEN + 1) + backtrack_k) : 
                        (current_state == NEXT_J ? (i_cnt * (S2_LEN + 1) * (VIRUS_LEN + 1) + j_cnt * (VIRUS_LEN + 1) + k_cnt) : 0);
    assign trace_read_data = trace_mem[trace_addr];

    // Helper Function for KMP
    function automatic logic [2:0] get_kmp_trans;
        input [2:0] state;
        input [CHAR_WIDTH-1:0] char;
        begin
            if (state == VIRUS_LEN) get_kmp_trans = VIRUS_LEN;
            else if (virus_mem[state] == char) get_kmp_trans = state + 1;
            else if (state > 0) begin
                logic [2:0] fallback = kmp_next[state - 1];
                if (virus_mem[fallback] == char) get_kmp_trans = fallback + 1;
                else if (fallback > 0) begin
                    fallback = kmp_next[fallback - 1];
                    if (virus_mem[fallback] == char) get_kmp_trans = fallback + 1;
                    else get_kmp_trans = 0;
                end else get_kmp_trans = 0;
            end else get_kmp_trans = 0;
        end
    endfunction

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_length <= 0;
            result_string <= 0;
            done <= 0;
            valid <= 0;
            load_cnt <= 0;
            kmp_idx_reg <= 0;
            trace_wr <= 0;
            max_found <= 0;
        end else begin
            current_state <= next_state;
            trace_wr <= 0; // Default

            case (current_state)
                LOAD: if (input_valid) begin
                    s1_mem[idx_s1] <= s1_char;
                    s2_mem[idx_s2] <= s2_char;
                    virus_mem[idx_virus] <= virus_char;
                    load_cnt <= load_cnt + 1;
                end

                BUILD_KMP: begin
                    if (kmp_idx_reg < VIRUS_LEN) begin
                        if (kmp_idx_reg == 0) kmp_next[0] <= 0;
                        else begin
                            logic [2:0] prev = kmp_next[kmp_idx_reg - 1];
                            if (virus_mem[kmp_idx_reg] == virus_mem[prev])
                                kmp_next[kmp_idx_reg] <= prev + 1;
                            else
                                kmp_next[kmp_idx_reg] <= 0;
                        end
                        kmp_idx_reg <= kmp_idx_reg + 1;
                    end
                end

                INIT_DP: begin
                    for (int idx = 0; idx <= VIRUS_LEN; idx = idx + 1) begin
                        dp_cur_len[idx] <= 0;
                        dp_cur_pi[idx] <= 0; dp_cur_pj[idx] <= 0; dp_cur_pk[idx] <= 0;
                        left_len[idx] <= 0;
                        left_pi[idx] <= 0; left_pj[idx] <= 0; left_pk[idx] <= 0;
                        dp_next_len[idx] <= 0;
                    end
                    i_cnt <= 0; j_cnt <= 0; k_cnt <= 0;
                end

                DP_LOOP: begin
                    // 1. Merge Left and Top
                    logic [3:0] best_l;
                    logic [3:0] p_i, p_j; logic [2:0] p_k;
                    
                    best_l = dp_cur_len[k_cnt];
                    p_i = (i_cnt > 0) ? i_cnt - 1 : 0;
                    p_j = j_cnt;
                    p_k = k_cnt;
                    
                    if (left_len[k_cnt] > best_l) begin
                        best_l = left_len[k_cnt];
                        p_i = i_cnt;
                        p_j = (j_cnt > 0) ? j_cnt - 1 : 0;
                        p_k = k_cnt;
                    end

                    dp_next_len[k_cnt] <= best_l;
                    dp_next_pi[k_cnt] <= p_i;
                    dp_next_pj[k_cnt] <= p_j;
                    dp_next_pk[k_cnt] <= p_k;

                    // 2. Match Transition (Update Target State)
                    if (i_cnt < S1_LEN && j_cnt < S2_LEN && s1_mem[i_cnt] == s2_mem[j_cnt]) begin
                        logic [2:0] next_k = get_kmp_trans(k_cnt, s1_mem[i_cnt]);
                        logic [3:0] match_val = dp_cur_len[k_cnt] + 1;
                        if (next_k < VIRUS_LEN && match_val > dp_next_len[next_k]) begin
                            dp_next_len[next_k] <= match_val;
                            dp_next_pi[next_k] <= i_cnt - 1;
                            dp_next_pj[next_k] <= j_cnt;
                            dp_next_pk[next_k] <= k_cnt;
                        end
                    end

                    k_cnt <= k_cnt + 1;
                end

                NEXT_J: begin
                    // Store to Left Buffer
                    for (int idx = 0; idx <= VIRUS_LEN; idx = idx + 1) begin
                        left_len[idx] <= dp_next_len[idx];
                        left_pi[idx] <= dp_next_pi[idx];
                        left_pj[idx] <= dp_next_pj[idx];
                        left_pk[idx] <= dp_next_pk[idx];
                        
                        // Write to Trace Memory
                        // Address: i*9*4 + j*4 + k. Note: 9=rows, 4=states.
                        // We use {i,j,k} mapping.
                        trace_data_in <= {dp_next_pi[idx], dp_next_pj[idx], dp_next_pk[idx]};
                        // Trigger write (address is comb logic)
                        trace_wr <= 1;
                    end
                    j_cnt <= j_cnt + 1;
                    k_cnt <= 0;
                end

                NEXT_I: begin
                    // Prepare for next row: copy dp_next to dp_cur (skip s1 propagation)
                    // But we must also include the Left propagation which is now in 'left' for the new row.
                    // Actually, at the start of a new row, left is zero (or should be reset).
                    // The DP logic: dp[i][j] = max(dp[i-1][j], dp[i][j-1], match).
                    // We maintain:
                    // dp_cur = dp[i-1][*] (Top)
                    // left = dp[i][j-1] (Left)
                    // 
                    // When we move to next row (i+1):
                    // New dp_cur should be dp[i][*] which is currently in dp_next (at end of row).
                    // But dp_next contains values for column j=S2_LEN-1.
                    // So we swap.
                    
                    for (int idx = 0; idx <= VIRUS_LEN; idx = idx + 1) begin
                        dp_cur_len[idx] <= dp_next_len[idx];
                        dp_cur_pi[idx] <= dp_next_pi[idx];
                        dp_cur_pj[idx] <= dp_next_pj[idx];
                        dp_cur_pk[idx] <= dp_next_pk[idx];
                        
                        // Reset Left for new row (since j starts at 0, no left neighbor)
                        left_len[idx] <= 0;
                        dp_next_len[idx] <= 0; // Reset accumulation for new row
                    end
                    i_cnt <= i_cnt + 1;
                    j_cnt <= 0;
                    k_cnt <= 0;
                    
                    // Check if we are done
                    if (i_cnt == S1_LEN - 1) begin
                        // We just finished the last row.
                        // The values in dp_next (which we just copied to dp_cur) are the final row values.
                        // But we need to check the max of the FINAL state.
                        // Let's find max in the next state (FIND_MAX).
                    end
                end

                FIND_MAX: begin
                    // We need to check the final row values.
                    // Since we just moved to NEXT_I (where i becomes S1_LEN), 
                    // we should check dp_next (the last computed row) or handle it in NEXT_I.
                    // Actually, the loop structure is i=0..7.
                    // After i=7 processing, we go to NEXT_I, i becomes 8.
                    // dp_cur now has row 7 values. dp_next is reset or garbage.
                    // Wait, in NEXT_I we copy dp_next to dp_cur.
                    // dp_next had the values for row i=7 (after j loop).
                    // So dp_cur has final values.
                    // But we need to check ALL k states for max.
                    
                    // Let's iterate k in this state to find max.
                    // We will use k_cnt for this loop.
                    if (k_cnt < VIRUS_LEN) begin
                        if (dp_cur_len[k_cnt] > max_length) begin
                            max_length <= dp_cur_len[k_cnt];
                            backtrack_i <= i_cnt - 1; // Source is i-1
                            backtrack_j <= S2_LEN - 1;
                            backtrack_k <= k_cnt;
                        end
                        k_cnt <= k_cnt + 1;
                    end
                end

                SETUP_BT: begin
                    // Just a transition state to clear counters
                    k_cnt <= 0;
                    result_len <= 0;
                    result_string <= 0;
                    // backtrack_i/j/k are already set from FIND_MAX
                end

                BACKTRACK: begin
                    // Address is set by comb logic based on backtrack_i/j/k
                    // We wait for read data in OUTPUT state
                end

                OUTPUT: begin
                    // Use trace_read_data
                    // Extract parent
                    logic [3:0] pi = trace_read_data[9:6];
                    logic [3:0] pj = trace_read_data[5:3];
                    logic [2:0] pk = trace_read_data[2:0];
                    
                    // If we moved from (pi, pj) to (i, j), and i=pi+1, j=pj, then we matched s1[pi]
                    // Actually, we stored parents for state (i, j, k).
                    // So if we are at (i, j, k), the parent is (pi, pj, pk).
                    // The character matched (if any) is s1[i-1] or s2[j-1].
                    // We can determine if it was a match by checking the move.
                    // If pi == backtrack_i - 1 && pj == backtrack_j, then matched s1[backtrack_i - 1].
                    
                    if (pi == backtrack_i - 1 && pj == backtrack_j && backtrack_i > 0) begin
                        result_string[result_len * 5 +: 5] <= s1_mem[backtrack_i - 1];
                        result_len <= result_len + 1;
                    end
                    
                    // Update pointers
                    backtrack_i <= pi;
                    backtrack_j <= pj;
                    backtrack_k <= pk;
                end

                DONE: begin
                    done <= 1;
                    valid <= 1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: if (start) next_state = LOAD;
            LOAD: if (load_cnt >= (S1_LEN + S2_LEN + VIRUS_LEN)) next_state = BUILD_KMP;
            BUILD_KMP: if (kmp_idx_reg >= VIRUS_LEN) next_state = INIT_DP;
            INIT_DP: next_state = DP_LOOP;
            
            // DP Loop Control
            DP_LOOP: begin
                if (i_cnt >= S1_LEN) next_state = DONE; // Safety
                else if (k_cnt < VIRUS_LEN) next_state = DP_LOOP; // Continue k
                else next_state = NEXT_J; // K done, move to next column
            end
            
            NEXT_J: begin
                if (j_cnt < S2_LEN) next_state = DP_LOOP; // Next column
                else next_state = NEXT_I; // Row done
            end
            
            NEXT_I: begin
                if (i_cnt < S1_LEN) next_state = DP_LOOP; // Next row
                else next_state = FIND_MAX; // All rows done
            end
            
            FIND_MAX: begin
                if (k_cnt < VIRUS_LEN) next_state = FIND_MAX;
                else next_state = SETUP_BT;
            end
            
            SETUP_BT: next_state = BACKTRACK;
            
            BACKTRACK: next_state = OUTPUT;
            
            OUTPUT: begin
                // Check if we reached start state (0,0,0)
                // Note: trace_read_data is available this cycle? 
                // In BACKTRACK we set address. In OUTPUT we read.
                // trace_read_data is combinational, so it updates immediately when BACKTRACK sets address?
                // No, BACKTRACK is a state. The address logic is comb. 
                // In BACKTRACK state, `trace_addr` changes. `trace_read_data` changes.
                // In the same cycle (BACKTRACK state), the seq block reads `trace_read_data`?
                // No, seq block reads inputs at posedge.
                // So in BACKTRACK state, address is set. At next posedge, state becomes OUTPUT.
                // In OUTPUT state, `trace_read_data` contains the value from address set in BACKTRACK.
                // So we can use it in OUTPUT state logic.
                
                // Check if we are at start
                // We need to check the PARENT of current state.
                // The data read is the parent of the state we queried.
                // If parent is (0,0,0), we are done after this step.
                
                if (trace_read_data[9:6] == 0 && trace_read_data[5:3] == 0) begin
                    // This is the last step
                    // After writing the char in OUTPUT state logic, we go to DONE.
                    // But we need to process this data.
                    next_state = DONE; // Or SETUP_BT for final char? 
                    // The seq logic writes the char if match.
                    // If we go DONE now, we might skip writing if not handled.
                    // Let's go SETUP_BT to verify or DONE.
                    // Actually, if parent is (0,0), we have matched char at current i/j.
                    // So we should write it and then done.
                    // The seq block writes it.
                    // Next state should be DONE.
                    // But wait, if we go DONE immediately, we stop. 
                    // Let's go to a state where we check length.
                    next_state = SETUP_BT; // Loop check
                end else begin
                    next_state = BACKTRACK;
                end
            end
            
            // Add a loop guard for SETUP_BT
            // If result_len == max_length, go DONE.
            SETUP_BT: begin
                if (result_len >= max_length && max_length > 0) next_state = DONE;
                else next_state = BACKTRACK;
            end
            
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

endmodule