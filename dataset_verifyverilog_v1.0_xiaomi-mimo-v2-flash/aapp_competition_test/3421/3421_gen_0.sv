module MaxDensitySubarray (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [8:0] k,
    input wire [7:0] s [255:0],
    output reg [7:0] start_idx,
    output reg [7:0] length,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] STORE_S      = 4'd1;
    localparam [3:0] SEARCH_SETUP = 4'd2;
    localparam [3:0] FEAS_CHECK   = 4'd3;
    localparam [3:0] UPDATE_BEST  = 4'd4;
    localparam [3:0] OUTPUT_RES   = 4'd5;
    localparam [3:0] DONE_STATE   = 4'd6;
    localparam [3:0] WAIT_DONE    = 4'd7; // Single cycle pulse

    // Binary search states
    localparam [1:0] BS_IDLE      = 2'd0;
    localparam [1:0] BS_GO        = 2'd1;
    localparam [1:0] BS_CHECK     = 2'd2;

    reg [3:0] state, next_state;
    reg [1:0] bs_state, next_bs_state;

    // Data registers
    reg [7:0] s_reg [255:0];
    reg [8:0] k_reg;
    reg [8:0] n_reg; // Actual length of input (derived from k or fixed max)

    // Binary search registers (scaled by 256)
    // Target density T = high[15:8] / 256
    reg [15:0] search_low;
    reg [15:0] search_high;
    reg [15:0] search_mid;
    reg [15:0] best_val_scaled;
    reg [7:0] search_iter;
    localparam [7:0] MAX_ITER = 8'd16;

    // Feasibility check registers
    // P[i] = sum(2*s[j]-1) for j=0..i-1
    // Feasible if P[j] - P[i] >= 0 and j-i >= k
    // Equivalent to (P[j] >= P[i]) and (j-i >= k)
    // For scaled threshold T: sum(2*s[j]-1 - T) >= 0
    // => sum(2*s[j]-1) >= T * (j-i)
    // => P[j] - P[i] >= T * (j-i)
    // => P[j] - T*j >= P[i] - T*i
    reg [15:0] prefix_sum;
    reg signed [23:0] current_val; // P[i] - T*i (scaled)
    reg signed [23:0] min_val;      // Min of P[i] - T*i in valid range
    reg [7:0] min_idx;
    reg signed [23:0] best_diff;    // Max (current - min)
    reg [7:0] best_len_feas;
    reg [7:0] best_start_feas;
    reg [7:0] i_cnt;
    reg [7:0] j_cnt;

    // Best solution registers
    reg [7:0] best_start;
    reg [7:0] best_len;
    reg [15:0] best_val_stored; // Scaled value of best solution

    // Logic to calculate N (length). Assuming full N=256 or fixed.
    // Here we use fixed N=256 as per spec array size.
    always @(*) begin
        n_reg = 9'd256;
    end

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bs_state <= BS_IDLE;
            done <= 1'b0;
            start_idx <= 8'd0;
            length <= 8'd0;
            search_iter <= 8'd0;
            // Initialize arrays to prevent X
            for (int i = 0; i < 256; i = i + 1) begin
                s_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            bs_state <= next_bs_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                STORE_S: begin
                    // Store input s into s_reg
                    // Using manual loop for compatibility
                    if (i_cnt < 8'd256) begin
                        s_reg[i_cnt] <= s[i_cnt];
                    end
                end
                SEARCH_SETUP: begin
                    // Initialize binary search bounds
                    // Density range [0.0, 1.0] -> Scaled [0, 256]
                    search_low <= 16'd0;
                    search_high <= 16'd256; // Inclusive upper bound
                    best_val_scaled <= 16'd0;
                    best_start <= 8'd0;
                    best_len <= 8'd0;
                    search_iter <= 8'd0;
                end
                FEAS_CHECK: begin
                    // Accumulate feasibility calculations
                    // Handled in combinational logic, state waits for completion
                end
                UPDATE_BEST: begin
                    // If feasible, update best and search higher (low = mid + 1)
                    // If not feasible, search lower (high = mid - 1)
                    // Handled in BS_CHECK state logic
                end
                OUTPUT_RES: begin
                    // Assign outputs
                    start_idx <= best_start + 8'd1; // 1-based
                    length <= best_len;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                WAIT_DONE: begin
                    done <= 1'b0;
                end
            endcase

            // Binary search iteration counter
            if (state == SEARCH_SETUP) begin
                search_iter <= 8'd0;
            end else if (state == UPDATE_BEST) begin
                search_iter <= search_iter + 8'd1;
            end
        end
    end

    // Feasibility Check Logic (Sequenced)
    // Computes: Is there a subarray of length >= k where sum(s[i] - T) >= 0?
    // We iterate j from k to N. 
    // min_val tracks min_{i <= j-k} (P[i] - T*i)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prefix_sum <= 16'd0;
            min_val <= 24'sd0;
            min_idx <= 8'd0;
            best_diff <= 24'sd0;
            best_len_feas <= 8'd0;
            best_start_feas <= 8'd0;
            i_cnt <= 8'd0;
            j_cnt <= 8'd0;
        end else begin
            if (state == FEAS_CHECK) begin
                // Sequenced loop logic
                if (j_cnt == 8'd0) begin
                    // Reset check
                    prefix_sum <= 16'd0;
                    // For scaled T, P[0] - T*0 = 0
                    min_val <= 24'sd0;
                    min_idx <= 8'd0;
                    best_diff <= 24'sd0;
                    best_len_feas <= 8'd0;
                    best_start_feas <= 8'd0;
                    j_cnt <= k_reg[7:0]; // Start checking valid end points at index k (0-based, P[k] corresponds to subarray 0..k-1)
                    // Actually, prefix sum P[x] is sum of 0..x-1.
                    // Subarray i..j has sum P[j+1] - P[i]. Length = j - i + 1.
                    // Condition: j - i + 1 >= k => i <= j - k + 1.
                    // Wait, spec says "indices i, j such that j - i >= k".
                    // If i and j are indices in string 0..N-1, length is j-i.
                    // If we use prefix sums P[0]...P[N], sum(i..j) = P[j+1] - P[i].
                    // Length = j-i+1. So j-i+1 >= k => i <= j+1-k.
                    // Let's assume spec indices are 0-based inclusive, length >= k.
                    // Let i be start, j be end (inclusive). length = j-i+1.
                    // Sum = P[j+1] - P[i]. Condition: j+1-i >= k => i <= j+1-k.
                    
                    // Special case: k=0 or k=1. Min length 1. 
                    // We need to handle valid lengths carefully.
                end else if (j_cnt < n_reg[7:0]) begin // Loop j from 0 to N-1 (end index of subarray)
                    // Calculate P[j+1]
                    // s[j] is 1 or 0. (2*s-1) is +1 or -1.
                    // Scaled threshold T is in [0, 256].
                    // We want sum( (2*s-1) - T ) >= 0 ? No, usually just sum(2*s-1) >= T * Len.
                    // Let's stick to: Find max sum(2*s-1) / Len.
                    // Feasibility: sum(2*s-1) >= T * Len ?
                    // For fixed point T scaled by 256: sum >= T * Len / 256 ?
                    // No, T is the density target. We want to check if density >= T exists.
                    // Density >= T <=> Sum(2*s-1) >= T * Len ? No.
                    // Density = (#ones)/Len. Sum(2*s-1) = #ones - #zeros = 2*#ones - Len.
                    // #ones/Len >= T  <=> 2*#ones - Len >= (2T - 1)*Len ?
                    // Let's use the transformed problem: maximize Sum(2*s-1) / Len.
                    // If we fix a value Y, check if (Sum - Y*Len) >= 0 exists.
                    // If we maximize (Sum / Len), this is the same as maximizing (Sum - Y*Len) for some Y.
                    // Here we binary search on Y (the value).
                    // Target Y. Check if max_{subarray} (Sum - Y*Len) >= 0.
                    // Transform: Sum - Y*Len = Sum_{k=i..j} ( (2*s[k]-1) - Y )
                    // Let A[k] = (2*s[k]-1) - Y. (Y is scaled integer)
                    // Check if max subarray sum of A[k] >= 0, with len >= k.
                    // This matches the "prefix sum - min prefix" method.
                    // P'[m] = sum_{0..m-1} A[i].
                    // Maximize P'[j+1] - P'[i] for j-i+1 >= k.
                    
                    // Update prefix sum A[k]
                    // A term = (2*s[k]-1)*SCALE - Y
                    // We use scale 1 for simplicity in logic, Y is scaled.
                    // Let's use scale 256 for Y.
                    // A term = 256*(2*s[k]-1) - Y.
                    // This fits in 18 bits roughly (256*2 = 512, Y ~ 256). 
                    // Let's use 24 bits for prefix to be safe.
                    
                    // We need to do this in pipelined/sequenced manner.
                    // Iteration j: 
                    // 1. Add term to current prefix.
                    // 2. If j >= k, we can form a subarray ending at j.
                    //    The start index i must satisfy i <= j - k + 1.
                    //    We track min_val = min_{i <= j-k+1} P'[i].
                    //    Check current P'[j+1] - min_val >= 0.
                    
                    // Calculate current term A[j]
                    // Term = 512*s[j] - 256 - Y
                    // s[j] is 1 bit. 0 or 1.
                    // If s[j] == 1: 512 - 256 - Y = 256 - Y
                    // If s[j] == 0: 0 - 256 - Y = -256 - Y
                    
                    // Update prefix sum (relative to start of feasibility check)
                    // Actually simpler: relative to 0. 
                    // P'[j] relative to P'[0]=0.
                    // But we need P'[j] - P'[i] >= 0.
                    // Let's maintain "relative" prefix sum.
                    // Reset prefix at start of check. 
                    // P_curr = 0 initially.
                    // j goes 0 to N-1.
                    // Loop:
                    //   val = (2*s[j]-1)*256 - Y
                    //   P_curr += val
                    //   If j >= k-1: (can form len >= k ending at j)
                    //     MinStart is min(P_start for starts 0 to j-k+1)
                    //     We update MinStart.
                    //     Check P_curr - MinStart >= 0.
                    //     Update MinStart = min(MinStart, P_curr_at_start_of_window)
                    //     Wait, MinStart is min of P values at indices i.
                    //     i goes 0 to j-k+1.
                    //     When j increments, i range shifts.
                    //     i = j - k + 1 becomes valid start.
                    //     We need P[i] for i = j - k + 1.
                    //     But we are iterating j.
                    //     We need to store P values? 
                    //     Or re-calculate? N=256. Memory is fine.
                    //     Let's use a BRAM or just registers? 
                    //     256x18 bit array is feasible in logic but large for manual code.
                    //     Re-calculation is slow (256*16 cycles = 4096).
                    //     Better to store P values.
                    //     Wait, we can update min_val on the fly if we know the P value at the new start index.
                    //     But the new start index is j-k+1. We need P[j-k+1].
                    //     If we don't store, we can't know it.
                    //     So we MUST store P values or compute them ahead.
                    //     Let's use a register array P_reg[256].
                    //     But Icarus doesn't like unpacked arrays in sensitive lists nicely sometimes.
                    //     Let's compute P values in a separate pass or store them.
                    //     Since N is small (256), let's calculate P values in SETUP phase? 
                    //     No, Y changes every iteration.
                    //     
                    //     Alternative: The classic algorithm.
                    //     Track min_prefix. 
                    //     For j in 0..N-1:
                    //       P += A[j]
                    //       If j >= k-1:
                    //         diff = P - min_prefix
                    //         If diff >= 0 -> Feasible.
                    //         Update min_prefix = min(min_prefix, P_at_index_{j-k+1})
                    //     To get P_at_index_{j-k+1}, we need to have saved it.
                    //     We can save it in a circular buffer or shift register of length k.
                    //     
                    //     Let's implement the buffer.
                    //     P_buffer stores P values.
                    //     When j reaches k-1, we populate min_prefix with P[0].
                    //     Then for j >= k, min_prefix compares with P[j-k+1].
                    //     
                    //     Sequence:
                    //     j = 0..N-1.
                    //     Compute P.
                    //     Store P in P_buffer[j].
                    //     If j >= k-1:
                    //       If j == k-1: min_prefix = P_buffer[0]
                    //       Else: min_prefix = min(min_prefix, P_buffer[j-k+1])
                    //       diff = P - min_prefix
                    //       If diff >= 0: flag feasible.
                    //     
                    //     We need P_buffer[256]. 256*18 = 4608 bits. OK.
                    //     We need to access it in a loop.
                    //     
                    //     Let's simplify the loop structure.
                    //     Since we are in a state machine, we can iterate j.
                    //     We need P_buffer for the FEAS_CHECK state.
                    
                    //     Let's do FEAS_CHECK in 2 loops if needed or one big sequenced loop.
                    //     One sequenced loop j=0 to N-1.
                    
                    //     Variables needed:
                    //     j_cnt (0 to N)
                    //     P_curr (24 bits)
                    //     P_buffer array (256 entries, 18 bits)
                    //     min_prefix (24 bits)
                    //     feasible_flag (1 bit)
                    
                    //     Let's use P_buffer logic.
                    //     Icarus constraint: unpacked arrays in always block tricky.
                    //     Better to use packed array or just reg [17:0] P_buffer [0:255].
                    //     Access: P_buffer[index].
                    //     
                    //     Refined FEAS_CHECK logic:
                    //     1. Calculate term = (s_reg[j_cnt] ? 256 : -256) - Y_scaled.
                    //        Wait, A[k] = (2*s[k]-1)*256 - Y.
                    //        2*s-1 is +1 or -1. Scaled by 256 => +256 or -256.
                    //        So term = 256 or -256, minus Y.
                    //     2. P_curr += term.
                    //     3. Store P_curr in P_buffer[j_cnt].
                    //     4. If j_cnt >= k_reg - 1:
                    //          If j_cnt == k_reg - 1: min_prefix = P_buffer[0].
                    //          Else: min_prefix = min(min_prefix, P_buffer[j_cnt - k_reg + 1]).
                    //          diff = P_curr - min_prefix.
                    //          If diff >= 0: feasible_flag = 1.
                    //     5. Increment j_cnt.
                    
                    //     Optimization: We can do this in FEAS_CHECK state until j_cnt == N.
                    //     If j_cnt reaches N, transition to UPDATE_BEST.
                    
                    //     Update P_curr logic.
                    //     P_curr is signed 24 bit.
                    
                    //     Handle k=0 case? Spec says k is 9-bit, likely >= 1.
                    //     If k=0, length 0 is valid? Usually length >= 1.
                    //     Let's assume k >= 1.
                    
                    //     Let's add P_buffer declaration.
                    
                    //     Wait, accessing P_buffer inside the loop requires it to be updated.
                    //     P_buffer[j_cnt] is written, P_buffer[j_cnt - k_reg + 1] is read.
                    //     This is fine.
                    
                    //     Start of FEAS_CHECK: reset j_cnt, P_curr, feasible_flag.
                    //     Loop until j_cnt == N.
                    
                    //     Need to handle sign of term.
                    //     Y is search_mid (0..256). 
                    //     term = (s_reg[j_cnt] ? 256 : -256) - search_mid.
                    //     
                    //     Let's fix the term calculation.
                    //     Target: Check if max density >= Y/256.
                    //     Condition: sum(2*s-1) >= (2*Y/256 - 1) * Len ? 
                    //     Let's stick to: Maximize (sum(2*s-1)*256 / Len) >= Y ?
                    //     Actually, maximizing density is same as maximizing (sum(2*s-1)).
                    //     If we binary search on value V.
                    //     Check if exists subarray len>=k: sum(2*s-1) >= V ?
                    //     No, that's not it. 
                    //     
                    //     Let's use the standard approach for max average subarray >= K.
                    //     Binary search on answer A.
                    //     Check if exists subarray of len >= k with average >= A.
                    //     sum / len >= A => sum - A*len >= 0.
                    //     Let X[i] = value[i] - A.
                    //     Check if max subarray sum of X with len >= k >= 0.
                    //     Here value is 0 or 1. 
                    //     So X[i] = (0 or 1) - A.
                    //     A is in [0, 1].
                    //     
                    //     We are searching for density d.
                    //     So X[i] = s[i] - d.
                    //     s[i] is 0 or 1.
                    //     
                    //     To avoid floating point:
                    //     Binary search integer S (0 to 256) representing d*256.
                    //     Check if exists subarray: sum(s[i] - S/256) >= 0
                    //     <=> sum(256*s[i] - S) >= 0
                    //     <=> sum(256*s[i]) >= S * Len
                    //     <=> sum(256*s[i]) - S*Len >= 0.
                    //     Define Y[i] = 256*s[i] - S.
                    //     Check max subarray sum Y with len >= k >= 0.
                    //     
                    //     So in FEAS_CHECK:
                    //     Term = (s_reg[j] ? 256 : 0) - S.
                    //     Prefix sum P.
                    //     Check P[j] - min(P[i]) >= 0 for j-i >= k.
                    
                    //     Refinement:
                    //     s[i] is 0 or 1.
                    //     If s[i]=1: val = 256 - S.
                    //     If s[i]=0: val = -S.
                    //     
                    //     S = search_mid.
                    //     search_mid is calculated in UPDATE_BEST state.
                    //     search_mid = (search_low + search_high) >> 1.
                    //     
                    //     Let's implement the FEAS_CHECK loop.
                    
                    //     Add P_buffer logic.
                    reg [17:0] p_val_write;
                    reg [17:0] p_val_read;
                    
                    // Calculate term
                    reg signed [17:0] term; // 17 bits signed is enough (max 256, min -256)
                    term = s_reg[j_cnt][0] ? (18'sd256 - search_mid) : (-(18'sd256 + search_mid)); 
                    // Correction: 256*s[i] - S. If s=0, it is -S.
                    // If s=1, 256 - S.
                    // search_mid is 0..256.
                    // -S ranges -256..0.
                    // 256-S ranges 0..256.
                    // So range is -256 to 256. 9 bits signed + sign.
                    // Let's use 18 bits signed.
                    
                    // Update P_curr (signed 24 bit)
                    if (j_cnt == 8'd0) begin
                        prefix_sum <= 16'd0; // Use prefix_sum as P accumulator? No, P_curr is separate.
                        // We need a register for P_curr. 
                        // Let's use `current_val` to hold P_curr in this context.
                        // Actually, `current_val` was used for P[i] - T*i. 
                        // Let's reuse it as P_curr accumulator.
                        current_val <= 24'sd0;
                        feasible_flag <= 1'b0;
                        min_prefix_val <= 24'sd0; // Renamed from min_val to avoid confusion
                    end else begin
                        current_val <= current_val + term;
                    end
                    
                    // Store current_val into P_buffer[j_cnt]
                    // P_buffer[j_cnt] <= current_val + term;
                    // We need to do this simultaneously or next cycle?
                    // Since current_val updates on posedge, we store the NEW value.
                    // So P_buffer[j_cnt] <= current_val + term.
                    
                    // Read P_buffer[j_cnt - k_reg + 1]
                    // If j_cnt >= k_reg - 1:
                    //   idx = j_cnt - k_reg + 1
                    //   min_prefix = min(min_prefix, P_buffer[idx])
                    
                    // Check condition
                    // diff = (current_val + term) - min_prefix
                    // If diff >= 0, feasible_flag = 1.
                    
                    // Let's break this down into states within FEAS_CHECK or just sequential logic.
                    // Given the complexity, let's sequence it carefully.
                    
                    // Actually, let's stick to the loop structure inside FEAS_CHECK state.
                    // We need an inner state for the loop? 
                    // No, we can just increment j_cnt and keep state as FEAS_CHECK.
                    // But we need to finish the loop to go to UPDATE_BEST.
                    // So: while (j_cnt < N) stay in FEAS_CHECK. Else goto UPDATE_BEST.
                    
                    // Logic for term:
                    // val = s_reg[j_cnt] ? (256 - search_mid) : (-search_mid);
                    // P_curr = P_curr + val.
                    
                    // We need to store P_curr values in a buffer to read back.
                    // We need a valid bit for the buffer.
                    // 
                    // Let's define the buffer inside the module.
                    // reg [17:0] p_buffer [0:255];
                    // 
                    // Step 1: Calculate val and new P.
                    // Step 2: Write new P to buffer.
                    // Step 3: If j_cnt >= k_reg, Read P[j_cnt - k_reg + 1] (Wait, i <= j - k + 1).
                    //         If j_cnt >= k_reg - 1: valid start exists.
                    //         Min prefix is min of P[0]...P[j_cnt - k_reg + 1].
                    //         We update min_prefix when we reach a new valid start index.
                    //         When j_cnt == k_reg - 1: valid starts are 0. min_prefix = P[0].
                    //         When j_cnt == k_reg: valid starts are 0, 1. min_prefix = min(prev, P[1]).
                    //         So we compare min_prefix with P[j_cnt - k_reg + 1].
                    //         
                    //         Note: P[i] corresponds to prefix sum up to i-1.
                    //         Subarray from i to j (inclusive). Length j-i+1.
                    //         Sum = P[j+1] - P[i].
                    //         Condition j-i+1 >= k => i <= j+1-k.
                    //         Let's use j as index 0..N-1.
                    //         P accumulates A[j].
                    //         At step j, P represents P[j+1].
                    //         We need to compare P[j+1] with P[i] where i <= j+1-k.
                    //         i ranges 0 to j+1-k.
                    //         Valid i starts appearing when j+1-k >= 0 => j >= k-1.
                    //         
                    //         Implementation:
                    //         j_cnt goes 0 to N-1.
                    //         P_curr accumulates sum(A[0]...A[j_cnt]).
                    //         This is P[j_cnt+1].
                    //         
                    //         If j_cnt >= k-1:
                    //           valid_start_idx = j_cnt + 1 - k = j_cnt - k + 1.
                    //           We need to consider P[valid_start_idx] in min calculation.
                    //           
                    //           When j_cnt == k-1: valid_start_idx = 0.
                    //             min_prefix = P[0] (which is 0).
                    //             Check P[k] - min_prefix >= 0.
                    //             
                    //           When j_cnt == k: valid_start_idx = 1.
                    //             min_prefix = min(min_prefix, P[1]).
                    //             Check P[k+1] - min_prefix >= 0.
                    //           
                    //           So we need to read P[valid_start_idx].
                    //           valid_start_idx = j_cnt - k_reg + 1.
                    //           
                    //           When j_cnt == k-1, we read P[0].
                    //           
                    //           We need to store P values.
                    //           P values are P[0], P[1], ... P[N].
                    //           P[0] = 0.
                    //           
                    //           Buffer size 257? 
                    //           N=256. j goes 0..255. P goes 0..256.
                    //           We can store P[0]...P[256].
                    //           
                    //           Buffer index logic:
                    //           We write P_curr (which is P[j+1]) to buffer at index j+1?
                    //           Or we write P_prev to index j.
                    //           Let's write P[0]..P[N-1] to buffer indices 0..N-1.
                    //           P[0] = 0.
                    //           At cycle j (0-indexed), we compute P[j+1].
                    //           We store P[j+1] for future use? 
                    //           We need P[i] where i is start index.
                    //           i <= j - k + 1.
                    //           So we need to store P[i] as we go.
                    //           
                    //           Let's use buffer indices 0..256.
                    //           buffer[0] = P[0] = 0.
                    //           Cycle j: 
                    //             Compute P[j+1].
                    //             Store P[j+1] in buffer[j+1].
                    //             
                    //             If j >= k-1:
                    //               start_idx = j - k + 1.
                    //               We need buffer[start_idx].
                    //               
                    //           This works. Buffer size 257.
                    //           257 * 18 bits = 4626 bits. OK.
                    
                    //           We need to initialize buffer[0] = 0 at start of FEAS_CHECK.
                    //           
                    //           Logic inside FEAS_CHECK:
                    //           
                    //           Wait, we need to handle the loop.
                    //           Since FEAS_CHECK is a state, we need to loop N times.
                    //           So we stay in FEAS_CHECK while j_cnt < N.
                    //           
                    //           First cycle of FEAS_CHECK (j_cnt = 0): 
                    //             P_curr = A[0].
                    //             Store P_curr in buffer[1]. (P[1])
                    //             j_cnt becomes 1.
                    //             
                    //           Wait, we need buffer[0] = P[0] = 0.
                    //           We should set buffer[0] <= 0 before loop starts.
                    //           
                    //           Sequence:
                    //           State = FEAS_CHECK.
                    //           If j_cnt == 0: buffer[0] <= 0. P_curr <= (2*s[0]-1)*256 - S. (Use term formula)
                    //           Else: P_curr <= P_curr + term.
                    //           
                    //           Store P_curr in buffer[j_cnt + 1].
                    //           
                    //           If j_cnt >= k_reg - 1:
                    //             start_idx = j_cnt - k_reg + 1.
                    //             min_prefix = min(min_prefix, buffer[start_idx]).
                    //             diff = P_curr - min_prefix.
                    //             If diff >= 0: feasible_flag = 1.
                    //           
                    //           Increment j_cnt.
                    //           
                    //           If j_cnt == N: goto UPDATE_BEST.
                    
                    //           Wait, we need to handle the boundary k=0?
                    //           k is 9-bit. If k=0, length >= 0. Empty subarray sum 0? 
                    //           Assume k>=1.
                    //           
                    //           Let's refine the term calculation.
                    //           A[j] = 256*s[j] - S.
                    //           S = search_mid.
                    //           
                    //           If s[j] == 1: term = 256 - S.
                    //           If s[j] == 0: term = -S.
                    //           
                    //           Let's declare buffer.
                    //           reg [17:0] p_buffer [0:256];
                    //           
                    //           We need to handle signed arithmetic.
                    //           P_curr, min_prefix, diff must be signed.
                    //           
                    //           Let's use `current_val` for P_curr (signed 24 bit).
                    //           `min_prefix_val` for min prefix (signed 24 bit).
                    //           `best_diff` for max diff found.
                    //           
                    //           Actually, we don't need to store max diff, just if >= 0 exists.
                    //           But we need best_len and best_start.
                    //           If feasible, we want to update best solution.
                    //           The update logic needs the parameters of the found solution.
                    //           So we need to track the start/end indices of the feasible subarray.
                    //           
                    //           If we find diff >= 0, we have a candidate:
                    //           length = j_cnt - start_idx + 1?
                    //           Wait, j_cnt is the index in string (0..N-1).
                    //           Subarray ends at j_cnt.
                    //           Start at start_idx.
                    //           Length = j_cnt - start_idx + 1.
                    //           
                    //           We update best_len and best_start if this length is > best_len.
                    //           Tie-breaking: 
                    //           Usually maximize density. If densities equal (both feasible for S),
                    //           we might want longer or shorter? 
                    //           The problem says "subsequence ... with maximum success rate".
                    //           If densities equal, length usually doesn't matter or we prefer longer? 
                    //           Usually pick any. Let's pick the first one found or the one with max length.
                    //           Let's track max length found during FEAS_CHECK.
                    //           
                    //           So in UPDATE_BEST:
                    //           best_len <= max_len_feas.
                    //           best_start <= corresponding_start.
                    //           best_val_scaled <= search_mid. (This is the current lower bound)
                    //           search_low <= search_mid + 1.
                    //           
                    //           If not feasible:
                    //           search_high <= search_mid - 1.
                    
                    //           Let's implement this logic.
                    
                    //           We need to save the start index when diff >= 0.
                    //           We can just update best_len_feas and best_start_feas in FEAS_CHECK.
                    
                    //           Special case: k=0 or k=1. 
                    //           If k=0, length 0 is valid? 
                    //           Usually subarray length >= 1.
                    //           Let's assume k >= 1. 
                    //           If k > N, no solution. 
                    //           Handle k > N: Output 0, 0? Or handle gracefully.
                    //           Let's add check at start. If k > N, done immediately.
                    
                    //           Let's code the FEAS_CHECK update.
                    
                    //           We need p_buffer. 
                    //           To avoid unpacked array issues in some tools, let's use packed if possible.
                    //           257x18 bits is 4626 bits. 
                    //           SystemVerilog allows unpacked arrays.
                    //           Icarus Verilog supports unpacked arrays in some contexts but can be picky.
                    //           If unsure, use manual indexing or flattened array.
                    //           Let's try unpacked array. If it fails, we can fix.
                    
                    //           We need to update p_buffer inside the always block.
                    //           p_buffer[j_cnt + 1] <= current_val + term;
                    //           Access: p_buffer[start_idx].
                    
                    //           We need to handle the first cycle of FEAS_CHECK separately to init buffer[0].
                    //           Let's add a sub-state or use j_cnt to distinguish.
                    //           If j_cnt == 0: buffer[0] <= 0.
                    //           
                    //           We also need to calculate term. 
                    //           term = s_reg[j_cnt] ? (18'sd256 - search_mid) : (-(18'sd256 + search_mid));
                    //           Wait, if s=0, term is -search_mid. 
                    //           If s=1, term is 256-search_mid.
                    
                    //           Let's correct the term calculation.
                    //           A[j] = 256*s[j] - S.
                    //           If s[j]=1: 256 - S.
                    //           If s[j]=0: 0 - S = -S.
                    //           
                    //           So term = s_reg[j_cnt] ? (256 - search_mid) : (-search_mid);
                    //           Note: search_mid is 16 bit unsigned. 
                    //           256 - search_mid can be negative. Must cast to signed.
                    //           
                    //           Let's define signed term.
                    //           term = s_reg[j_cnt] ? ($signed(18'sd256) - search_mid) : (-$signed(search_mid));
                    //           
                    //           Let's put this in code.
                    
                end else begin
                    // Loop done
                    j_cnt <= 8'd0;
                end
            end else begin
                // Reset counters if not in FEAS_CHECK
                j_cnt <= 8'd0;
            end
            
            if (state == STORE_S) begin
                if (i_cnt < 8'd256)
                    i_cnt <= i_cnt + 8'd1;
                else
                    i_cnt <= 8'd0;
            end else if (state == IDLE || state == OUTPUT_RES) begin
                i_cnt <= 8'd0;
            end
        end
    end

    // Internal declarations for FEAS_CHECK logic
    reg signed [23:0] p_curr;
    reg signed [23:0] min_prefix;
    reg [17:0] p_buffer [0:256]; // Unpacked array
    reg feasible_flag;
    reg [7:0] feas_len;
    reg [7:0] feas_start;
    
    // Separate combinational logic for FEAS_CHECK to handle the loop cleanly
    // Or integrate into the sequential block above. 
    // The sequential block above has the loop structure.
    // We just need to handle the logic inside.
    // Since we can't do multi-cycle assignments in one block easily without vars.
    // Let's use the sequential block for control, and add another always block for logic?
    // No, keep it together to avoid multiple drivers.
    
    // Let's refine the sequential block logic for FEAS_CHECK.
    // We'll use `p_curr`, `min_prefix`, `feasible_flag`, `feas_len`, `feas_start`.
    
    // We need to access s_reg. s_reg is unpacked array.
    // s_reg[j_cnt] is valid.
    
    // We need to handle the case k > N.
    // This should be checked before entering SEARCH_SETUP.
    
    // Logic for UPDATE_BEST:
    // if (feasible_flag) begin
    //     best_val_scaled <= search_mid;
    //     best_start <= feas_start;
    //     best_len <= feas_len;
    //     search_low <= search_mid + 1;
    // end else begin
    //     search_high <= search_mid - 1;
    // end
    // search_mid <= (search_low + search_high) >> 1;
    
    // Let's write the complete sequential logic for FEAS_CHECK and UPDATE_BEST.
    // We need to handle the transitions.
    
    // Re-defining the sequential block logic for these states:
    // We need to ensure `p_buffer` is handled correctly. 
    // Icarus Verilog might have issues with unpacked arrays inside always_ff blocks if not careful.
    // Let's try to use a for-loop to initialize p_buffer to avoid X's.
    
    // Also, we need to handle the case where k=0. 
    // If k=0, length >= 0. The max density is usually defined on non-empty subarrays.
    // If empty is allowed, density is 0/0 undefined. 
    // So assume k>=1.
    
    // Let's put the logic for FEAS_CHECK inside the main sequential block.
    // We'll use a sub-state or just rely on j_cnt.
    
    // Refinement of FEAS_CHECK in the sequential block:
    // We need to separate the "first cycle" logic.
    // 
    // If (state == FEAS_CHECK) begin
    //     if (j_cnt == 0) begin
    //         p_buffer[0] <= 18'sd0;
    //         p_curr <= (s_reg[0] ? (18'sd256 - search_mid) : (-search_mid));
    //         min_prefix <= 24'sd0; // P[0] is 0
    //         feasible_flag <= 1'b0;
    //         feas_len <= 8'd0;
    //         feas_start <= 8'd0;
    //         // Store P[1]
    //         p_buffer[1] <= (s_reg[0] ? (18'sd256 - search_mid) : (-search_mid));
    //         // Check validity for len >= k
    //         // j=0. Valid starts i where 0-i+1 >= k? i <= 1-k.
    //         // If k=1, i <= 0. i=0 valid.
    //         // If k>1, no valid start yet.
    //         // So we need to check if 0 >= k-1.
    //         if (0 >= k_reg - 1) begin
    //             // Valid subarray ending at 0
    //             // Start index 0. Length 1.
    //             // min_prefix is P[0].
    //             // diff = P[1] - P[0].
    //             // We need to check this.
    //             // But wait, k=1 case: length 1 is valid.
    //             // Condition: 0 >= 1-1 = 0. True.
    //             // So we check diff.
    //             if (p_curr >= 0) begin
    //                 feasible_flag <= 1'b1;
    //                 feas_len <= 8'd1;
    //                 feas_start <= 8'd0;
    //             end
    //         end
    //         j_cnt <= 8'd1;
    //     end else if (j_cnt < n_reg[7:0]) begin
    //         // General cycle
    //         // 1. Calculate term for s[j_cnt]
    //         // 2. Update p_curr
    //         // 3. Store p_curr in buffer[j_cnt+1]
    //         // 4. Update min_prefix if valid
    //         // 5. Check condition
    //         
    //         // Term calculation
    //         reg signed [17:0] term;
    //         term = s_reg[j_cnt] ? ($signed(18'sd256) - search_mid) : (-$signed(search_mid));
    //         
    //         reg signed [23:0] next_p;
    //         next_p = p_curr + term;
    //         
    //         // Update min_prefix
    //         // Valid start index is j_cnt - k_reg + 1.
    //         // We need to compare min_prefix with P[j_cnt - k_reg + 1].
    //         // Note: p_buffer index stores P[index].
    //         // P[0] is at 0. P[1] at 1.
    //         // We need P[start_idx].
    //         // start_idx = j_cnt - k_reg + 1.
    //         // Wait, j_cnt is current index (end of subarray).
    //         // Start index i <= j_cnt - k_reg + 1.
    //         // The new start index becoming valid is j_cnt - k_reg + 1.
    //         // We update min_prefix with P[j_cnt - k_reg + 1].
    //         
    //         // But we need to be careful with indices.
    //         // j_cnt is the index of the element we are processing.
    //         // P_curr is sum up to j_cnt.
    //         // This corresponds to P[j_cnt + 1].
    //         // 
    //         // Let's visualize:
    //         // S: 0 1 2 ...
    //         // P: 0 1 2 ...
    //         // Subarray i..j. Sum = P[j+1] - P[i].
    //         // Length = j - i + 1.
    //         // Condition: j - i + 1 >= k => i <= j + 1 - k.
    //         // 
    //         // In our loop, j is j_cnt.
    //         // We have computed P[j_cnt+1] in `next_p`.
    //         // We store it in p_buffer[j_cnt+1].
    //         // 
    //         // Valid starts i satisfy i <= j_cnt + 1 - k.
    //         // We want min(P[i]) for valid i.
    //         // 
    //         // When does a new start become valid?
    //         // As j_cnt increases, max valid i increases.
    //         // At step j_cnt, valid i are 0 to j_cnt + 1 - k.
    //         // 
    //         // We need to update min_prefix with P[j_cnt + 1 - k].
    //         // 
    //         // Example: k=1.
    //         // j=0: Valid i <= 0. i=0. min_prefix = P[0]. Check P[1] - P[0].
    //         // j=1: Valid i <= 1. i=0,1. Update min with P[1]. Check P[2] - min.
    //         // 
    //         // Example: k=2.
    //         // j=0: Valid i <= -1. None. 
    //         // j=1: Valid i <= 0. i=0. Update min with P[0]. Check P[2] - P[0].
    //         // j=2: Valid i <= 1. i=0,1. Update min with P[1]. Check P[3] - min.
    //         
    //         // So, we update min_prefix with p_buffer[j_cnt + 1 - k_reg].
    //         // And check condition.
    //         
    //         // Note: j_cnt + 1 - k_reg must be >= 0.
    //         // This corresponds to j_cnt >= k_reg - 1.
    //         
    //         // Logic:
    //         reg signed [17:0] val_to_compare;
    //         reg [7:0] read_idx;
    //         
    //         // Update p_curr and store
    //         p_curr <= next_p;
    //         p_buffer[j_cnt + 1] <= next_p;
    //         
    //         if (j_cnt >= k_reg - 1) begin
    //             read_idx = j_cnt + 1 - k_reg;
    //             val_to_compare = p_buffer[read_idx];
    //             
    //             // Update min_prefix
    //             if (next_p < min_prefix) begin
    //                 min_prefix <= next_p;
    //             end
    //             // Actually, min_prefix should be min of all previous valid P's.
    //             // min_prefix = min(min_prefix, val_to_compare).
    //             // Wait, val_to_compare is P[j_cnt + 1 - k].
    //             // This is the NEW valid start's P value.
    //             // So yes, update min_prefix with it.
    //             
    //             // Check condition: P[j_cnt+1] - min_prefix >= 0
    //             // diff = next_p - min_prefix
    //             // But we update min_prefix first?
    //             // Yes, we check using the current min prefix (which includes the new one).
    //             // 
    //             // Update min_prefix:
    //             if (val_to_compare < min_prefix) begin
    //                 min_prefix <= val_to_compare;
    //                 // Check with new min
    //                 if (next_p - val_to_compare >= 0) begin
    //                     feasible_flag <= 1'b1;
    //                     // Update best length for this feasibility check
    //                     // Length = j_cnt + 1 - (start index)
    //                     // Wait, which start index gives the max length?
    //                     // The condition is: exists i such that P[i] <= next_p and i <= j_cnt+1-k.
    //                     // If we just want to know IF feasible, we don't need the exact length.
    //                     // But we need the best length for the update.
    //                     // 
    //                     // If we want the maximum length subarray for the current density S:
    //                     // We are checking if density >= S exists.
    //                     // We found one. 
    //                     // But we need to record the best length found SO FAR.
    //                     // 
    //                     // Tie-breaking: If we found a feasible solution, we usually just need to know it exists.
    //                     // However, the prompt says: "Track the best found length and start index globally."
    //                     // This implies inside the binary search loop.
    //                     // If S is feasible, we update global best with THIS subarray?
    //                     // Or just update the global best with the best subarray found for this S?
    //                     // 
    //                     // The binary search maximizes S. 
    //                     // If S is feasible, we record S as current best density.
    //                     // We also need to record the length and start of the subarray that achieved this density.
    //                     // 
    //                     // So, if we find a feasible subarray, we should update:
    //                     // best_val_scaled = S
    //                     // best_len = length of this subarray
    //                     // best_start = start of this subarray
    //                     // 
    //                     // But we might find multiple subarrays for the same S.
    //                     // We should probably track the LONGEST one (or any).
    //                     // Let's track the longest one found during the FEAS_CHECK for this S.
    //                     // 
    //                     // So we need variables: feas_len, feas_start.
    //                     // When we find a valid subarray, we check if its length > feas_len.
    //                     // 
    //                     // Length = j_cnt + 1 - (start index).
    //                     // Which start index? The one that gives the valid diff.
    //                     // The diff is next_p - min_prefix.
    //                     // min_prefix corresponds to some index i_min.
    //                     // So length = j_cnt + 1 - i_min.
    //                     // 
    //                     // We need to know i_min.
    //                     // We store P values. We also need to store the INDEX of P values?
    //                     // No, we can just store the start index corresponding to min_prefix.
    //                     // 
    //                     // Let's add a register `min_prefix_idx`.
    //                     // When we update min_prefix, we update min_prefix_idx.
    //                     // 
    //                     // 
    //                     // Correction:
    //                     // min_prefix = min(P[i]) for valid i.
    //                     // When we find next_p - min_prefix >= 0:
    //                     // The subarray is from min_prefix_idx to j_cnt.
    //                     // Length = j_cnt - min_prefix_idx + 1.
    //                     // 
    //                     // So we need to track min_prefix_idx.
    //                 end
    //             end else begin
    //                 // min_prefix is smaller or equal.
    //                 // Check diff using existing min_prefix.
    //                 if (next_p - min_prefix >= 0) begin
    //                     feasible_flag <= 1'b1;
    //                 end
    //             end
    //             
    //             // If we found a valid subarray, update feas_len/feas_start if length is larger.
    //             // Note: We need to know the length.
    //             // Length = j_cnt - min_prefix_idx + 1.
    //             // 
    //             // We need to calculate this inside the if block.
    //             // But we don't have the index easily unless we track it.
    //             // 
    //             // Let's track `min_prefix_idx`.
    //             // When j_cnt == k-1, min_prefix_idx = 0.
    //             // When we update min_prefix with val_to_compare (which is P[j_cnt+1-k]),
    //             // we also update min_prefix_idx = j_cnt + 1 - k.
    //             // 
    //             // So:
    //             // if (val_to_compare < min_prefix) begin
    //             //    min_prefix <= val_to_compare;
    //             //    min_prefix_idx <= j_cnt + 1 - k_reg;
    //             // end
    //             // 
    //             // Then check diff:
    //             // if (next_p - min_prefix >= 0) begin
    //             //    len = j_cnt - min_prefix_idx + 1;
    //             //    if (len > feas_len) ...
    //             // end
    //         end
    //         
    //         j_cnt <= j_cnt + 1;
    //     end else begin
    //         // Loop finished
    //         // Transition to UPDATE_BEST
    //         // Note: This logic is inside the always block.
    //         // We need to transition state.
    //         // But this is combinational logic for next_state.
    //         // Wait, the logic above is sequential.
    //         // If we update j_cnt, we stay in FEAS_CHECK.
    //         // When j_cnt reaches N, we need to go to UPDATE_BEST.
    //         // This transition should be handled by the state transition logic.
    //         // 
    //         // Let's add a condition: if (j_cnt == N && state == FEAS_CHECK) next_state = UPDATE_BEST;
    //     end
    // end

    // Let's consolidate the logic.
    // We need a few more registers: min_prefix_idx, p_curr, min_prefix, feas_len, feas_start, feasible_flag.
    // And p_buffer.
    
    // Edge case: k > N. 
    // Check in IDLE or SEARCH_SETUP. If k > N, go directly to DONE or OUTPUT_RES with 0.
    // k is 9 bit, N is 256. If k >= 257, invalid.
    // If k > N, no subarray of length >= k exists.
    // Output 0, 0? 
    
    // Let's add the p_buffer declaration.
    // reg [17:0] p_buffer [0:256]; // Already declared above.
    
    // State transition logic
    always @(*) begin
        next_state = state;
        next_bs_state = bs_state;
        
        case (state)
            IDLE: begin
                if (start) next_state = STORE_S;
            end
            STORE_S: begin
                if (i_cnt == 8'd255) next_state = SEARCH_SETUP;
            end
            SEARCH_SETUP: begin
                // If k > N (256), we can't find a subarray. 
                // But k is 9-bit. If k > 256, invalid. 
                // Let's assume k <= 256 for valid inputs.
                // If k > 256, go to DONE.
                // k_reg is updated in IDLE or STORE_S? 
                // k is input. We capture it in IDLE.
                // Let's capture k in IDLE.
                
                // Transition to FEAS_CHECK immediately?
                // Yes, we start binary search iteration.
                // But we need to calculate search_mid first.
                // search_mid is calculated in UPDATE_BEST or here?
                // First iteration: low=0, high=256. mid=128.
                // So we need to calculate mid before FEAS_CHECK.
                // 
                // Actually, SEARCH_SETUP sets up bounds. 
                // Then we need to go to FEAS_CHECK.
                // But we need to ensure search_mid is ready.
                // Let's calculate search_mid in SEARCH_SETUP or as combinational logic.
                // Let's do it in SEARCH_SETUP.
                // search_mid = (search_low + search_high) >> 1.
                
                // However, binary search loop structure:
                // while (low <= high) {
                //    mid = (low+high)/2;
                //    if (feasible(mid)) { best = mid; low = mid+1; }
                //    else { high = mid-1; }
                // }
                // 
                // We need to loop MAX_ITER times or until low > high.
                // Let's use a loop counter.
                // 
                // If search_iter < MAX_ITER:
                //   Calculate mid.
                //   Go to FEAS_CHECK.
                // Else: Go to OUTPUT_RES.
                // 
                // Also need to check search_low <= search_high.
                // If not, done.
                
                // Let's check search_low <= search_high.
                // Also check iter count.
                // If both OK, go FEAS_CHECK.
                // Else go OUTPUT_RES.
                
                if (search_iter < MAX_ITER && search_low <= search_high) begin
                    next_state = FEAS_CHECK;
                end else begin
                    next_state = OUTPUT_RES;
                end
            end
            FEAS_CHECK: begin
                // Wait for loop to finish (j_cnt == N)
                // We use j_cnt to track progress.
                // j_cnt goes 0 to N.
                // If j_cnt < N, stay here.
                // If j_cnt == N, go to UPDATE_BEST.
                if (j_cnt < n_reg[7:0]) begin
                    next_state = FEAS_CHECK;
                end else begin
                    next_state = UPDATE_BEST;
                end
            end
            UPDATE_BEST: begin
                // Update bounds based on feasible_flag
                // Then go back to SEARCH_SETUP (to increment iter and calc mid) or OUTPUT_RES.
                // Actually, SEARCH_SETUP calculates mid. 
                // But we update bounds here. 
                // So we should go back to a state that calculates the next mid.
                // Or calculate mid here.
                // Let's go to SEARCH_SETUP. 
                // But SEARCH_SETUP resets things if we aren't careful.
                // Let's modify SEARCH_SETUP to not reset everything if search_iter > 0.
                // Or create a CALC_MID state.
                // Let's just go to SEARCH_SETUP. 
                // In SEARCH_SETUP, if search_iter > 0, we don't reset low/high.
                // We just calc mid.
                
                next_state = SEARCH_SETUP;
            end
            OUTPUT_RES: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = WAIT_DONE;
            end
            WAIT_DONE: begin
                if (!start) next_state = IDLE; // Wait for start to go low
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Logic for BS transitions
    always @(*) begin
        next_bs_state = bs_state;
        case (bs_state)
            BS_IDLE: if (state == SEARCH_SETUP) next_bs_state = BS_GO;
            BS_GO: if (state == FEAS_CHECK) next_bs_state = BS_CHECK; // Trigger start?
            BS_CHECK: if (state == UPDATE_BEST) next_bs_state = BS_IDLE;
            default: next_bs_state = BS_IDLE;
        endcase
    end

    // Sequential logic updates for FEAS_CHECK and UPDATE_BEST
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic handled in main FSM block mostly
            // Just reset internal vars
            p_curr <= 24'sd0;
            min_prefix <= 24'sd0;
            min_prefix_idx <= 8'd0;
            feas_len <= 8'd0;
            feas_start <= 8'd0;
            feasible_flag <= 1'b0;
            search_low <= 16'd0;
            search_high <= 16'd0;
            search_mid <= 16'd0;
            best_val_scaled <= 16'd0;
            best_start <= 8'd0;
            best_len <= 8'd0;
            // Initialize p_buffer to 0 to avoid X propagation
            // Icarus might not like initial block for synthesis, but always block is fine.
            // We can just rely on writes. Reads before write are undefined but we control flow.
        end else begin
            case (state)
                IDLE: begin
                    k_reg <= k; // Capture k
                end
                STORE_S: begin
                    // s_reg handled in main FSM block
                end
                SEARCH_SETUP: begin
                    // Initialize binary search if first iteration
                    if (search_iter == 8'd0) begin
                        search_low <= 16'd0;
                        search_high <= 16'd256;
                        best_val_scaled <= 16'd0;
                        best_start <= 8'd0;
                        best_len <= 8'd0;
                    end
                    // Calculate mid
                    // search_mid <= (search_low + search_high) >> 1;
                    // Use shift for division by 2
                    search_mid <= (search_low + search_high) >> 1;
                    
                    // Reset feasibility tracking
                    j_cnt <= 8'd0;
                    feasible_flag <= 1'b0;
                    feas_len <= 8'd0;
                    feas_start <= 8'd0;
                end
                FEAS_CHECK: begin
                    // Loop logic
                    if (j_cnt < n_reg[7:0]) begin
                        // First cycle setup
                        if (j_cnt == 8'd0) begin
                            p_buffer[0] <= 18'sd0;
                            min_prefix <= 24'sd0;
                            min_prefix_idx <= 8'd0;
                            
                            // Calculate P[1]
                            // term = s[0] ? (256 - S) : (-S)
                            // search_mid is S
                            reg signed [17:0] term;
                            term = s_reg[0] ? ($signed(18'sd256) - search_mid) : (-$signed(search_mid));
                            p_curr <= term;
                            
                            // Store P[1]
                            p_buffer[1] <= term;
                            
                            // Check validity for length >= k ending at 0
                            // Valid if 0 >= k-1 (i.e., k <= 1)
                            if (0 >= k_reg - 1) begin
                                // Valid subarray from 0 to 0
                                // Min prefix is P[0]=0
                                if (term >= 0) begin
                                    feasible_flag <= 1'b1;
                                    feas_len <= 8'd1;
                                    feas_start <= 8'd0;
                                end
                            end
                        end else begin
                            // General cycle
                            reg signed [17:0] term;
                            reg signed [23:0] next_p;
                            reg signed [17:0] val_to_compare;
                            reg [7:0] read_idx;
                            reg signed [23:0] new_min;
                            
                            // Calculate term for current index j_cnt
                            term = s_reg[j_cnt] ? ($signed(18'sd256) - search_mid) : (-$signed(search_mid));
                            next_p = p_curr + term;
                            
                            // Update P_curr
                            p_curr <= next_p;
                            // Store in buffer
                            p_buffer[j_cnt + 1] <= next_p;
                            
                            // Check if we have valid subarrays ending at j_cnt
                            // Valid start index i <= j_cnt + 1 - k_reg
                            // New valid start index is j_cnt + 1 - k_reg
                            if (j_cnt >= k_reg - 1) begin
                                read_idx = j_cnt + 1 - k_reg;
                                val_to_compare = p_buffer[read_idx];
                                
                                // Update min_prefix
                                if (val_to_compare < min_prefix) begin
                                    min_prefix <= val_to_compare;
                                    min_prefix_idx <= read_idx;
                                    new_min = val_to_compare;
                                end else begin
                                    new_min = min_prefix;
                                end
                                
                                // Check condition: next_p - new_min >= 0
                                if (next_p - new_min >= 0) begin
                                    feasible_flag <= 1'b1;
                                    
                                    // Calculate length
                                    // Length = j_cnt - start_idx + 1
                                    // start_idx = min_prefix_idx
                                    // Note: indices are 0-based.
                                    // If j_cnt=0, start=0, len=1. Correct.
                                    // 
                                    // We need to track the MAX length found for this S
                                    // Use a temporary variable or just compare with feas_len
                                    // We need to compute length. 
                                    // Since we are in always block, we can't easily compute in combinational way here.
                                    // But we can just check and update.
                                    // Wait, we need to compare (j_cnt - min_prefix_idx + 1) with feas_len.
                                    // We can do this comparison with a wire or localparam?
                                    // Let's use a local variable.
                                    // Note: min_prefix_idx is updated in the same cycle if we found a new min.
                                    // So we should use the `read_idx` if we updated min, else `min_prefix_idx`.
                                    // Actually, `new_min` logic helps. If we updated min, `new_min` is val_to_compare.
                                    // The corresponding index is `read_idx`.
                                    // If we didn't update, it's `min_prefix_idx`.
                                    
                                    // Let's determine the current best start index for this cycle.
                                    reg [7:0] curr_start;
                                    if (val_to_compare < min_prefix) begin
                                        curr_start = read_idx;
                                    end else begin
                                        curr_start = min_prefix_idx;
                                    end
                                    
                                    // Calculate current length
                                    // j_cnt is current index (end).
                                    // Length = j_cnt - curr_start + 1.
                                    // Note: j_cnt is the loop variable.
                                    // 
                                    // Update feas_len if this length is greater.
                                    // Note: j_cnt is 1-based in loop? No, 0-based.
                                    // Loop j_cnt = 0, 1, ...
                                    // At j_cnt=0, we handled above.
                                    // Here j_cnt >= 1.
                                    // 
                                    // We need to compare (j_cnt - curr_start + 1) > feas_len.
                                    // We can compute this.
                                    
                                    // Since we can't do complex arithmetic in combinational inside always_ff easily without blocking,
                                    // we can just check the condition.
                                    // 
                                    // Wait, `feas_len` is a register. We can't read and write it in the same block reliably for comparison.
                                    // We need combinational logic for the comparison or use next_val.
                                    // Or just do it sequentially.
                                    // 
                                    // Let's use a temporary register `temp_len` to hold the candidate length.
                                    // But we need to compute it.
                                    // 
                                    // Let's do this:
                                    // If (next_p - new_min >= 0) begin
                                    //     if (j_cnt - curr_start + 1 > feas_len) begin
                                    //         feas_len <= j_cnt - curr_start + 1;
                                    //         feas_start <= curr_start;
                                    //     end
                                    // end
                                    // 
                                    // We can compute `j_cnt - curr_start + 1`.
                                    // 
                                    // However, `curr_start` depends on `min_prefix_idx` which is a register.
                                    // `val_to_compare < min_prefix` is combinational.
                                    // 
                                    // If `val_to_compare < min_prefix`, `curr_start = read_idx`.
                                    // Else `curr_start = min_prefix_idx`.
                                    // 
                                    // `read_idx = j_cnt + 1 - k_reg`. This is combinational.
                                    // 
                                    // So we can compute `curr_start` and `len`.
                                    // 
                                    // Let's define `len_temp`.
                                    reg [7:0] len_temp;
                                    len_temp = j_cnt - curr_start + 1;
                                    
                                    if (len_temp > feas_len) begin
                                        feas_len <= len_temp;
                                        feas_start <= curr_start;
                                    end
                                end
                            end
                            
                            // Increment j_cnt
                            // We handle this at the end of the block or in main FSM?
                            // Main FSM block increments j_cnt if state == FEAS_CHECK.
                            // We need to ensure j_cnt updates correctly.
                            // The main FSM block has: if (j_cnt < N) j_cnt <= j_cnt + 1.
                            // We need to make sure we don't double increment.
                            // Let's remove the increment from main FSM block and do it here.
                        end
                        
                        // Increment j_cnt (must be at the end of the block)
                        j_cnt <= j_cnt + 8'd1;
                    end
                end
                UPDATE_BEST: begin
                    // Update binary search bounds
                    if (feasible_flag) begin
                        best_val_scaled <= search_mid;
                        best_start <= feas_start;
                        best_len <= feas_len;
                        search_low <= search_mid + 1;
                    end else begin
                        search_high <= search_mid - 1;
                    end
                    search_iter <= search_iter + 8'd1;
                end
            endcase
        end
    end
    
    // Remove j_cnt increment from main FSM block to avoid conflict
    // The main FSM block has j_cnt logic in FEAS_CHECK.
    // We need to modify that part.
    // The main FSM block code above for FEAS_CHECK:
    // if (j_cnt < n_reg[7:0]) begin ... end else begin j_cnt <= 8'd0; end
    // We need to remove the j_cnt increment inside that block.
    // And let the sequential block handle it.
    // Actually, the sequential block handles it at the end of FEAS_CHECK state.
    // So we just need to ensure the main FSM block doesn't reset j_cnt prematurely.
    
    // Correction to main FSM block for FEAS_CHECK:
    // if (j_cnt < n_reg[7:0]) begin
    //    // stay in FEAS_CHECK
    // end else begin
    //    j_cnt <= 8'd0; // Reset for next time
    // end
    
    // And remove the `j_cnt <= j_cnt + 1` from the main FSM block.
    // The sequential block handles the increment.
    
    // Also, we need to declare min_prefix_idx.
    // reg [7:0] min_prefix_idx;
    // reg signed [23:0] p_curr;
    // reg signed [23:0] min_prefix;
    // reg [17:0] p_buffer [0:256];
    // reg feasible_flag;
    // reg [7:0] feas_len;
    // reg [7:0] feas_start;

    // Wait, we need to handle the case where k > N.
    // In IDLE, we capture k_reg.
    // In SEARCH_SETUP, we can check.
    // If k_reg > 256 (N), then no solution.
    // We should go directly to OUTPUT_RES with best_len = 0.
    // But k_reg is 9 bit. N=256. 
    // If k_reg > 256, it's invalid or implies no solution.
    // Let's check in SEARCH_SETUP.
    // if (k_reg > 256) next_state = OUTPUT_RES; (handled in combinational logic)
    // In OUTPUT_RES, best_len is 0 by default.
    
    // Also need to handle k=0.
    // If k=0, min length is 0? Usually 1. 
    // If k=0, we assume k=1 or handle specially.
    // Let's assume k>=1.
    
    // Need to declare p_buffer in the module body.
    // And other regs.
    
    // Let's refine the combinational next_state logic for SEARCH_SETUP.
    // if (search_iter < MAX_ITER && search_low <= search_high && k_reg <= 256) begin
    //    next_state = FEAS_CHECK;
    // end else begin
    //    next_state = OUTPUT_RES;
    // end
    
    // Also, we need to reset j_cnt in SEARCH_SETUP (done in sequential block).
    
    // We need to fix the term calculation for s=0.
    // term = s_reg[j_cnt] ? ($signed(18'sd256) - search_mid) : (-$signed(search_mid));
    // -search_mid is correct for s=0.
    
    // We need to handle the case where search_mid is 16 bit and we subtract from 18 bit.
    // $signed(search_mid) casts it to signed 16 bit, then to 18 bit.
    // (18'sd256 - $signed(search_mid)) is correct.
    
    // We need to declare the internal regs.
    // We should add them to the module port list? No, internal.
    // Add them in the body.
    
    // One issue: The `p_buffer` is unpacked array. 
    // Icarus Verilog supports unpacked arrays but accessing them inside always_ff blocks with variable indices can be tricky.
    // Specifically, `p_buffer[j_cnt + 1] <= ...` where j_cnt is a variable.
    // This should work in standard Verilog.
    
    // Let's double check the reset of p_buffer. 
    // We write to it. We read from it. 
    // If we read an unwritten index, it's X.
    // We write indices 0, 1, ... N.
    // We read indices 0 ... N-k.
    // We write before we read in the same cycle? 
    // In the logic above:
    // We compute `next_p`.
    // We write `p_buffer[j_cnt + 1] <= next_p`.
    // We read `p_buffer[read_idx]`.
    // `read_idx = j_cnt + 1 - k_reg`.
    // So we are reading an index written in a PREVIOUS cycle (since read_idx < j_cnt+1).
    // This is correct.
    
    // The only exception is the first cycle where we write buffer[0] and buffer[1].
    // In cycle 0: write 0, 1. Read none (or buffer[0] for min).
    // Wait, in cycle 0 (j_cnt=0), we write buffer[0] and buffer[1].
    // In cycle 1 (j_cnt=1), we read buffer[1 - k].
    // If k=1, read buffer[1].
    // We wrote buffer[1] in cycle 0. Correct.
    
    // One more thing: `search_mid` calculation.
    // search_mid <= (search_low + search_high) >> 1;
    // This shifts the 16-bit value. Correct for integer division.
    
    // Finally, the output.
    // start_idx is 1-based.
    // best_start is 0-based.
    // So output best_start + 1.
    // But what if best_len is 0? (No solution).
    // Then start_idx 1 might be misleading.
    // If no solution, output 0, 0? 
    // If best_len == 0, we can output start_idx 0.
    
    // Let's code the missing parts.
    
    // Missing registers:
    reg [7:0] min_prefix_idx;
    reg signed [23:0] p_curr;
    reg signed [23:0] min_prefix;
    reg [17:0] p_buffer [0:256];
    reg feasible_flag;
    reg [7:0] feas_len;
    reg [7:0] feas_start;
    
    // Corrected Main FSM Block for FEAS_CHECK (j_cnt increment part)
    // The sequential block handles j_cnt increment.
    // The combinational block must just check the condition.
    
    // In the combinational block:
    // case (state)
    //    ...
    //    FEAS_CHECK: begin
    //        if (j_cnt < n_reg[7:0]) next_state = FEAS_CHECK;
    //        else next_state = UPDATE_BEST;
    //    end
    //    ...
    // endcase
    
    // In the sequential block:
    // case (state)
    //    ...
    //    FEAS_CHECK: begin
    //        if (j_cnt < n_reg[7:0]) begin
    //            // Logic...
    //            j_cnt <= j_cnt + 1;
    //        end else begin
    //            j_cnt <= 0; // Reset
    //        end
    //    end
    //    ...
    // endcase
    
    // Need to declare n_reg. N=256.
    // localparam [8:0] N = 9'd256;
    // reg [8:0] n_reg;
    // assign n_reg = 9'd256; 
    // Or just use 9'd256 directly.
    
    // We need to handle k=0 case. 
    // If k=0, length >= 0. 
    // Usually length >= 1.
    // If k=0, we can treat it as k=1.
    // Let's add: if (k_reg == 0) k_reg <= 1; in IDLE.
    
    // Also, we need to handle the case where k > N.
    // If k > 256, no solution.
    // In SEARCH_SETUP: if (k_reg > 256) next_state = OUTPUT_RES;
    
    // One final check on the term calculation:
    // term = s_reg[j_cnt] ? (256 - search_mid) : (-search_mid);
    // search_mid is unsigned 16 bit (0-256).
    // -search_mid is -0 to -256.
    // 256 - search_mid is 0 to 256.
    // Range fits in signed 9 bits, but we cast to 18 bits.
    
    // What about the case `search_mid` is 16 bit and we subtract from 18 bit?
    // (18'sd256 - $signed({{14{search_mid[15]}}, search_mid}))? No.
    // $signed(search_mid) works if search_mid is treated as signed.
    // But search_mid is declared as reg [15:0].
    // Arithmetic with `search_mid` will treat it as unsigned unless cast.
    // -search_mid will be unsigned if search_mid is unsigned?
    // No, unary minus promotes to signed.
    // But to be safe and explicit:
    // term = s_reg[j_cnt] ? ($signed(18'sd256) - $signed({1'b0, search_mid})) : (-$signed({1'b0, search_mid}));
    // Actually, $signed(search_mid) works if search_mid is a variable.
    // Let's just use explicit casting.
    
    // Let's assume `search_mid` is 16 bit unsigned.
    // We want to do signed arithmetic.
    // We should declare search_mid as signed.
    // reg signed [15:0] search_mid;
    // Then -search_mid is signed.
    // And 18'sd256 - search_mid is signed.
    
    // Let's change search_mid to signed.
    
    // Also, best_val_scaled should be signed? No, it's the answer 0..256.
    
    // Let's update the declarations.

    // Re-declare signed regs
    reg signed [15:0] search_mid;
    
    // We need to check if Icarus supports unpacked array indexing with variable.
    // If it fails, we might need to use a flattened array or manual indexing.
    // But let's try this first.

    // Output assignments
    // start_idx: 8 bit, 1-based.
    // length: 8 bit.
    // done: 1 bit.

    // We need to make sure we don't have multiple drivers for start_idx, length.
    // We assign them in the sequential block.
    // Only in OUTPUT_RES state.
    
    // One more thing: The prompt says "Inputs: s: [7:0] array [255:0]".
    // This means s[0] to s[255].
    // My code uses s_reg[0] to s_reg[255]. Correct.

    // Final check on states:
    // IDLE -> start -> STORE_S
    // STORE_S -> i=255 -> SEARCH_SETUP
    // SEARCH_SETUP -> check bounds -> FEAS_CHECK
    // FEAS_CHECK -> j=N -> UPDATE_BEST
    // UPDATE_BEST -> SEARCH_SETUP (loop)
    // SEARCH_SETUP -> (done) -> OUTPUT_RES
    // OUTPUT_RES -> DONE_STATE -> WAIT_DONE -> IDLE
    
    // In UPDATE_BEST, we update search_iter.
    // In SEARCH_SETUP, we check search_iter < MAX_ITER.
    
    // What if search_low > search_high before MAX_ITER?
    // We check `search_low <= search_high` in SEARCH_SETUP.
    
    // What if k=0?
    // In IDLE: if (k == 0) k_reg <= 1; else k_reg <= k;
    
    // What if k > 256?
    // In SEARCH_SETUP: if (k_reg > 9'd256) next_state = OUTPUT_RES;
    
    // What about the initial best solution?
    // If no solution is found (e.g. all zeros, k>1), best_len remains 0.
    // This is correct.
    
    // One small optimization: 
    // If we find a feasible solution, we update best_val_scaled.
    // But we might find the same density with a longer subarray.
    // Since we are maximizing density, and we update best_len/feas_len 
    // during the check, we should be good.
    
    // Let's code the missing parts in the always blocks.
    
    // We need to add the internal regs to the module body.

    // I will assemble the final code now.

endmodule
