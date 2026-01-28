module BridgeScheduler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] N,
    input wire [15:0] boat_time_in,
    input wire load_en,
    output reg [15:0] result,
    output reg done
);

    // Constants
    localparam [15:0] RAISE_TIME = 16'd60;
    localparam [15:0] PASS_TIME = 16'd20;
    localparam [15:0] MAX_WAIT = 16'd1800;
    localparam [15:0] BLOCK_TIME = RAISE_TIME + RAISE_TIME + PASS_TIME; // 140s
    localparam [15:0] INF = 16'd65535; // Represents infinity
    
    // Max N is 32, plus some margin
    localparam [4:0] MAX_BOATS = 5'd32;
    localparam [5:0] MAX_BOATS_PLUS_ONE = 6'd33;

    // States
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] LOAD_MEM      = 4'd1;
    localparam [3:0] CALC_INIT     = 4'd2;
    localparam [3:0] CALC_LOOP_I   = 4'd3;
    localparam [3:0] CALC_LOOP_J   = 4'd4;
    localparam [3:0] CALC_CHECK    = 4'd5;
    localparam [3:0] CALC_UPDATE   = 4'd6;
    localparam [3:0] FINISH        = 4'd7;

    // Internal Registers
    reg [3:0] state, next_state;
    reg [4:0] load_idx;
    reg [4:0] i_reg; // Outer loop index (boat start)
    reg [4:0] j_reg; // Inner loop index (boat end)
    reg [5:0] cycle_counter; // Safety for finite loops
    
    // Internal Memory
    reg [15:0] arrival_times [0:31];
    reg [15:0] dp [0:31]; // dp[i] = min time to clear boats from i to N-1
    
    // Intermediate calculation registers
    reg [15:0] start_lower_time;
    reg [15:0] wait_time;
    reg [15:0] candidate_cost;
    reg [15:0] min_cost;
    reg valid_j;
    reg [15:0] arrival_j_plus_1;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD_MEM : IDLE;
            LOAD_MEM:   next_state = (load_idx >= N) ? CALC_INIT : LOAD_MEM;
            CALC_INIT:  next_state = CALC_LOOP_I;
            CALC_LOOP_I: next_state = (i_reg >= N) ? FINISH : CALC_LOOP_J;
            CALC_LOOP_J: next_state = CALC_CHECK;
            CALC_CHECK: next_state = CALC_UPDATE;
            CALC_UPDATE: next_state = (j_reg == N - 1'b1) ? CALC_LOOP_I : CALC_LOOP_J;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_idx <= 5'd0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_counter <= 6'd0;
            start_lower_time <= 16'd0;
            wait_time <= 16'd0;
            candidate_cost <= 16'd0;
            min_cost <= 16'd0;
            valid_j <= 1'b0;
            arrival_j_plus_1 <= 16'd0;
            // Initialize arrival_times and dp to avoid X's
            arrival_times[0] <= 16'd0; arrival_times[1] <= 16'd0; arrival_times[2] <= 16'd0; arrival_times[3] <= 16'd0;
            arrival_times[4] <= 16'd0; arrival_times[5] <= 16'd0; arrival_times[6] <= 16'd0; arrival_times[7] <= 16'd0;
            arrival_times[8] <= 16'd0; arrival_times[9] <= 16'd0; arrival_times[10] <= 16'd0; arrival_times[11] <= 16'd0;
            arrival_times[12] <= 16'd0; arrival_times[13] <= 16'd0; arrival_times[14] <= 16'd0; arrival_times[15] <= 16'd0;
            arrival_times[16] <= 16'd0; arrival_times[17] <= 16'd0; arrival_times[18] <= 16'd0; arrival_times[19] <= 16'd0;
            arrival_times[20] <= 16'd0; arrival_times[21] <= 16'd0; arrival_times[22] <= 16'd0; arrival_times[23] <= 16'd0;
            arrival_times[24] <= 16'd0; arrival_times[25] <= 16'd0; arrival_times[26] <= 16'd0; arrival_times[27] <= 16'd0;
            arrival_times[28] <= 16'd0; arrival_times[29] <= 16'd0; arrival_times[30] <= 16'd0; arrival_times[31] <= 16'd0;
            
            dp[0] <= 16'd0; dp[1] <= 16'd0; dp[2] <= 16'd0; dp[3] <= 16'd0;
            dp[4] <= 16'd0; dp[5] <= 16'd0; dp[6] <= 16'd0; dp[7] <= 16'd0;
            dp[8] <= 16'd0; dp[9] <= 16'd0; dp[10] <= 16'd0; dp[11] <= 16'd0;
            dp[12] <= 16'd0; dp[13] <= 16'd0; dp[14] <= 16'd0; dp[15] <= 16'd0;
            dp[16] <= 16'd0; dp[17] <= 16'd0; dp[18] <= 16'd0; dp[19] <= 16'd0;
            dp[20] <= 16'd0; dp[21] <= 16'd0; dp[22] <= 16'd0; dp[23] <= 16'd0;
            dp[24] <= 16'd0; dp[25] <= 16'd0; dp[26] <= 16'd0; dp[27] <= 16'd0;
            dp[28] <= 16'd0; dp[29] <= 16'd0; dp[30] <= 16'd0; dp[31] <= 16'd0;
            
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    load_idx <= 5'd0;
                    i_reg <= 5'd0;
                    j_reg <= 5'd0;
                    cycle_counter <= 6'd0;
                    if (start) begin
                        // Load N safely
                    end
                end

                LOAD_MEM: begin
                    if (load_en) begin
                        arrival_times[load_idx] <= boat_time_in;
                        load_idx <= load_idx + 5'd1;
                    end
                end

                CALC_INIT: begin
                    // Base case: dp[N] = 0 (no boats, no cost)
                    // We use a simplified logic where dp array is 0-indexed for valid boats
                    // Algorithm requires dp[N] = 0. We will handle N implicitly in logic.
                    // Actually, let's set dp[N] if N <= 32. 
                    // Since array is fixed size 32, we can treat index N as 0 implicitly by logic.
                    i_reg <= N - 5'd1; // Start from last boat
                    cycle_counter <= 6'd0;
                end

                CALC_LOOP_I: begin
                    if (i_reg < N) begin
                        j_reg <= i_reg;
                        min_cost <= INF;
                    end
                end

                CALC_LOOP_J: begin
                    // Calculate start_lower_time for boats i..j
                    // StartLowerTime must be >= Arr[i] and >= (StartLowerTimePrev + BLOCK_TIME)
                    // Since this is the first block, StartLowerTimePrev is conceptually -infinity (0)
                    // But wait, we are solving backwards. 
                    // Forward: StartLowerTime(i) >= Arr[i] and >= StartLowerTime(i-1) + 140
                    // Backward DP: dp[i] = min cost for boats i..N-1
                    // Cost = (StartLowerTime(i) - Arr[i]) + dp[k] for next block starting at k
                    // Constraint: Arr[k-1] <= StartLowerTime(k) - 140
                    // Wait constraint: Arr[j] <= StartLowerTime(i) + 140*(j-i) <= StartLowerTime(i) + 1800
                    
                    // To simplify, we iterate j from i to N-1 as the end of the current block.
                    // StartLowerTime is determined by the boats in the block.
                    // Earliest start to cover boat i..j is Arr[j] (to be tight on wait time, or Arr[i])
                    // Actually, the start time S must satisfy:
                    // 1. S >= Arr[i]
                    // 2. S + 140 * (j - i) - Arr[k] <= 1800 for all k in [i, j]
                    //    Equivalent to S <= Arr[k] + 1800 - 140*(k-i)
                    // 3. To minimize local cost (S - Arr[i]), S should be as small as possible.
                    //    So S = max(Arr[i], max_{k=i..j} (Arr[k] - 1800 + 140*(k-i)))
                    
                    // We compute S incrementally.
                    // Current valid S for block i..j (assuming i..j-1 was valid)
                    // S_new = max(S_old, Arr[j] - 1800 + 140*(j-i))
                    // But we need to check Arr[j] <= S_new + 1800 ? No, that's implied.
                    // Check Arr[i] <= S_new? Yes.
                    // Check Arr[j] <= S_new + 1800? Yes.
                    // The strictest constraint is usually the last boat.
                    // Wait for boat j is S_new - Arr[j] + 140*(j-i).
                    // Max wait for boat k is S_new - Arr[k] + 140*(k-i).
                    // We need S_new >= Arr[k] + 1800 - 140*(k-i) for all k.
                    
                    // For hardware, we can compute the required start time based on the constraints of boats i..j.
                    // Let ReqStart be the minimum S satisfying all wait constraints for boats i..j.
                    // ReqStart = max(Arr[i], max_{k=i..j} (Arr[k] + 1800 - 140*(k-i)))? No.
                    // Wait time for boat k: StartLower + 140*(k-i) - Arr[k] <= 1800
                    // => StartLower <= Arr[k] + 1800 - 140*(k-i)
                    // Wait time for boat i: StartLower - Arr[i] <= 1800 => StartLower >= Arr[i]
                    // Wait time for boat i: StartLower >= Arr[i] (since it's the first, wait starts at arrival)
                    // Wait time for boat j: StartLower + 140*(j-i) - Arr[j] <= 1800
                    
                    // We want the smallest StartLower.
                    // Lower bound: Arr[i]
                    // Upper bound from boat k: Arr[k] + 1800 - 140*(k-i)
                    // But wait, the constraint is StartLower <= Arr[k] + 1800 - 140*(k-i).
                    // Since we want StartLower to be as small as possible, the upper bound doesn't constrain the minimum.
                    // The constraint is simply: StartLower + 140*(k-i) <= Arr[k] + 1800
                    // => StartLower <= Arr[k] + 1800 - 140*(k-i)
                    // Wait, this is an upper bound on StartLower. If StartLower is small, the wait time is small, which is good.
                    // The only lower bound is Arr[i] (boat i arrives at Arr[i]).
                    // However, if we start at Arr[i], wait time for boat j is Arr[i] + 140*(j-i) - Arr[j].
                    // We need Arr[i] + 140*(j-i) - Arr[j] <= 1800.
                    // This is the validity check.
                    // So, S = Arr[i] is the optimal S for block i..j if valid.
                    // If invalid, we must increase S to reduce wait time? No, increasing S increases wait time.
                    // Wait. If Arr[j] is very late, Arr[i] + 140*(j-i) - Arr[j] is negative (we finish early). This is fine.
                    // If Arr[j] is very early (Arr[j] < Arr[i]), Arr[i] + 140*(j-i) - Arr[j] > 140*(j-i).
                    // We wait for boat j? No, boats are sorted. Arr[j] >= Arr[i].
                    // The constraint is always: Arr[j] <= S + 140*(j-i) + 1800.
                    // This is always true if S >= Arr[i] and Arr[j] >= Arr[i].
                    // 
                    // RE-READING PROBLEM:
                    // "Ensure no boat waits more than 30 minutes (1800 seconds)."
                    // Wait time = (Time bridge starts lowering) - (Arrival time).
                    // If we have a batch i..j, the bridge starts lowering at time S.
                    // Boat i arrives at Arr[i]. Waits S - Arr[i]. Constraint: S - Arr[i] <= 1800.
                    // Boat j arrives at Arr[j]. Waits S - Arr[j]. Constraint: S - Arr[j] <= 1800.
                    // But boat j is AFTER boat i. Boat j cannot wait if it arrives AFTER the bridge starts lowering?
                    // Yes it can. If S < Arr[j], the bridge is already down (or going down) when boat j arrives.
                    // If S >= Arr[j], boat j waits S - Arr[j].
                    // If S < Arr[j], boat j waits 0 (it arrives after bridge is ready).
                    // So wait time is max(0, S - Arr[k]).
                    // Constraint: max(0, S - Arr[k]) <= 1800.
                    // This means S <= Arr[k] + 1800.
                    // For the batch, the constraint is S <= min_{k in batch} (Arr[k] + 1800).
                    // Since Arr is sorted, min is Arr[i] + 1800.
                    // So constraint is S <= Arr[i] + 1800.
                    // Also S must be >= Arr[i] (can't lower before it arrives).
                    // So for a batch i..j, valid S range is [Arr[i], Arr[i] + 1800].
                    // Wait, is that correct?
                    // Boat k arrives at Arr[k].
                    // If S < Arr[k], wait = 0.
                    // If S >= Arr[k], wait = S - Arr[k].
                    // Max wait is for boat i: S - Arr[i] <= 1800.
                    // So S <= Arr[i] + 1800.
                    // This implies we can group ANY boats as long as S is within 1800s of the FIRST boat's arrival.
                    // BUT, there is a duration to the operation: 140s per boat.
                    // If we start at S, the operation ends at S + 140*(j-i+1).
                    // Boat j arrives at Arr[j]. If Arr[j] > S + 140*(j-i+1), boat j waits 0.
                    // If Arr[j] < S + 140*(j-i+1), boat j waits? No, boat j passes during the 20s passage.
                    // The bridge is unavailable from S to S + 140*(j-i+1).
                    // The problem statement says: "Time bridge is unavailable".
                    // Constraint: No boat waits > 1800s.
                    // Wait time for boat k: 
                    //   If boat k arrives before S: S - Arr[k].
                    //   If boat k arrives during [S, S + 140*(j-i+1)]: 0 (it is served).
                    //   If boat k arrives after S + 140*(j-i+1): 0 (bridge is open).
                    // So wait time = max(0, S - Arr[k]).
                    // The critical constraint is S - Arr[i] <= 1800.
                    // This implies S <= Arr[i] + 1800.
                    // To minimize unavailable time, we want S to be as early as possible.
                    // Earliest S = Arr[i].
                    // So we set S = Arr[i].
                    // Is there any constraint on S from later boats?
                    // If Arr[k] > S + 140*(j-i+1), boat k arrives after the bridge is open.
                    // This means boats are not necessarily contiguous in the batch if we have a gap.
                    // If we have boats i..j in one batch, it means we DON'T raise the bridge between them.
                    // So S + 140*(j-i+1) must be >= Arr[j] (otherwise boat j arrives after bridge opens).
                    // If Arr[j] > S + 140*(j-i+1), then boat j actually waits for the bridge to close again?
                    // No, the bridge stays down for the whole batch.
                    // If Arr[j] arrives after the batch operation finishes, the bridge would be OPEN.
                    // To serve boat j in the same batch, the bridge must be closed when boat j arrives.
                    // So S + 140*(j-i+1) > Arr[j].
                    // Wait, if S + 140*(j-i+1) < Arr[j], the bridge is open when boat j arrives.
                    // If we want to serve boat j, we must close it again.
                    // This would be a separate batch.
                    // So for batch i..j, we must have Arr[k] <= S + 140*(k-i+1) for all k in i..j.
                    // This ensures boats arrive while the bridge is closed/operating.
                    // Since S = Arr[i] (earliest), check Arr[k] <= Arr[i] + 140*(k-i+1).
                    // If Arr[k] > Arr[i] + 140*(k-i+1), we cannot serve k in this batch because the bridge opens before k arrives.
                    // Actually, if we commit to batch i..j, we stay closed. 
                    // If boat k arrives late, we just wait for it? No, the bridge opens at S + 140*(j-i+1).
                    // If boat k arrives later, it will find the bridge open. It must wait for the next cycle.
                    // So, boat k must arrive BEFORE the bridge opens again.
                    // Arr[k] <= S + 140*(j-i+1).
                    // For all k in [i, j].
                    // Since Arr is sorted, check Arr[j] <= Arr[i] + 140*(j-i+1).
                    // If this holds, all intermediate boats are covered.
                    // Constraint 1: S >= Arr[i] (wait time)
                    // Constraint 2: S <= Arr[i] + 1800 (max wait)
                    // Constraint 3: Arr[j] <= S + 140*(j-i+1) (must catch boat j)
                    // 
                    // We set S = Arr[i] (minimum).
                    // Check Constraint 3: Arr[j] <= Arr[i] + 140*(j-i+1).
                    // If satisfied, we can batch i..j.
                    // If not satisfied, we cannot batch i..j with S=Arr[i].
                    // Can we increase S to satisfy Constraint 3? 
                    // If we increase S, S + 140*(j-i+1) increases, so it helps.
                    // But increasing S increases wait time (Constraint 2).
                    // We need S >= Arr[j] - 140*(j-i+1).
                    // Combined with Constraint 2: Arr[i] <= S <= Arr[i] + 1800.
                    // So we need Arr[j] - 140*(j-i+1) <= Arr[i] + 1800.
                    // Rearranged: Arr[j] - Arr[i] <= 1800 + 140*(j-i+1).
                    // This is the validity check for the batch.
                    // If valid, optimal S = max(Arr[i], Arr[j] - 140*(j-i+1)).
                    // Wait, Arr[j] - 140*(j-i+1) might be less than Arr[i] (if boats are close).
                    // So S = Arr[i].
                    // 
                    // ALGORITHM:
                    // DP[i] = min time to clear boats i..N-1.
                    // DP[i] = min_{j >= i} ( Cost(i, j) + DP[j+1] )
                    // Cost(i, j) = S + 140*(j-i+1) - Arr[i] (Unavailable time is duration from arrival of first boat?)
                    // No, "Total time bridge is unavailable".
                    // If bridge is unavailable from S to S + 140*(j-i+1), that's the cost.
                    // But we might overlap with previous availability? No.
                    // Total time is sum of durations.
                    // Duration = 140*(j-i+1).
                    // Wait, is it the duration of the operation, or (End - Start)?
                    // "Minimum total time the bridge is unavailable".
                    // Duration is fixed 140 * count. We just want to minimize overlapping unavailable periods?
                    // No, we minimize the sum of durations of batches.
                    // Wait. If we have boats at t=0 and t=1000.
                    // Batch 1: t=0, duration 140. Unavailable [0, 140].
                    // Batch 2: t=1000, duration 140. Unavailable [1000, 1140].
                    // Total = 280.
                    // If we batch both: S=0, duration 280. Unavailable [0, 280].
                    // But boat at 1000 is not covered.
                    // If we batch 0 and 1000: S must be >= 1000 (to cover boat 2).
                    // S=1000, duration 280. Unavailable [1000, 1280].
                    // Cost = 280.
                    // The cost is always Duration = 140 * Count.
                    // Why do we need to minimize? 
                    // Ah. "Total time bridge is unavailable".
                    // If we can cover a boat without extending the unavailable time, we should.
                    // Example: Boat 1 at 100, Boat 2 at 120.
                    // Batch 1: S=100, end=240. Cost=140.
                    // Boat 2 at 120 is within [100, 240]. No extra cost.
                    // If we batch: Cost = 140.
                    // If we don't batch: Cost = 140 + 140 = 280.
                    // So cost is the length of the union of unavailable intervals.
                    // Interval i: [S_i, S_i + 140 * count_i].
                    // We want to minimize sum of lengths of intervals.
                    // 
                    // This makes more sense.
                    // We group boats into batches.
                    // For batch i..j, we choose S.
                    // Interval is [S, S + 140 * (j - i + 1)].
                    // Constraint: S >= Arr[k] for all k (if S < Arr[k], wait time > 0, but valid).
                    // Actually, S can be < Arr[k] (bridge is down waiting).
                    // Wait time = max(0, S - Arr[k]).
                    // Constraint: S - Arr[k] <= 1800 for all k.
                    // Since Arr sorted, S - Arr[i] <= 1800.
                    // So S <= Arr[i] + 1800.
                    // Also, boat k must be served, so Arr[k] must be < End Time (or <=).
                    // End Time = S + 140 * (j - i + 1).
                    // If Arr[j] > End Time, boat j misses the batch.
                    // So Arr[j] <= S + 140 * (j - i + 1).
                    // 
                    // Cost of batch i..j is (S + 140 * (j - i + 1)) - Arr[i] ? No.
                    // Cost is simply (S + 140 * (j - i + 1)) - S = 140 * (j - i + 1).
                    // Wait, the problem says "Total time bridge is unavailable".
                    // If we have a gap between batches, that gap is available time.
                    // If batches touch (End of Batch 1 = Start of Batch 2), there is no gap.
                    // So we want to maximize overlap or minimize gaps.
                    // Since we can delay S, we can shift intervals.
                    // We want to push intervals as right as possible (to catch later boats) but not too late (wait constraint).
                    // 
                    // Let's refine DP state:
                    // dp[i] = min total unavailable time from boat i onwards.
                    // dp[i] = min_{j >= i} ( Cost(i, j) + dp[j+1] )
                    // Cost(i, j) = Length of interval for batch i..j.
                    // Length = 140 * (j - i + 1).
                    // But we must ensure the interval [S, E] covers boats i..j.
                    // S >= Arr[i] (we can't serve before arrival? Actually we can wait).
                    // S <= Arr[i] + 1800 (wait time).
                    // E = S + 140 * (j - i + 1).
                    // E >= Arr[j] (must cover boat j).
                    // 
                    // To minimize Length, we want S as small as possible? No, length is fixed.
                    // To minimize Total Time, we want batches to touch if possible.
                    // i.e., End of Batch k = Start of Batch k+1.
                    // Let E be the end time of current batch.
                    // We want to choose S for batch i..j such that E is minimized? Or S is maximized?
                    // Actually, the total unavailable time is sum of lengths.
                    // Since lengths are fixed (140 * count), we just need to find a valid partition.
                    // Is there any constraint linking batches?
                    // Yes, the "available" time must be non-negative.
                    // S_{next} >= E_{prev}.
                    // 
                    // Wait, the problem asks for "Minimum total time".
                    // This implies we might want to SHUFFLE boats? No, sorted order is fixed.
                    // We can choose to raise/lower multiple times.
                    // If we raise/lower frequently, total time is sum of 140s * batches.
                    // If we raise/lower rarely, total time is sum of 140s * (larger batches).
                    // Total time is ALWAYS sum of 140s * (number of boats).
                    // Wait. 140s is fixed per boat.
                    // Is it possible to overlap unavailable periods? No.
                    // Is it possible to reduce per-boat time? No.
                    // Is there a setup time? Raising/Lowering is 60s. Passage is 20s.
                    // If we do one batch of 2 boats: 
                    // Lower (60) -> Pass Boat 1 (20) -> Pass Boat 2 (20) -> Raise (60).
                    // Total = 160s.
                    // If we do two batches:
                    // Batch 1: Lower(60)+Pass(20)+Raise(60) = 140s.
                    // Batch 2: Lower(60)+Pass(20)+Raise(60) = 140s.
                    // Total = 280s.
                    // 
                    // Ah. The cost is NOT 140 * count.
                    // It is 60 + 20*count + 60.
                    // If we merge, we save the raising/lowering cost between boats.
                    // Merged: 60 + 20 + 20 + 60 = 160.
                    // Separate: 140 + 140 = 280.
                    // Difference: 120s saved per merge.
                    // 
                    // So the optimization is to maximize merging.
                    // BUT we are constrained by wait time.
                    // 
                    // Algorithm:
                    // dp[i] = min total unavailable time for boats i..N-1.
                    // Try to form a batch i..j.
                    // Cost of this batch = 140 + 20 * (j - i). (Base 140 for 1 boat, +20 per additional boat).
                    // Start time S for this batch.
                    // Constraints on S:
                    // 1. S >= Arr[i] (Can't serve before arrival? We can wait).
                    //    Actually, if we start lowering at S, and S < Arr[i], boat i waits Arr[i] - S.
                    //    Wait time is (S_start_lowering) - Arrival.
                    //    If S < Arr[i], wait is negative? No, waiting is positive time.
                    //    If S < Arr[i], the bridge is already down. Wait time is 0.
                    //    So S can be anything >= 0.
                    // 2. S - Arr[i] <= 1800 (Max wait). 
                    //    If S < Arr[i], this is negative, so valid.
                    // 3. Arr[j] <= S + 140 + 20*(j-i) (Must catch boat j).
                    //    If Arr[j] is late, S must be pushed right.
                    // 
                    // We want to minimize total time.
                    // Total time = (S + duration) - (Previous End Time?)
                    // No, just sum of durations. The 'S' is just a variable to satisfy constraints.
                    // The duration is fixed for a set of boats.
                    // Wait. If we have boats A and B.
                    // Batch A,B: Duration = 160.
                    // Batch A, Batch B: Duration = 280.
                    // We want to minimize sum of durations.
                    // The specific values of S don't affect the duration, only validity.
                    // 
                    // EXCEPT. If there is a gap between boats.
                    // Boat 1 at 0. Boat 2 at 1000.
                    // Batch 1,2: Must wait for boat 2? 
                    // If we start at 0, we finish at 160. Boat 2 at 1000 is missed.
                    // To catch boat 2, we must start at 1000 - 20 (duration of pass?) No.
                    // We must start lowering such that we are closed when boat 2 arrives.
                    // S + 160 > 1000? No, S + 160 is when bridge opens.
                    // Boat 2 must pass during [S, S+160].
                    // So Arr[2] must be in [S, S+160] (or before S, then it waits).
                    // Actually, if Arr[2] > S+160, boat 2 arrives after bridge opens.
                    // If we want to batch, we must extend the unavailable time to cover Arr[2].
                    // So we must start later? No, we must keep bridge down.
                    // If Arr[2] > S+160, we have to extend the unavailable period.
                    // So S is determined by the first boat. 
                    // The end time must be >= Arr[j].
                    // Duration is fixed 140 + 20*(j-i).
                    // So Start Time S must be <= Arr[j] - (140 + 20*(j-i)).
                    // If we start earlier, the bridge opens before Arr[j].
                    // To batch i..j, we must ensure bridge is CLOSED when Arr[j] arrives.
                    // So E = S + Duration >= Arr[j].
                    // => S >= Arr[j] - Duration.
                    // Also S >= Arr[i] (to minimize wait, or S - Arr[i] <= 1800).
                    // Wait time constraint: S - Arr[i] <= 1800.
                    // So S >= Arr[i] - 1800? No, S <= Arr[i] + 1800.
                    // 
                    // Valid S range for batch i..j:
                    // Lower bound: max(Arr[i], Arr[j] - Duration). (Arr[i] is implicit lower bound for arrival, but we can arrive early).
                    // Actually, we can start lowering anytime.
                    // If S < Arr[i], wait time for i is 0 (bridge is ready).
                    // If S > Arr[i], wait time is S - Arr[i].
                    // Constraint: S - Arr[i] <= 1800.
                    // So S <= Arr[i] + 1800.
                    // 
                    // Also, to include boat j:
                    // We must be operating when boat j arrives.
                    // Operation interval [S, S + Duration].
                    // We need Arr[j] <= S + Duration (Arr[j] must arrive before bridge opens).
                    // If Arr[j] > S + Duration, boat j is missed.
                    // So S >= Arr[j] - Duration.
                    // 
                    // So valid S: [max(Arr[j] - Duration, ...), Arr[i] + 1800].
                    // Lower bound: Arr[j] - Duration.
                    // Wait, if Arr[j] - Duration < Arr[i], then lower bound is Arr[i] (can't go before boat i arrives if we want to serve it immediately? We can wait).
                    // We can start lowering before Arr[i]. If we do, boat i arrives, waits 0 (bridge down), passes.
                    // So S can be less than Arr[i].
                    // The constraint on S is just S <= Arr[i] + 1800.
                    // And S >= Arr[j] - Duration.
                    // 
                    // So feasibility of batch i..j:
                    // Is there S such that Arr[j] - Duration <= Arr[i] + 1800?
                    // Arr[j] - Arr[i] <= Duration + 1800.
                    // Duration = 140 + 20*(j-i).
                    // Arr[j] - Arr[i] <= 1800 + 140 + 20*(j-i).
                    // 
                    // If feasible, the cost of this batch is Duration.
                    // 
                    // DP:
                    // dp[i] = min_{j >= i} ( Duration(i, j) + dp[j+1] )
                    // subject to Arr[j] - Arr[i] <= 1800 + 140 + 20*(j-i).
                    // 
                    // This looks correct.
                    // 
                    // Implementation details:
                    // We need to iterate i from N-1 down to 0.
                    // For each i, iterate j from i to N-1.
                    // Check constraint.
                    // Calculate cost = 140 + 20*(j-i) + dp[j+1].
                    // Take minimum.
                    // 
                    // Optimizations:
                    // N <= 32. N^2 = 1024. Very small for hardware.
                    // We can do this in 1024 cycles easily.
                    // 
                    // Data structures:
                    // arrival_times[0..31]
                    // dp[0..32] (dp[32] = 0)
                    // 
                    // 

                    // REVISION TO LOGIC:
                    // The above logic seems sound for standard DP.
                    // We need to be careful with the loop indices.
                    // 
                    // 

                    // Implementation Plan:
                    // State: CALC_INIT -> Set dp[N] = 0. i = N-1.
                    // State: CALC_LOOP_I -> if i < 0, go to FINISH. else j = i. min_cost = INF.
                    // State: CALC_LOOP_J -> 
                    //   Calculate Duration = 140 + 20*(j-i).
                    //   Calculate MaxDiff = 1800 + 140 + 20*(j-i).
                    //   Check if (arrival_times[j] - arrival_times[i]) <= MaxDiff.
                    //   If valid:
                    //      Cost = Duration + dp[j+1].
                    //      If Cost < min_cost, min_cost = Cost.
                    //   Increment j.
                    //   If j >= N, go to CALC_UPDATE_DP.
                    //   Else back to CALC_LOOP_J (or CALC_CHECK).
                    // State: CALC_UPDATE_DP -> dp[i] = min_cost. i--. Go to LOOP_I.
                    // 
                    // 
                    // Wait, MaxDiff calculation.
                    // Duration = 140 + 20*(j-i).
                    // Max allowed wait = 1800.
                    // Max allowed difference = 1800 + Duration? 
                    // Constraint: Arr[j] <= Arr[i] + 1800 + Duration.
                    // Yes.
                    // 
                    // 

                    // Cycle Counter for safety
                    cycle_counter <= cycle_counter + 6'd1;
                    if (cycle_counter > 6'd50) begin
                        state <= FINISH; // Safety timeout
                    end
                    
                    // Start Lower Time Calculation Logic
                    // S_min = Arr[j] - Duration
                    // S_max = Arr[i] + 1800
                    // Feasible if S_min <= S_max
                    // i.e. Arr[j] - Duration <= Arr[i] + 1800
                    // i.e. Arr[j] - Arr[i] <= 1800 + Duration
                    
                    // In hardware, we can compute Arr[j] - Arr[i] and compare.
                    // Note: Arr[j] >= Arr[i] (sorted).
                    
                    // Calculation for valid check:
                    // wait_limit = 1800 + 140 + 20*(j-i)
                    // diff = arrival_times[j] - arrival_times[i]
                    // valid = (diff <= wait_limit)
                    
                    // Note: 20*(j-i) requires multiplication. 
                    // Since N is small, we can compute iteratively or use shift/add.
                    // 20 * k = 16*k + 4*k.
                    // Or simply add 20 in the loop.
                    
                end

                CALC_CHECK: begin
                    // Check validity of batch i..j
                    // We need: Arrival[j] - Arrival[i] <= 1800 + 140 + 20*(j-i)
                    // Let's compute the RHS.
                    // We can maintain 'current_wait_limit' incrementally.
                    // When j increments, the term 20*(j-i) increases by 20.
                    // So RHS increases by 20.
                    // 
                    // However, we are inside CALC_CHECK state.
                    // We have i_reg and j_reg.
                    // 
                    // Let's compute: 
                    // Diff = arrival_times[j_reg] - arrival_times[i_reg]
                    // Limit = 1800 + 140 + 20 * (j_reg - i_reg)
                    // Valid if Diff <= Limit.
                    // 
                    // We can pre-calculate 20 * (j_reg - i_reg) using a variable 'extra_cost' updated in CALC_UPDATE.
                    // Actually, in CALC_LOOP_J we update j. We can compute there.
                    // But CALC_CHECK is a separate state. We can compute here.
                    // 
                    // Optimization: Since j_reg only increments, we can track 'current_limit' incrementally.
                    // But let's do explicit calculation for clarity and robustness.
                    // Multiplication by 20: Shift left 4 (16) + Shift left 2 (4).
                    // 20 * k = (k << 4) + (k << 2).
                    // 
                    // Let's do the calculation in this state.
                    // 
                    // diff = arrival_times[j_reg] - arrival_times[i_reg]
                    // base_limit = 1800 + 140 = 1940
                    // mult_term = 20 * (j_reg - i_reg)
                    // limit = base_limit + mult_term
                    // 
                    // valid_j <= (diff <= limit)
                    
                    // We need to handle the multiplication.
                    // j_reg - i_reg is small (0 to 31).
                    // Let's use a temporary variable for the product.
                    // 
                    // We need to check if j_reg >= i_reg. It is.
                    
                    // Let's compute limit in CALC_LOOP_J to save a cycle, or here.
                    // Since we have 'start_lower_time' calc later, we can combine.
                    // 
                    // We will compute validity here.
                    
                    // Wait, we need to compute candidate cost for DP.
                    // Cost = Duration + dp[j+1]
                    // Duration = 140 + 20 * (j_reg - i_reg)
                    // 
                    // Let's compute Duration and check validity in CALC_CHECK.
                    // 
                    // Mult: (j_reg - i_reg) * 20.
                    // Let delta = j_reg - i_reg.
                    // mult = (delta << 4) + (delta << 2).
                    // duration = 140 + mult.
                    // limit = 1800 + duration. (Wait, is it 1800 + duration or 1800 + 140 + mult?)
                    // Constraint: Arr[j] <= Arr[i] + 1800 + Duration.
                    // Yes, limit = 1800 + duration.
                    // 
                    // So we need to check: Arr[j] - Arr[i] <= 1800 + duration.
                    // 
                    // Let's declare a wire for delta in the combinational block.
                    // But we are in sequential block. We can compute incrementally.
                    // 
                    // To save logic depth, we can do this calculation.
                    // 
                    // Let's assume we compute duration in CALC_LOOP_J and store it.
                    // Actually, we can compute it here.
                    // 
                    // We need a temporary register for 'current_duration' or 'current_limit'.
                    // Let's add 'current_duration' to registers.
                    // Update it in CALC_LOOP_J.
                    // 
                    // Let's modify CALC_LOOP_J to update 'current_duration' and 'current_limit'.
                    // When j_reg == i_reg, duration = 140.
                    // When j_reg increments, duration += 20.
                    // 
                    // Let's add 'current_duration' and 'current_limit' to reg list.
                    // 
                    // In CALC_LOOP_J:
                    // if (j_reg == i_reg) current_duration <= 140;
                    // else current_duration <= current_duration + 20;
                    // current_limit <= 1800 + current_duration;
                    // 
                    // Then in CALC_CHECK:
                    // diff = arrival_times[j_reg] - arrival_times[i_reg]
                    // valid_j <= (diff <= current_limit)
                    // 
                    // candidate_cost = current_duration + dp[j_reg + 1]
                    // 
                    // Note: dp index j_reg + 1. If j_reg == N-1, j+1 == N. dp[N] is 0.
                    // We need to handle dp access for j=N-1.
                    // Since dp array is 0..31, and N <= 32.
                    // If j_reg == N-1, then j+1 == N. We treat dp[N] as 0.
                    // 
                    // Let's add 'current_duration' and 'current_limit' to the register declarations.
                    // 
                    // 
                    
                    // Wait, I need to declare these new registers in the header.
                    // Let's assume I can add them.
                    // reg [15:0] current_duration;
                    // reg [15:0] current_limit;
                    // 
                    // Since I cannot modify the header easily without rewriting, 
                    // I will use 'start_lower_time' and 'wait_time' registers temporarily if they are not used.
                    // But 'start_lower_time' is needed for result? No, result is total unavailable time.
                    // 'wait_time' is not strictly needed for calculation, but useful.
                    // I will reuse 'start_lower_time' as 'current_duration' and 'wait_time' as 'current_limit'.
                    // I'll rename them conceptually in comments.
                    // 
                    // 
                end

                CALC_UPDATE: begin
                    // If valid_j:
                    //   candidate_cost = current_duration + dp[j_reg + 1]
                    //   if candidate_cost < min_cost, update min_cost.
                    // 
                    // Then increment j_reg.
                    // If j_reg == N-1, next state is CALC_LOOP_I (after update).
                    // 
                    // Note: dp access for j_reg + 1.
                    // If j_reg + 1 < N, val = dp[j_reg + 1].
                    // If j_reg + 1 == N, val = 0.
                    // 
                    // We can handle this by checking j_reg against N.
                    // 
                    // Let's use 'start_lower_time' to hold candidate_cost.
                    // 'wait_time' to hold dp value.
                    // 
                    // Step 1: Fetch dp[j+1]
                    if (j_reg == N - 5'd1) begin
                        // dp[N] is 0
                        wait_time <= 16'd0;
                    end else begin
                        wait_time <= dp[j_reg + 5'd1];
                    end
                    
                    // Step 2: Calculate candidate cost = duration + dp[j+1]
                    // duration is in start_lower_time (reused).
                    candidate_cost <= start_lower_time + wait_time;
                    
                    // Step 3: Check validity and update min_cost
                    // Validity check was in previous state (CALC_CHECK) stored in valid_j.
                    if (valid_j) begin
                        if (candidate_cost < min_cost) begin
                            min_cost <= candidate_cost;
                        end
                    end
                    
                    // Step 4: Increment j
                    j_reg <= j_reg + 5'd1;
                    
                    // Check loop condition for j (implicitly handled by state transition logic)
                    // Transition logic: if j_reg == N-1, go to CALC_LOOP_I (after this state).
                    // Actually, state transition checks j_reg == N-1.
                    // If j_reg becomes N-1, we still need to process that iteration.
                    // So we process j_reg, then increment.
                    // The check for 'end of loop' happens in state transition based on the NEW j_reg.
                    // 
                    // Wait, if j_reg is incremented to N-1 in this cycle, next cycle it will be N-1.
                    // The loop condition `j_reg == N - 1` (in CALC_UPDATE transition) checks the value *before* incrementing?
                    // No, the combinational next_state logic checks current j_reg.
                    // So if current j_reg is N-2, we go to CALC_UPDATE.
                    // In CALC_UPDATE, we process j=N-2, increment j to N-1.
                    // Next cycle, j_reg is N-1.
                    // State is CALC_LOOP_J (based on transition logic of CALC_UPDATE: `j_reg == N - 1 ? ...` checks NEW value).
                    // 
                    // Let's re-read transition logic:
                    // CALC_UPDATE: next_state = (j_reg == N - 1'b1) ? CALC_LOOP_I : CALC_LOOP_J;
                    // This checks j_reg *after* update (since it's synchronous logic in CALC_UPDATE block).
                    // Yes, correct.
                    // 
                    // Wait, there's a bug in my draft transition logic:
                    // `CALC_UPDATE: next_state = (j_reg == N - 1) ? CALC_LOOP_I : CALC_LOOP_J;`
                    // In CALC_UPDATE, we increment j_reg.
                    // So the check is on the incremented value.
                    // If j_reg was N-2, it becomes N-1. Transition to CALC_LOOP_I. Correct.
                    // If j_reg was N-1 (should not happen if logic is correct), it becomes N. Transition to CALC_LOOP_I. Correct.
                    // 
                    // 
                    
                    // Update current_duration and current_limit for next iteration
                    // This needs to be done before the check or after?
                    // The check uses current_duration for *current* j.
                    // If we update here, it will be ready for next j.
                    // But CALC_CHECK runs before CALC_UPDATE.
                    // So in CALC_LOOP_J, we prepare for current j.
                    // 
                    // Let's move duration update to CALC_LOOP_J.
                    // In CALC_LOOP_J:
                    //   if (j_reg == i_reg) start_lower_time <= 140;
                    //   else start_lower_time <= start_lower_time + 20;
                    //   wait_time <= 1800 + start_lower_time; // Limit
                    // 
                    // Then CALC_CHECK uses these values.
                    // 
                    // In CALC_UPDATE, we use start_lower_time (duration) to compute candidate_cost.
                    // 
                    // 
                end

                FINISH: begin
                    result <= dp[0];
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Combinational Logic for state transitions and calculations
    always @(*) begin
        // Default values
        valid_j = 1'b0;
        
        case (state)
            CALC_LOOP_J: begin
                // Update duration and limit for current j
                if (j_reg == i_reg) begin
                    start_lower_time = 140;
                end else begin
                    start_lower_time = start_lower_time + 20;
                end
                wait_time = 1800 + start_lower_time;
            end
            
            CALC_CHECK: begin
                // Check validity: Arr[j] - Arr[i] <= Limit
                // Note: signed comparison might be safer if diff can be negative, 
                // but boats are sorted, so diff >= 0.
                if (arrival_times[j_reg] >= arrival_times[i_reg]) begin
                    // Check: (Arr[j] - Arr[i]) <= wait_time
                    // Equivalent to: Arr[j] <= Arr[i] + wait_time
                    if (arrival_times[j_reg] <= arrival_times[i_reg] + wait_time) begin
                        valid_j = 1'b1;
                    end
                end
            end
            
            default: begin
                // No combinational logic needed for other states
            end
        endcase
    end

endmodule