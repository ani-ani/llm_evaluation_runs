module trek_planner(
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [3:0] edge_count,
    input [5:0] edge_u,
    input [5:0] edge_v,
    input [5:0] edge_weight,
    input edge_valid,
    input compute_start,
    output reg [7:0] wait_time,
    output reg done,
    output reg error
);

    // Parameters for state machine
    localparam IDLE = 3'b000;
    localparam LOAD_EDGES = 3'b001;
    localparam COMPUTE_KNIGHT = 3'b010;
    localparam COMPUTE_DAY = 3'b011;
    localparam CALC_RESULT = 3'b100;
    localparam DONE_STATE = 3'b101;

    // Registers for state
    reg [2:0] state;
    reg [2:0] next_state;

    // Edge storage (Depth 16 for max nodes, assuming max 16 edges for simplicity)
    // Using distributed RAM style registers
    reg [5:0] edge_u_ram [0:15];
    reg [5:0] edge_v_ram [0:15];
    reg [5:0] edge_w_ram [0:15];
    reg [3:0] edge_idx;
    reg [3:0] stored_edge_count;

    // Dijkstra/DP variables
    reg [3:0] node_idx;     // Index for iteration
    reg [3:0] u, v;
    reg [5:0] w;
    
    // Distances for Knight (Shortest Path - standard Dijkstra logic)
    // We use simple relaxation loop to fit sequential constraint
    reg [13:0] dist_knight [0:15]; // 14 bits for max weight ~16*12 = 192
    reg [13:0] dist_day [0:15];    // For Day strategy
    reg [13:0] relax_temp;
    reg [13:0] current_dist;
    
    // Helper flags
    reg dist_init;
    reg computing_knight;
    reg computing_day;
    reg [2:0] iteration_count; // For unrolled loops
    
    // Day specific: tracking days and hours per node
    // We optimize: Minimize days, then hours.
    // Stored as {days[4:0], hours[7:0]} = 13 bits total
    // Format: High bits are days, low bits are hours (raw accumulated within day)
    // Actually, let's store packed: {days[7:0], hours[7:0]} for 16 bits, max days 255
    reg [15:0] day_state [0:15]; // Packed: [15:8] days, [7:0] hours (0-255)
    reg [15:0] new_day_state;
    
    // Timer for Done signal
    reg [7:0] timeout;

    integer i;

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (compute_start) next_state = LOAD_EDGES;
                else next_state = IDLE;
            end
            LOAD_EDGES: begin
                // Wait for edge_valid to go low, or count reached
                if (!edge_valid && edge_idx > 0) next_state = COMPUTE_KNIGHT;
                else if (edge_idx >= edge_count) next_state = COMPUTE_KNIGHT;
                else next_state = LOAD_EDGES;
            end
            COMPUTE_KNIGHT: begin
                // Run fixed number of iterations for relaxation (node_count * 2 approx for small graphs)
                if (iteration_count >= (node_count + 2)) next_state = COMPUTE_DAY;
                else next_state = COMPUTE_KNIGHT;
            end
            COMPUTE_DAY: begin
                if (iteration_count >= (node_count + 2)) next_state = CALC_RESULT;
                else next_state = COMPUTE_DAY;
            end
            CALC_RESULT: next_state = DONE_STATE;
            DONE_STATE: begin
                if (start) next_state = IDLE; // Reset if start is pressed again (optional)
                else next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_idx <= 0;
            stored_edge_count <= 0;
            iteration_count <= 0;
            node_idx <= 0;
            done <= 0;
            error <= 0;
            wait_time <= 0;
            dist_init <= 0;
            computing_knight <= 0;
            computing_day <= 0;
            // Reset Dist arrays
            for (i = 0; i < 16; i = i + 1) begin
                dist_knight[i] <= 14'h3FFF; // Inf
                dist_day[i] <= 14'h3FFF;
                day_state[i] <= 16'hFFFF; // Inf days
            end
        end else begin
            case (state)
                IDLE: begin
                    edge_idx <= 0;
                    stored_edge_count <= 0;
                    done <= 0;
                    error <= 0;
                    dist_init <= 0;
                    // Reset arrays on start just in case, but load edge logic will overwrite
                end

                LOAD_EDGES: begin
                    if (edge_valid && edge_idx < 16) begin
                        edge_u_ram[edge_idx] <= edge_u;
                        edge_v_ram[edge_idx] <= edge_v;
                        edge_w_ram[edge_idx] <= edge_weight;
                        edge_idx <= edge_idx + 1;
                        stored_edge_count <= edge_idx + 1; // Track count
                    end
                end

                COMPUTE_KNIGHT: begin
                    // Initialize once
                    if (!dist_init) begin
                        dist_knight[0] <= 0;
                        for (i = 1; i < 16; i = i + 1) dist_knight[i] <= 14'h3FFF;
                        dist_init <= 1;
                        iteration_count <= 0;
                        node_idx <= 0;
                    end else begin
                        // Simple Bellman-Ford style relaxation loop (sequential)
                        // Since graph is small, we iterate edges multiple times
                        if (node_idx < stored_edge_count) begin
                            u <= edge_u_ram[node_idx];
                            v <= edge_v_ram[node_idx];
                            w <= edge_w_ram[node_idx];
                            // Check U->V
                            if (dist_knight[edge_u_ram[node_idx]] != 14'h3FFF) begin
                                if (dist_knight[edge_u_ram[node_idx]] + edge_w_ram[node_idx] < dist_knight[edge_v_ram[node_idx]]) begin
                                    dist_knight[edge_v_ram[node_idx]] <= dist_knight[edge_u_ram[node_idx]] + edge_w_ram[node_idx];
                                end
                            end
                            // Check V->U (undirected)
                            if (dist_knight[edge_v_ram[node_idx]] != 14'h3FFF) begin
                                if (dist_knight[edge_v_ram[node_idx]] + edge_w_ram[node_idx] < dist_knight[edge_u_ram[node_idx]]) begin
                                    dist_knight[edge_u_ram[node_idx]] <= dist_knight[edge_v_ram[node_idx]] + edge_w_ram[node_idx];
                                end
                            end
                            node_idx <= node_idx + 1;
                        end else begin
                            node_idx <= 0;
                            iteration_count <= iteration_count + 1;
                        end
                    end
                end

                COMPUTE_DAY: begin
                    // Strategy 2: Must stop at cabin (node) if time >= 12.
                    // We store state as {days[7:0], current_day_hours[7:0]}
                    // Initialization
                    if (!computing_day) begin
                        computing_day <= 1;
                        // Start at node 0: Day 0, Hours 0 (Assuming start of day 1)
                        // We will treat accumulated time modulo 12.
                        day_state[0] <= 16'h0000; // Days 0, Hours 0
                        for (i = 1; i < 16; i = i + 1) day_state[i] <= 16'hFFFF;
                        iteration_count <= 0;
                        node_idx <= 0;
                    end else begin
                        // Relaxation for Day Strategy
                        // If moving from U to V takes W hours:
                        // New Hours = Current Hours + W
                        // If New Hours > 12 -> New Days = Current Days + 1 + (New Hours / 12), New Hours = New Hours % 12
                        // Else New Days = Current Days, New Hours = New Hours
                        // Note: The prompt says "Max 12 hours", stop at cabin. 
                        // Usually 08:00 to 20:00 = 12h. If you walk 10h, you have 2h left, but you MUST sleep if you are at a cabin?
                        // "Must sleep at cabins only... stop at cabin even if time remains" implies if you reach a node, you sleep?
                        // No, that would be bad. Let's re-read: "Must sleep at cabins only". 
                        // Interpretation: You can only pass through nodes (cabins). If you reach a node and it's not end of day, you CAN continue if connected.
                        // BUT: "Max 12 hours per day". "Stop at cabin even if time remains" -> This implies if you are AT a cabin, you can choose to sleep?
                        // Wait. "Must sleep at cabins only" -> You cannot sleep on the trail. 
                        // "Stop at cabin even if time remains" -> This is likely Mr. Day's flaw. He stops if he reaches a cabin.
                        // Let's assume the standard constrained shortest path:
                        // State is (Node, HoursUsedToday). 
                        // If (HoursUsedToday + Weight > 12), it's an invalid move (cannot reach next node).
                        // Wait, "stop at cabin even if time remains" implies he terminates the day at the cabin he reaches. 
                        // So: 
                        // 1. Calculate reachability within 12h.
                        // 2. If reachable: He arrives at V. He stops there for the day.
                        // 3. New Day starts at V.
                        
                        // Let's refine state storage: day_state[node] = {days[7:0], hours[7:0]} (accumulated total hours modulo? no, raw).
                        // Actually, let's store total hours used (TotalDays * 12 + HoursIntoDay). 
                        // But we need to minimize days first. 
                        // Let's store minimal total time (in hours) for Mr. Day.
                        // Cost function: Every edge (u,v) has cost w.
                        // However, the constraint forces a break at nodes.
                        // Effectively: The path is segmented. 
                        // We can run a BFS/Dijkstra where the cost is (Days, Hours).
                        // Let's optimize:
                        // We use the previous day_state. 
                        // But wait, if he stops at every cabin, then moving U->V is one leg.
                        // If U->V > 12, invalid edge.
                        // If U->V <= 12: He travels U->V, spends 'w' hours.
                        // He arrives at V. He sleeps. 
                        // So transition U->V:
                        // Current Total Time = DistDay[U]
                        // Day start time = DistDay[U] (hours since epoch).
                        // But we must account for the 12h limit. 
                        // If DistDay[U] is e.g. 10 hours (1 day, 10h).
                        // Next day starts at 12 hours (Day 1 done). 
                        // Actually, simpler:
                        // State: Minimal total hours to reach node.
                        // Wait time = (TotalHours / 12).ceil() * 12 + (TotalHours % 12).
                        // But wait, "Stop at cabin even if time remains".
                        // This means: If I arrive at V at 09:00 (1h into day), I stop. I sleep. I wake up 08:00 next day.
                        // So the travel cost is actually w + (12 - (arrival_time % 12)).
                        // Wait, arrival_time = Prev_Total + w.
                        // If Prev_Total % 12 + w < 12: 
                        //   Arrival at H = Prev_Total + w.
                        //   Mr. Day stops. He sleeps. He is idle until 12h have passed in that day.
                        //   So actually he wastes time? 
                        //   "Stop at cabin even if time remains" usually implies "arrive at 09:00, wait until 20:00 to sleep? No."
                        //   It implies "Arrive at 09:00, immediately sleep, wake up 08:00 tomorrow".
                        //   So he wastes (12 - arrival_time_in_day).
                        //   Total time = Total + w + (12 - (Total%12 + w))
                        //   Let's check: Total 0, w=2. Arrive 02:00. Sleep. Wake 08:00. Total time passed 2 + (12-2) = 12.
                        //   Next leg starts at 12. 
                        //   So the edge weight for Mr Day is w + (12 - w) = 12 if w < 12? 
                        //   No, wait. "Each day is 12 hours max".
                        //   If you walk 2 hours, you have 10 hours left. 
                        //   If you stop at the cabin (Mr. Day), you just end the day. 
                        //   Total time accumulated = (PrevDays * 12) + PrevHours + w + (12 - (PrevHours + w)).
                        //   If PrevHours + w <= 12: 
                        //     New Total = PrevDays * 12 + 12 = (PrevDays + 1) * 12.
                        //     So every valid move costs 12 hours for Mr. Day? 
                        //     That seems too simple. 
                        //     If Start (08:00) -> A (09:00). Cost 1 hour. Stop. Wait until next day. Total 12 hours passed.
                        //     A (08:00) -> B (09:00). Cost 1 hour. Stop. Total 24 hours passed.
                        //     So indeed, every edge traversed effectively costs 12 hours (the whole day), 
                        //     UNLESS the edge takes > 12 hours (impossible). 
                        //     Wait, "Max 12 hours per day".
                        //     If I walk 12 hours: 08:00 to 20:00. I arrive at 20:00. I sleep. Total 12h passed.
                        //     If I walk 1 hour: 08:00 to 09:00. I arrive at 09:00. I stop. I sleep. 
                        //     When do I wake up? "Each day max 12 hours".
                        //     Usually "Sleep at cabin" implies you wake up 08:00 next day.
                        //     So yes. Walking U->V takes 'w' hours. 
                        //     If (TimeOfDayStart + w <= 20:00) -> Valid.
                        //     TimeOfDayEnd = TimeOfDayStart + w.
                        //     Mr. Day Ends Day. 
                        //     Next Day starts at 08:00.
                        //     So time elapsed = (TimeOfDayEnd - TimeOfDayStart) + (08:00 next day - TimeOfDayEnd).
                        //     = w + ( (24:00 - TimeOfDayEnd) + 08:00 ) = w + 32 - TimeOfDayEnd.
                        //     Since TimeOfDayStart = 08:00 (for first leg) or 08:00 (for subsequent legs?) 
                        //     Wait, "Mr. Day: Must sleep at cabins".
                        //     Does he wake up at 08:00? Or just when he decides to walk?
                        //     "Each day max 12 hours" implies 08:00-20:00 window.
                        //     If he stops, he waits until 08:00 next day.
                        //     So cost of leg = w + (12 - w) = 12? 
                        //     Only if he starts at 08:00. 
                        //     Actually, if he starts at 08:00 and walks 1h, he finishes at 09:00. 
                        //     He waits 11h. Total 12h passed.
                        //     If he walks 12h, finishes at 20:00. Waits 0h. Total 12h passed.
                        //     So every leg costs exactly 12 hours of total elapsed time!
                        //     Then Mr. Day's total time = (Number of legs) * 12.
                        //     But wait, that's only if he starts at 08:00.
                        //     What if he doesn't? The problem says "Each day max 12 hours".
                        //     "Start at node 0". Implicit 08:00.
                        //     So yes, Mr. Day's time is simply (Shortest Path Edges) * 12.
                        //     
                        //     Wait, "Stop at cabin even if time remains".
                        //     This implies a behavior of "Stop at the FIRST cabin you hit?" or "You must sleep at cabin, but you can walk multiple legs in a day?"
                        //     "Must sleep at cabins only" -> You can't sleep on trail.
                        //     "Each day max 12 hours" -> You can't walk >12h.
                        //     "Stop at cabin even if time remains" -> This is the key differentiator.
                        //     This implies: If you reach a cabin, you must end the day.
                        //     So you cannot walk U->V->W in one day. You must sleep at V.
                        //     Therefore, the graph for Mr. Day has edge costs based on 'days' rather than hours.
                        //     Edge U->V takes 1 day (12h total elapsed).
                        //     BUT: What if U->V takes 1 hour? Total elapsed 12h.
                        //     What if U->V takes 12 hours? Total elapsed 12h.
                        //     So yes, Edge Cost (in time) = 12.
                        //     BUT: What if the edge weight is 0? Edge Cost 12.
                        //     
                        //     HOWEVER: The output is "Difference in waiting time".
                        //     Wait. "Hours Dr. Knight waits".
                        //     Is this the difference in arrival time?
                        //     "Output difference: (MrDay_total - Knight_total)"
                        //     So if Knight arrives in 24h and Day in 36h, diff is 12.
                        //     
                        //     Re-read: "Dr. Knight: Walk as far as possible each day, sleep anywhere. Minimize total days/hours."
                        //     "Mr. Day: Must sleep at cabins only... stop at cabin even if time remains."
                        //     
                        //     Okay, strategy for implementation:
                        //     1. Knight: Standard Dijkstra. Total Hours = Sum of weights.
                        //        Mr. Day: Graph traversal where every step (node visit) consumes a 'day block'.
                        //        But wait. If Mr. Day goes A -> B -> C.
                        //        Day 1: A -> B. (W_AB hours). Stops. Wasted (12 - W_AB) hours.
                        //        Day 2: B -> C. (W_BC hours). Stops. Wasted (12 - W_BC) hours.
                        //        Total Time = 12 + 12 = 24 hours.
                        //        
                        //        What if the graph is A -> B -> C, but there is also A -> C (direct).
                        //        Knight takes A->C. Weight 20. Arrives in 20h.
                        //        Day takes A->B (5h) -> B->C (5h).
                        //        Day takes 12h (Day 1) + 12h (Day 2) = 24h.
                        //        
                        //     So Mr. Day's problem is: Minimize (Number of hops * 12).
                        //     But wait, can he do multiple hops in a day if he doesn't stop?
                        //     "Must sleep at cabins only" -> He MUST sleep at cabins.
                        //     Does he HAVE to stop at EVERY cabin he passes?
                        //     "Stop at cabin even if time remains".
                        //     This suggests: If the path goes through a cabin, he stops.
                        //     So he cannot pass through a node without stopping.
                        //     This effectively fragments the journey into single-hop days.
                        //     
                        //     So: 
                        //     1. Knight: Dijkstra on weights (sum of weights).
                        //     2. Day: BFS/Dijkstra on Edge Hops (count of edges).
                        //        Total Time = (Hop Count) * 12.
                        //        
                        //     Is there a nuance with the 12h limit? 
                        //     Yes. If a single edge weight > 12, it's impossible for Mr. Day.
                        //     (Knight could take it, but Day cannot).
                        //     
                        //     Let's refine Mr. Day's logic:
                        //     We need to find the path with minimum number of edges.
                        //     Weights for Mr. Day: If Edge Weight <= 12: Cost = 1 Day (12 Hours).
                        //     If Edge Weight > 12: Invalid edge for Day.
                        //     
                        //     Total Day Time = (Shortest Path Edges) * 12.
                        //     Total Knight Time = (Shortest Path Weights).
                        //     
                        //     Wait, what about the "Q16.16" hint? 
                        //     If Day uses * 12, it's integer.
                        //     Knight uses sum of integers.
                        //     
                        //     Let's double check the "Stop at cabin even if time remains".
                        //     What if he arrives at a cabin at 09:00 (1h into day).
                        //     He stops. He waits 11h. Total elapsed that segment: 12h.
                        //     So yes, per hop = 12h.
                        //     
                        //     Wait, what if the edge is 13h? 
                        //     Knight can traverse it (13h total).
                        //     Day cannot (max 12h/day).
                        //     So Day must find a different path.
                        //     
                        //     So the algorithm for Day is:
                        //     Find shortest path in terms of NUMBER OF EDGES, but ONLY using edges with weight <= 12.
                        //     If no path exists -> Error.
                        //     Result = (Edge Count * 12).
                        //     
                        //     Let's confirm with the "Compute Day" requirement.
                        //     "Constrained DP... Each day starts fresh at 08:00... Can only stop at nodes... Minimize total days, then hours."
                        //     Minimize days. Days = Hop Count.
                        //     Then hours. What hours? If hop count is same, what differs?
                        //     If path 1: A->B (1h), B->C (1h). Total 2 days. 24h.
                        //     If path 2: A->D (10h), D->C (10h). Total 2 days. 24h.
        //     Total time is same.
        //     Unless... 
        //     "Start at node 0".
        //     Knight: Walk 08:00 to 20:00 (12h), sleep. Walk 08:00 to 20:00.
        //     Day: Walk 09:00 (stop), sleep. Walk 09:00 (stop).
        //     Wait. "Dr. Knight: Walk as far as possible".
        //     This implies Knight can walk multiple edges in a day.
        //     Sum weights <= 12. 
        //     So Knight's problem is standard shortest path.
        //     
        //     Mr. Day: 
        //     "Must sleep at cabins only" -> Okay.
        //     "Each day max 12 hours" -> Okay.
        //     "Stop at cabin even if time remains" -> 
        //     This implies: If he reaches a cabin, he MUST stop for the day.
        //     So he can never traverse more than 1 edge per day.
        //     Because traversing edge U->V lands him at V (a cabin). He stops.
        //     So he effectively traverses 1 edge per day.
        //     
        //     Is it possible he traverses 0 edges? No.
        //     
        //     So Mr. Day's graph: Weights are either 12 (if traversable) or Infinity (if edge > 12).
        //     
        //     Wait, "Minimize total days, then hours".
        //     If multiple paths have same number of edges (days), what about hours?
        //     If he takes edge A->B (2h). Arrives 10:00. Stops. Wastes 10h. Total 12h.
        //     If he takes edge A->C (10h). Arrives 18:00. Stops. Wastes 2h. Total 12h.
        //     So hours don't matter for total elapsed time?
        //     Unless he doesn't sleep until 20:00? "Even if time remains" implies he stops early.
        //     So yes, Total Time = 12 * Hops.
        //     
        //     However, the prompt says: "Output difference: (MrDay_total - Knight_total)"
        //     Knight Total: Sum of weights.
        //     Mr Day Total: Sum of 12s (Hops * 12).
        //     
        //     Let's refine the DP for Mr. Day to be safe.
        //     We need to minimize (Days, Hours) lexicographically? 
        //     But if every hop costs 12h, Days = Hops. Hours = 0.
        //     Wait. "Hours" in "Minimize total days, then hours" might refer to the time of day?
        //     Or the remaining time used?
        //     Let's assume the standard interpretation: 
        //     Mr. Day's total time = (Hops * 12).
        //     Knight's total time = (Sum of weights).
        //     
        //     Edge Cases:
        //     1. No path for Knight -> Error.
        //     2. No path for Day -> Error.
        //     3. Max nodes 16. Max weights 12. 
        //        Max Knight time = 16*12 = 192. Fits in 8 bits? No, 192 fits. Wait, 8 bits max 255. Yes.
        //        Max Day time = 16 hops * 12 = 192. Fits in 8 bits.
        //        Result difference: 192 - 0 = 192. Fits in 8 bits.
        //        
        //     Wait, Result fits in 8 bits. Max ~255. 
        //     
        //     Implementation Plan:
        //     State: LOAD_EDGES -> COMPUTE_KNIGHT -> COMPUTE_DAY -> CALC -> DONE
        //     
        //     Knight: Dijkstra (or Bellman-Ford).
        //     Data: dist_knight[15:0]. Init INF. dist[0]=0.
        //     Loop: Relax all edges.
        //     
        //     Day: Shortest Path in hops.
        //     Data: dist_day[15:0]. Init INF. dist[0]=0.
        //     Edge Check: If weight <= 12, it's a valid edge with cost 1 hop.
        //     Loop: Relax all edges.
        //     
        //     Result: 
        //     Knight Time = dist_knight[n-1].
        //     Day Time = dist_day[n-1] * 12.
        //     
        //     Wait, "Wait time difference". 
        //     Knight waits? "Hours Dr. Knight waits". 
        //     Maybe this is the time saved? Or the time difference?
        //     "Output difference: (MrDay_total - Knight_total)"
        //     So if Day is slower (typical), Knight waits less? 
        //     Actually, "Hours Dr. Knight waits" implies Knight arrives first and waits for Day?
        //     No, "Calculate difference".
        //     
        //     Let's implement the DP for Mr. Day carefully.
        //     Actually, "Minimize days, then hours".
        //     If Hop Count is the metric for Days, then Hop Count * 12 is Days in hours.
        //     If Hop Count is equal, what minimizes hours?
        //     If Path A (2 hops): A->B (1h), B->C (1h). Total 2 days. 24h.
        //     Path B (2 hops): A->D (10h), D->C (10h). Total 2 days. 24h.
        //     So hours don't differ? 
        //     Maybe the "Hours" refers to the time within the day he arrives?
        //     No, total elapsed.
        //     
        //     Let's assume the simplest model: 
        //     Day Cost per Edge = 12.
        //     
        //     But wait, what if the edge weight is 0? 
        //     Day takes 0h walk, stops. Total 12h.
        //     Knight takes 0h. Arrives instantly.
        //     
        //     Okay, wait. "Dr. Knight: Walk as far as possible each day, sleep anywhere."
        //     This implies he chunks edges. 
        //     E.g. A->B (2h), B->C (3h). Knight does A->C in 5h.
        //     Mr. Day: A->B (2h, stop), B->C (3h, stop). 2 days = 24h.
        //     
        //     So Mr. Day is constrained to 1 edge per day.
        //     
        //     What if the graph has an edge A->C (weight 5). 
        //     Knight: A->C, 5h.
        //     Day: A->C, 5h walk, stop. Total 12h.
        //     
        //     So Mr. Day's formula: 
        //     Shortest path in terms of number of edges (hops), subject to weight constraints.
        //     Total Time = (Hop Count) * 12.
        //     
        //     But wait. "Minimize total days, then hours".
        //     If Hop Count is same, what's the hours?
        //     Maybe "Hours" refers to the actual time spent walking?
        //     Or the time of arrival? 
        //     If A->B (2h), B->C (2h). Total 4h walking. 24h elapsed.
        //     If A->D (4h), D->C (0h). Total 4h walking. 24h elapsed.
        //     
        //     Maybe there's a nuance: If he arrives at 19:00 (11h), he sleeps. Wastes 1h.
        //     If he arrives at 09:00 (1h), he sleeps. Wastes 11h.
        //     Total elapsed is still 12h per hop.
        //     
        //     So the hours part is moot if the metric is "Total Elapsed Time".
        //     However, the prompt says "Minimize total days, then hours".
        //     This implies lexicographical ordering on (Days, Hours).
        //     Maybe "Hours" is the remainder of the last day?
        //     No, "Hours Dr. Knight waits".
        //     
        //     Let's assume the strict interpretation:
        //     Knight: Standard Dijkstra.
        //     Day: 
        //       - States: (Current Node, HoursUsedInDay).
        //       - Transition: If (HoursUsed + Weight > 12), Invalid.
        //       - If (HoursUsed + Weight <= 12): 
        //         - Arrive at V.
        //         - Wait. "Stop at cabin even if time remains".
        //         - Does this mean he MUST end the day?
        //         - If yes, then next state is (V, 0) with added 12h? Or added (HoursUsed+Weight) + (12 - (HoursUsed+Weight)) = 12.
        //         - So cost = 12.
        //         - Next node starts at 0 hours used.
        //     
        //     This matches the hop-count model.
        //     
        //     Let's implement the Hop-Count model for Day.
        //     It fits the constraints (256 cycles, small graph).
        //     
        //     One more thing: "Nodes 0 to n-1". Start 0, Dest n-1.
        //     Inputs node_count and edge_count.
        //     
        //     Implementation details:
        //     
        //     Knight Distance Array: 14 bits (192 max).
        //     Day Distance Array: 4 bits (16 hops max). 
        //     
        //     
        //     Algorithm for Day:
        //     dist[0] = 0 (0 hops).
        //     dist[1..15] = INF.
        //     Relaxation:
        //       If edge w <= 12:
        //         if dist[u] + 1 < dist[v]: dist[v] = dist[u] + 1
        //         if dist[v] + 1 < dist[u]: dist[u] = dist[v] + 1
        //     
        //     Result Day Time = dist[n-1] * 12.
        //     
        //     Wait, what if n=2, edge weight 12.
        //     Knight: 12h.
        //     Day: 1 hop = 12h.
        //     Diff = 0.
        //     
        //     What if n=2, edge weight 5.
        //     Knight: 5h.
        //     Day: 12h.
        //     Diff = 7.
        //     
        //     What if n=3. 0-1 (1h), 1-2 (1h), 0-2 (5h).
        //     Knight: 0->2 = 5h.
        //     Day: 0->2 (1 hop, 12h). OR 0->1->2 (2 hops, 24h). Min is 12h.
        //     Diff = 7.
        //     
        //     This seems correct.
        //     
        //     Let's refine the State Machine to handle the loops efficiently.
        //     We have limited cycles (256).
        //     Graph size is small (16 nodes).
        //     Edges are few (16).
        //     Sequential processing: Iterate edges multiple times.
        //     
        //     Phase 1: Knight (Dijkstra/Bellman Ford)
        //       Initialize dist_knight[0]=0.
        //       Loop (node_count + 1) times:
        //         Iterate edge_idx from 0 to stored_edge_count-1:
        //           relax u, v, w
        //     
        //     Phase 2: Day (Hop count)
        //       Initialize dist_day[0]=0.
        //       Loop (node_count + 1) times:
        //         Iterate edge_idx from 0 to stored_edge_count-1:
        //           If w <= 12: relax u, v (cost 1)
        //     
        //     Phase 3: Calc
        //       Result = (dist_day[n-1] * 12) - dist_knight[n-1]
        //       If dist_day[n-1] == INF or dist_knight[n-1] == INF -> Error.
        //     
        //     Optimizing for Area/Speed:
        //     We need a loop counter for the outer iteration (node_count).
        //     We need an inner loop counter for edges.
        //     
        //     Let's combine into single FSM with counters.
        //     
        //     State LOAD_EDGES: Handles input. 
        //     
        //     State COMPUTE_KNIGHT:
        //       We need to run Relaxation.
        //       We'll use `node_idx` as the outer loop counter (iter 0 to N).
        //       We'll use `edge_idx` as the inner loop counter (iter 0 to EdgeCount).
        //       
        //       If `node_idx` < (node_count + 2):
        //         If `edge_idx` < stored_edge_count:
        //           Read u, v, w.
        //           Check relaxation.
        //           edge_idx += 1
        //         Else:
        //           edge_idx = 0
        //           node_idx += 1
        //       Else:
        //         Done.
        //     
        //     Same for State COMPUTE_DAY, but with added check for w <= 12.
        //     
        //     Logic for Relaxation (Knight):
        //     
        //     reg [13:0] candidate;
        //     candidate = dist_knight[u] + w;
        //     if (candidate < dist_knight[v]) dist_knight[v] = candidate;
        //     
        //     candidate = dist_knight[v] + w;
        //     if (candidate < dist_knight[u]) dist_knight[u] = candidate;
        //     
        //     Logic for Relaxation (Day):
        //     if (w <= 12):
        //       if (dist_day[u] != INF && dist_day[u] + 1 < dist_day[v]) dist_day[v] = dist_day[u] + 1;
        //       if (dist_day[v] != INF && dist_day[v] + 1 < dist_day[u]) dist_day[u] = dist_day[v] + 1;
        //     
        //     Let's define INF for Day. Max hops 15. INF = 16 (or 31).
        //     Knight INF: 14'h3FFF.
        //     Day INF: 5'h1F.
        //     
        //     Result Calculation:
        //     Knight_Val = dist_knight[node_count-1]
        //     Day_Hops = dist_day[node_count-1]
        //     Day_Val = Day_Hops * 12
        //     
        //     Error if (Knight_Val == INF || Day_Hops == INF)
        //     
        //     Result = Day_Val - Knight_Val.
        //     
        //     One nuance: "Output difference: (MrDay_total - Knight_total)"
        //     "Hours Dr. Knight waits".
        //     If Day is faster (unlikely given constraints), result could be negative.
        //     But `wait_time` is [7:0] (unsigned).
        //     If Day is slower (typical), result is positive.
        //     If Day is faster, result is negative. 
        //     The prompt says "Result fits in 8 bits for scaled problem (max ~255 hours)".
        //     This implies the difference is usually positive and within 255.
        //     We will treat it as unsigned and clamp or logic? 
        //     Let's assume Day is never faster. If it is, we output 0? Or wrap?
        //     Given "Dr. Knight waits", it implies Knight arrives first. So Day is slower.
        //     So (Day - Knight) >= 0.
        //     
        //     Let's refine the Wait Time output.
        //     "Wait time difference". 
        //     If I interpret "Hours Dr. Knight waits" literally, it might be the time Knight waits for Day.
        //     So if Knight arrives at T1, Day at T2. Wait = T2 - T1.
        //     
        //     Let's implement the logic.
        //     
        //     Variables needed:
        //     state, next_state.
        //     stored_edge_count.
        //     edge_idx, node_idx (iteration counters).
        //     dist_knight [0:15] (14 bits).
        //     dist_day [0:15] (5 bits, use 6 bits for simplicity). 
        //     
        //     Optimization:
        //     Since node_count is input, we can limit loops.
        //     But for simplicity in verilog, we often run full fixed iterations or check counters.
        //     Max 16 nodes. 
        //     
        //     Let's add logic for `done` and `error`.
        //     Done goes high in DONE_STATE.
        //     Error is computed in CALC_RESULT if path not found.
        //     
        //     Edge Storage:
        //     `edge_u_ram`, `edge_v_ram`, `edge_w_ram` size 16.
        //     
        //     Let's write the code.

            IDLE: begin
                // Reset iteration counters
                edge_idx <= 0;
                node_idx <= 0;
                iteration_count <= 0;
                dist_init <= 0;
                computing_knight <= 0;
                computing_day <= 0;
                done <= 0;
                error <= 0;
            end

            LOAD_EDGES: begin
                if (edge_valid) begin
                    if (edge_idx < 16) begin // Safety cap
                        edge_u_ram[edge_idx] <= edge_u;
                        edge_v_ram[edge_idx] <= edge_v;
                        edge_w_ram[edge_idx] <= edge_weight;
                        edge_idx <= edge_idx + 1;
                    end
                end else begin
                    // If not valid, but we have edges, move on. 
                    // Or if we hit the count.
                    if (edge_idx > 0 || edge_count == 0) begin
                        stored_edge_count <= edge_idx; // Actual loaded count
                    end
                end
            end

            COMPUTE_KNIGHT: begin
                // Initialize distances
                if (!computing_knight) begin
                    computing_knight <= 1;
                    // Reset dist array
                    for (i = 0; i < 16; i = i + 1) dist_knight[i] <= 14'h3FFF;
                    dist_knight[0] <= 0;
                    node_idx <= 0; // Outer loop counter (relaxation rounds)
                    edge_idx <= 0; // Inner loop counter (edge index)
                    iteration_count <= 0;
                end else begin
                    // Bellman-Ford style relaxation loop
                    // We run (node_count + 1) rounds of relaxing all edges
                    if (node_idx < (node_count + 1)) begin
                        // Process edges
                        if (edge_idx < stored_edge_count) begin
                            // Read edge
                            u <= edge_u_ram[edge_idx];
                            v <= edge_v_ram[edge_idx];
                            w <= edge_w_ram[edge_idx];
                            
                            // Relax U->V
                            if (dist_knight[edge_u_ram[edge_idx]] != 14'h3FFF) begin
                                if (dist_knight[edge_u_ram[edge_idx]] + edge_w_ram[edge_idx] < dist_knight[edge_v_ram[edge_idx]]) begin
                                    dist_knight[edge_v_ram[edge_idx]] <= dist_knight[edge_u_ram[edge_idx]] + edge_w_ram[edge_idx];
                                end
                            end
                            // Relax V->U (Undirected)
                            if (dist_knight[edge_v_ram[edge_idx]] != 14'h3FFF) begin
                                if (dist_knight[edge_v_ram[edge_idx]] + edge_w_ram[edge_idx] < dist_knight[edge_u_ram[edge_idx]]) begin
                                    dist_knight[edge_u_ram[edge_idx]] <= dist_knight[edge_v_ram[edge_idx]] + edge_w_ram[edge_idx];
                                end
                            end
                            
                            edge_idx <= edge_idx + 1;
                        end else begin
                            // Finished edges for this round
                            edge_idx <= 0;
                            node_idx <= node_idx + 1;
                        end
                    end else begin
                        // Knight computation done
                        // Check if we need to skip to Day (if node_count is 0)
                        if (stored_edge_count == 0 && node_count > 0) begin
                            // No edges, impossible unless start == end
                        end
                        // We just transition based on state machine timing (iteration_count)
                        // Actually we can transition directly if we want to save cycles, 
                        // but the state machine says "ITERATION_COUNT" based transition.
                        // Let's use the state machine's iteration_count logic for consistency.
                        iteration_count <= iteration_count + 1; // Use this to exit state
                    end
                end
            end

            COMPUTE_DAY: begin
                // Initialize distances
                if (!computing_day) begin
                    computing_day <= 1;
                    // Reset dist array (5 bits needed for 16 hops)
                    for (i = 0; i < 16; i = i + 1) dist_day[i] <= 6'h3F; // Inf
                    dist_day[0] <= 0;
                    node_idx <= 0;
                    edge_idx <= 0;
                    iteration_count <= 0;
                end else begin
                    if (node_idx < (node_count + 1)) begin
                        if (edge_idx < stored_edge_count) begin
                            u <= edge_u_ram[edge_idx];
                            v <= edge_v_ram[edge_idx];
                            w <= edge_w_ram[edge_idx];
                            
                            // Check weight constraint for Mr. Day
                            if (edge_w_ram[edge_idx] <= 12) begin
                                // Relax U->V (Cost 1 hop)
                                if (dist_day[edge_u_ram[edge_idx]] != 6'h3F) begin
                                    if (dist_day[edge_u_ram[edge_idx]] + 1 < dist_day[edge_v_ram[edge_idx]]) begin
                                        dist_day[edge_v_ram[edge_idx]] <= dist_day[edge_u_ram[edge_idx]] + 1;
                                    end
                                end
                                // Relax V->U
                                if (dist_day[edge_v_ram[edge_idx]] != 6'h3F) begin
                                    if (dist_day[edge_v_ram[edge_idx]] + 1 < dist_day[edge_u_ram[edge_idx]]) begin
                                        dist_day[edge_u_ram[edge_idx]] <= dist_day[edge_v_ram[edge_idx]] + 1;
                                    end
                                end
                            end
                            edge_idx <= edge_idx + 1;
                        end else begin
                            edge_idx <= 0;
                            node_idx <= node_idx + 1;
                        end
                    end else begin
                        iteration_count <= iteration_count + 1;
                    end
                end
            end

            CALC_RESULT: begin
                // Calculate Difference
                // Knight Total = dist_knight[node_count-1]
                // Day Total = dist_day[node_count-1] * 12
                // We need to handle the case where node_count-1 is accessed.
                // If node_count is 0 or 1, start == end. Wait time 0?
                
                if (node_count <= 1) begin
                    wait_time <= 0;
                    error <= 0;
                end else begin
                    // Check errors
                    if (dist_knight[node_count-1] >= 14'h3FFF || dist_day[node_count-1] >= 6'h3F) begin
                        error <= 1;
                        wait_time <= 0;
                    end else begin
                        error <= 0;
                        // Perform calculation
                        // Day Time = Hops * 12
                        // We can multiply by 12 (shift left 3 + shift left 2).
                        // dist_day is 6 bits. Result fits 8 bits (max 15*12 = 180).
                        
                        // Wait_time = (dist_day[n-1] * 12) - dist_knight[n-1]
                        // dist_knight is 14 bits, but values are small.
                        
                        // Let's do it safely.
                        // Max Day: 180. Max Knight: 192. Diff: < 256.
                        // If Knight is faster, Diff is positive.
                        
                        // We need a small multiplier/subtractor combo.
                        // Let's compute: Day_Hops * 12
                        // We can use a wire for multiplication in combinational logic block? 
                        // No, this is sequential logic block. 
                        // We can do it in one cycle if we pre-calculate or use simple shift/add.
                        // 12 = 8 + 4. {dist_day, 2'b00} + {dist_day, 1'b0}.
                        
                        // Let's use intermediate registers or variables if allowed inside always block.
                        // Verilog allows local variables in combinational blocks, but this is seq block.
                        // Let's compute math directly if the synth tool is smart, or break it down.
                        // Actually, just write the expression. Synthesis will handle it.
                        
                        // However, we need to ensure we use the correct values.
                        // dist_knight[node_count-1] and dist_day[node_count-1] are registers.
                        
                        // We need to index the arrays.
                        // Since node_count is input, it might not be constant.
                        // We need to handle indexing.
                        // We can use a lookup or compute on the fly.
                        
                        // Let's create temporary values.
                        // Note: In combinational logic inside always block, we can't easily index array with variable unless it's a variable index.
                        // But dist_knight is an array of regs. dist_knight[node_count-1] is valid.
                        
                        // Calculate Day Hours
                        // wait_time <= (dist_day[node_count-1] * 12) - dist_knight[node_count-1];
                        // Wait, dist_day is 6 bits. dist_knight is 14 bits.
                        // We need to zero extend dist_day to 14 bits for subtraction?
                        // Or just truncate dist_knight to 8 bits? No, result is 8 bits.
                        
                        // Let's use temporary wires for clarity if needed, but we can do math in place.
                        // Synthesis might complain about width mismatch if we don't care.
                        // Let's zero extend dist_day to 14 bits for subtraction.
                        
                        // Also, dist_knight might be larger than 255 if graph is dense, but prompt says result fits 8 bits.
                        // So diff is < 256.
                        // We can cast to 8 bits if we trust the constraint.
                        
                        // Logic:
                        // reg [13:0] d_day_time; // 14 bits
                        // reg [13:0] d_kn_time;  // 14 bits
                        // d_day_time = dist_day[node_count-1] * 12;
                        // d_kn_time = dist_knight[node_count-1];
                        // wait_time <= d_day_time - d_kn_time;
                        // 
                        // We need to perform this calculation. 
                        // Since we are in a sequential block, let's compute the product first.
                        // Or we can just let the synth tool handle it. 
                        
                        // To be safe and explicit:
                        wait_time <= (dist_day[node_count-1] * 12) - dist_knight[node_count-1][7:0]; 
                        // NOTE: If Knight time > 255, this truncates. But the problem says result fits 8 bits.
                        // (MrDay - Knight) fits 8 bits. So Knight must be small if Day is small.
                        // Max Day = 192. So Knight must be > 192-255 = -63 (impossible) or < 192.
                        // Actually, if Diff fits 8 bits, and Day >= Knight, then Diff is 0..255.
                        // So (Day - Knight) fits 8 bits.
                        // Wait_time is 8 bits.
                        // So we just need to ensure subtraction logic is correct.
                        // (Day * 12) is max 192. Knight is max 192. 
                        // 192 - 192 = 0. 192 - 0 = 192.
                        // Wait_time is [7:0].
                        // So result is always positive or zero.
                        
                        // So we can safely truncate Knight to 8 bits because if Knight > 255, Diff would be negative, which is impossible.
                        // Wait, if Knight > Day? "Knight waits" implies Knight arrives first.
                        // So Day >= Knight.
                        // So Day - Knight >= 0.
                        // So we need (Day - Knight).
                        // Let's do 8-bit subtraction.
                        // wait_time <= (dist_day[node_count-1] * 12) - dist_knight[node_count-1][7:0];
                        // But if dist_knight is > 255, we have a problem.
                        // If dist_knight > 255, and Day is >= Knight, then Day >= 256. 
                        // But Day max is 192 (16*12). 
                        // So Knight cannot be > 192 if Day >= Knight.
                        // So dist_knight fits in 8 bits in valid scenarios.
                        // So [7:0] is safe.
                        
                        // Wait, what if no path exists? We handled error flag.
                        // So if not error, paths exist.
                        
                        wait_time <= (dist_day[node_count-1] * 12) - dist_knight[node_count-1][7:0];
                    end
                end
            end

            DONE_STATE: begin
                done <= 1;
            end
        endcase
    end

endmodule
