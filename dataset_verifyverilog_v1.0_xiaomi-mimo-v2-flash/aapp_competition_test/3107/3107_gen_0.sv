module truck_encounter_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_en,
    input wire [7:0] data_in,
    input wire [3:0] addr_in,
    output reg result_valid,
    output reg [7:0] result_count,
    output reg busy
);

    // --- Constants ---
    localparam [3:0] MAX_TRUCKS = 4'd16;
    localparam [3:0] MAX_QUERIES = 4'd16;
    localparam [3:0] MAX_CITIES = 4'd8;
    localparam [7:0] MAX_COORD = 8'd127;

    // --- State Declarations ---
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG_LOAD = 3'd1;
    localparam [2:0] PROCESS_SETUP = 3'd2;
    localparam [2:0] CALC_INTERSECT = 3'd3;
    localparam [2:0] OUTPUT_RESULT = 3'd4;
    localparam [2:0] WAIT_NEXT = 3'd5;

    // --- Internal Registers & Wires ---
    reg [2:0] state, next_state;
    reg [3:0] query_idx;
    reg [3:0] config_truck_idx;
    reg [3:0] config_city_idx;
    reg config_done_flag;
    
    // --- Memory Arrays (BRAM style) ---
    // Truck Routes: 16 trucks * 8 cities * 8 bits
    reg [7:0] truck_routes [0:15][0:7];
    // Route Lengths: 16 trucks * 4 bits (max 8 cities)
    reg [3:0] truck_lengths [0:15];
    // Query Pairs: 16 queries * 8 bits (4-bit A, 4-bit B)
    reg [7:0] query_pairs [0:15];
    
    // --- Processing Registers ---
    reg [3:0] truck_a_id;
    reg [3:0] truck_b_id;
    reg [3:0] seg_a_idx;
    reg [3:0] seg_b_idx;
    reg [7:0] encounter_count;
    reg [3:0] num_segs_a;
    reg [3:0] num_segs_b;
    
    // --- Fixed Point & Math Registers (Q8.8 simulation using 16-bit) ---
    // We use 16-bit internal for intermediate calcs (8-bit coord * 8-bit time)
    reg [15:0] pos_a_start, pos_a_end;
    reg [15:0] pos_b_start, pos_b_end;
    reg [15:0] time_a_start, time_a_end;
    reg [15:0] time_b_start, time_b_end;
    reg [15:0] vel_a, vel_b; // Velocity = delta_pos / delta_time
    reg [15:0] intersect_time;
    
    // --- Cycle Counter for Timeout Prevention ---
    reg [7:0] cycle_counter;

    // --- FSM State Transition ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            result_valid <= 1'b0;
            result_count <= 8'd0;
            query_idx <= 4'd0;
            config_truck_idx <= 4'd0;
            config_city_idx <= 4'd0;
            config_done_flag <= 1'b0;
            seg_a_idx <= 4'd0;
            seg_b_idx <= 4'd0;
            encounter_count <= 8'd0;
            cycle_counter <= 8'd0;
            truck_a_id <= 4'd0;
            truck_b_id <= 4'd0;
            num_segs_a <= 4'd0;
            num_segs_b <= 4'd0;
        end else begin
            state <= next_state;
            
            // Default outputs
            result_valid <= 1'b0;
            busy <= 1'b1;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    result_count <= 8'd0;
                    query_idx <= 4'd0;
                    config_truck_idx <= 4'd0;
                    config_city_idx <= 4'd0;
                    config_done_flag <= 1'b0;
                    seg_a_idx <= 4'd0;
                    seg_b_idx <= 4'd0;
                    encounter_count <= 8'd0;
                    cycle_counter <= 8'd0;
                    if (start && config_done_flag) begin
                        // Only start if config is marked done
                        // (Alternatively, start immediate processing if config already loaded)
                    end
                end

                CONFIG_LOAD: begin
                    // Handling data input inside FSM or separate logic? 
                    // According to protocol, data comes in continuously.
                    // We rely on external control or internal logic to latch data.
                    // Here we advance indices based on control signals.
                    // Note: Actual latching happens in the always block triggered by config_en/data_in.
                end

                PROCESS_SETUP: begin
                    // Load current query data
                    truck_a_id <= query_pairs[query_idx][7:4];
                    truck_b_id <= query_pairs[query_idx][3:0];
                    num_segs_a <= (truck_lengths[query_pairs[query_idx][7:4]] > 1) ? (truck_lengths[query_pairs[query_idx][7:4]] - 1) : 0;
                    num_segs_b <= (truck_lengths[query_pairs[query_idx][3:0]] > 1) ? (truck_lengths[query_pairs[query_idx][3:0]] - 1) : 0;
                    seg_a_idx <= 4'd0;
                    seg_b_idx <= 4'd0;
                    encounter_count <= 8'd0;
                    cycle_counter <= 8'd0;
                end

                CALC_INTERSECT: begin
                    // Cycle counter for timeout
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // --- Math Logic (Direct Implementation) ---
                    // 1. Get Segment Data
                    // Coordinates are 8-bit. Treat as integer.
                    // Time is proportional to distance: |p2 - p1|
                    
                    // Fetch points
                    // A segment: (truck_routes[truck_a_id][seg_a_idx], truck_routes[truck_a_id][seg_a_idx+1])
                    // B segment: (truck_routes[truck_b_id][seg_b_idx], truck_routes[truck_b_id][seg_b_idx+1])
                    
                    // Pre-calculate differences and times
                    // Note: We use 16-bit for signed arithmetic safety and scaling
                    
                    // Segment A calculation
                    if (truck_routes[truck_a_id][seg_a_idx+1] >= truck_routes[truck_a_id][seg_a_idx]) begin
                        vel_a <= {8'd0, (truck_routes[truck_a_id][seg_a_idx+1] - truck_routes[truck_a_id][seg_a_idx])};
                        time_a_start <= {8'd0, truck_routes[truck_a_id][seg_a_idx]}; // Actually pos is pos, time is distance from start
                        // Wait, the problem says "Piecewise linear segments connecting route cities".
                        // "Time = |City_{i+1} - City_i| * 1 cycle" is the duration.
                        // Let's define time relative to segment start for math.
                        // Parametric: P(t) = P0 + V*t. t in [0, duration].
                        // Duration A = abs(P1 - P0).
                    end
                    // Let's stick to the problem hint: 
                    // Solve P1 + V1*(t-t1) = P2 + V2*(t-t2)
                    // Let's normalize so t starts at 0 for each segment?
                    // No, absolute time is better.
                    
                    // Let's assume: 
                    // Segment A: Pos: P_A1 -> P_A2. Duration: D_A = |P_A2 - P_A1|.
                    // Time interval: [T_A1, T_A1 + D_A].
                    // Velocity V_A = (P_A2 - P_A1) / D_A. (Direction +1 or -1)
                    
                    // To avoid floating point, we solve:
                    // (P_A1 + V_A * (t - T_A1)) = (P_B1 + V_B * (t - T_B1))
                    // P_A1 - V_A * T_A1 + V_A * t = P_B1 - V_B * T_B1 + V_B * t
                    // t * (V_A - V_B) = (P_B1 - V_B * T_B1) - (P_A1 - V_A * T_A1)
                    // This is tricky with integer velocities.
                    
                    // ALTERNATIVE: Cross product method (safest for integers)
                    // Line 1: (t1, p1) -> (t2, p2)
                    // Line 2: (t3, p3) -> (t4, p4)
                    // Intersection exists if (t1, p1)-(t2, p2) crosses (t3, p3)-(t4, p4).
                    // Let's construct absolute time points.
                    // We need absolute cumulative time for each city.
                    // Since we didn't store cumulative time, we must compute it on fly or store it.
                    // Given 8 cities max, we can compute cumulative time in a small buffer or just on the fly.
                    
                    // Let's refine: Use relative segments.
                    // P(t) = P_start + (P_end - P_start) * (t / duration)
                    // Multiply both sides by duration: P(t)*duration = P_start*duration + (P_end - P_start)*t
                    
                    // Let's use the formula provided in hints:
                    // (p2-p1)*(t4-t3) != (p4-p3)*(t2-t1) (Parallel check)
                    // Solve for t (intersection time)
                    // This suggests treating (t, p) as coordinates in time-position space.
                    // We need to know absolute time for each point.
                    
                    // --- IMPACT: We need to calculate Absolute Times ---
                    // We will compute start time of segment A and B dynamically.
                    // We need a helper to compute cumulative time up to segment index.
                    // Since the loop is sequential (seg_a_idx, seg_b_idx), we can compute cumulative time.
                    
                    // Let's store Cumulative Time in a temporary register array or compute it.
                    // Compute Time_A_Start: Sum of |City_i - City_{i-1}| for i=0..seg_a_idx
                    // We will compute this in the math logic below.
                    
                    // --- Math Implementation ---
                    // 1. Compute Segment A Data
                    // P_A1 = truck_routes[truck_a_id][seg_a_idx]
                    // P_A2 = truck_routes[truck_a_id][seg_a_idx + 1]
                    // D_A = |P_A2 - P_A1]
                    // T_A1 = Cumulative Time up to seg_a_idx
                    // T_A2 = T_A1 + D_A
                    
                    // 2. Compute Segment B Data similarly
                    
                    // 3. Check Intersection
                    // Numerator for t: (P_A2*T_A1 - P_A1*T_A2)*(T_B2 - T_B1) - (P_B2*T_B1 - P_B1*T_B2)*(T_A2 - T_A1)
                    // Denominator: (P_A2 - P_A1)*(T_B2 - T_B1) - (P_B2 - P_B1)*(T_A2 - T_A1)
                    // If Denom == 0: Parallel (no intersect or colinear, ignore)
                    // If t strictly inside (T_A1, T_A2) AND (T_B1, T_B2): Count++
                    
                    // To implement this efficiently without loops inside combinational logic:
                    // We will compute segment parameters in setup or pipe stages.
                    // For this single always block FSM, we do sequential checking.
                    
                    // --- Helper Logic for Cumulative Time ---
                    // We need a function or combinational logic to get cumulative time.
                    // Let's assume we calculate it.
                    
                    // Since Verilog in always block is sequential, we will calculate one intersection per cycle (or few cycles).
                    // Given constraints (max 49 intersections per query), 1 cycle per intersection is fine.
                    
                    // We will use combinational logic blocks for math, or do it step-by-step.
                    // Let's do step-by-step in the FSM state CALC_INTERSECT.
                    
                    // Define helper registers for this cycle's calculation
                    // We compute T_A1, T_A2, etc. here.
                    // Since we are in CALC_INTERSECT, we need to fetch data.
                    // We will use a combinational block for the math, or do it sequentially.
                    // Let's do sequential to ensure no timing errors.
                    
                    // Step 1: Compute Cumulative Times for A and B start points.
                    // This requires summing previous segments. 
                    // Since we are iterating, we can accumulate.
                    // However, the FSM iterates seg_a_idx and seg_b_idx.
                    // We need T_A1 for the current seg_a_idx.
                    // We can compute T_A1 by summing distances of truck_a_id from 0 to seg_a_idx.
                    // This is a small sum (max 7 terms). We can do it in a combinational block or store cumulative times.
                    // Let's use a combinational block (function-like logic) inside the always block is hard.
                    // Instead, let's pre-calculate cumulative times? 
                    // No, let's calculate them on the fly.
                    
                    // We will use a dedicated combinational logic block for math using `wire`s.
                    // The FSM state just triggers the logic and increments counters based on the result.
                    // But `wire` logic cannot be inside `always`.
                    // We will use intermediate registers to hold calculated values.
                end
                
                OUTPUT_RESULT: begin
                    result_valid <= 1'b1;
                    result_count <= encounter_count;
                end

                WAIT_NEXT: begin
                    result_valid <= 1'b0;
                    // Ready for next query or idle
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

    // --- Combinational Next State Logic ---
    always @(*) begin
        case (state)
            IDLE: begin
                if (config_en) next_state = CONFIG_LOAD;
                else if (start && config_done_flag) next_state = PROCESS_SETUP;
                else next_state = IDLE;
            end
            CONFIG_LOAD: begin
                // Stay in CONFIG_LOAD if config_en is high? 
                // Or just latch data when config_en is high.
                // Protocol says "Data stream". We assume config_en stays high during loading.
                if (config_en) next_state = CONFIG_LOAD;
                else next_state = IDLE; // Return to IDLE after config transaction
            end
            PROCESS_SETUP: begin
                // Check if current query has any segments
                if (num_segs_a == 0 || num_segs_b == 0) begin
                    // No segments to intersect
                    next_state = OUTPUT_RESULT;
                end else begin
                    next_state = CALC_INTERSECT;
                end
            end
            CALC_INTERSECT: begin
                // Logic to determine when segment loops are done
                // We need to iterate seg_a_idx (0 to num_segs_a-1) and seg_b_idx (0 to num_segs_b-1)
                
                // If finished inner loop (seg_b_idx done)
                if (seg_b_idx >= num_segs_b - 1) begin
                    if (seg_a_idx >= num_segs_a - 1) begin
                        // Both loops done
                        next_state = OUTPUT_RESULT;
                    end else begin
                        // Next A segment, reset B
                        next_state = CALC_INTERSECT; // Stay in calc, update indices in seq block
                    end
                end else begin
                    // Next B segment
                    next_state = CALC_INTERSECT;
                end
                
                // Timeout safety
                if (cycle_counter > 8'd200) begin // Safety timeout
                    next_state = OUTPUT_RESULT;
                end
            end
            OUTPUT_RESULT: begin
                next_state = WAIT_NEXT;
            end
            WAIT_NEXT: begin
                if (query_idx >= MAX_QUERIES - 1) next_state = IDLE;
                else next_state = PROCESS_SETUP; // Start next query immediately for throughput
            end
            default: next_state = IDLE;
        endcase
    end

    // --- Data Latching Logic (Configuration) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            config_done_flag <= 1'b0;
        end else begin
            if (config_en) begin
                // Route Configuration (config_en=0 specified in prompt, but here config_en=1 for query?)
                // Prompt: config_en=0 (Route), config_en=1 (Query)
                // Wait, prompt says: "config_en: 1-bit select signal (0=Route config, 1=Query config)"
                // But also: "Configuration Protocol: 1. Routes (config_en=0) ... 2. Queries (config_en=1)"
                // This means we latch based on config_en value when in IDLE or CONFIG_LOAD state.
                // However, `config_en` is an input signal, not a state.
                // We assume `config_en` is high during the configuration cycles.
                
                if (!config_en) begin
                    // Route config
                    if (config_city_idx == 0) begin
                        // First byte is length
                        if (data_in[7:3] <= MAX_CITIES) begin // Limit check
                            // We expect length K. Then K cities.
                            // If length is 0, we are done with this truck?
                            // Let's store length
                            // We store length temporarily or directly?
                            // Let's store directly.
                            if (data_in[7:0] > 0) begin
                                truck_lengths[addr_in] <= data_in[3:0]; // Assuming 4-bit length fits
                            end else begin
                                truck_lengths[addr_in] <= 4'd0;
                            end
                            config_city_idx <= 4'd1; // Move to first city
                        end
                    end else begin
                        // Storing cities
                        // Check if we exceeded length
                        if (config_city_idx <= truck_lengths[addr_in]) begin
                             truck_routes[addr_in][config_city_idx - 1] <= data_in;
                             config_city_idx <= config_city_idx + 4'd1;
                        end
                        // If we finished cities for this truck, reset index for next truck
                        if (config_city_idx == truck_lengths[addr_in]) begin
                             config_city_idx <= 4'd0;
                        end
                    end
                end else begin
                    // Query config
                    // config_en = 1. addr_in selects query ID. data_in is [A, B].
                    query_pairs[addr_in] <= data_in;
                    // Mark that we have config data (though specific query might be set)
                    config_done_flag <= 1'b1;
                end
            end
        end
    end

    // --- Intersection Logic (Combinational) ---
    // This block calculates the intersection for the current segments defined by seg_a_idx and seg_b_idx
    // We will use intermediate wires for the math to keep it clean.
    
    wire [7:0] p_a1, p_a2;
    wire [7:0] p_b1, p_b2;
    wire [15:0] t_a1, t_a2, t_b1, t_b2;
    wire [15:0] den, num_t;
    wire [31:0] den_full, num_full; // 32-bit for multiplication
    wire intersect_valid;
    wire [15:0] t_intersect;
    
    // Helper to compute cumulative time (summation of distances)
    // We need T_A1 for seg_a_idx. It's the sum of abs diff of cities 0..seg_a_idx
    // Since we are in a sequential block, we can't easily have dynamic loops.
    // However, we are in CALC_INTERSECT state, iterating one step at a time.
    // We can compute T_A1 by adding to a running accumulator? 
    // No, because seg_b_idx resets. T_A1 depends only on seg_a_idx.
    // 
    // Solution: 
    // 1. Use a combinational function or logic to calculate T_A1 based on seg_a_idx.
    // 2. Since max 8 cities, we can unroll or use a small loop in generate (complex) or just chain logic.
    // Let's use a pre-calculation approach: T_A1 is just the sum of |diff| for previous segments.
    // 
    // However, `truck_routes` is `reg`. We can read it combinationally.
    // 
    // Let's define the segment points directly:
    assign p_a1 = truck_routes[truck_a_id][seg_a_idx];
    assign p_a2 = truck_routes[truck_a_id][seg_a_idx + 4'd1];
    assign p_b1 = truck_routes[truck_b_id][seg_b_idx];
    assign p_b2 = truck_routes[truck_b_id][seg_b_idx + 4'd1];

    // Calculate Durations (unsigned)
    wire [7:0] dur_a_raw = (p_a2 > p_a1) ? (p_a2 - p_a1) : (p_a1 - p_a2);
    wire [7:0] dur_b_raw = (p_b2 > p_b1) ? (p_b2 - p_b1) : (p_b1 - p_b2);
    wire [15:0] dur_a = {8'd0, dur_a_raw};
    wire [15:0] dur_b = {8'd0, dur_b_raw};
    
    // Calculate Cumulative Start Times
    // This is the tricky part. We need a running sum.
    // To avoid sequential dependency in the combinational block, we will use a lookup logic.
    // We can compute T_A1 by summing up to seg_a_idx.
    // Let's define a function-like block using assign statements for every possible index.
    // Since seg_a_idx is 0..6, we can use ternary operators.
    // 
    // T_A1 = sum(|truck_a[k+1] - truck_a[k]|) for k=0 to seg_a_idx-1
    // T_B1 = sum(|truck_b[k+1] - truck_b[k]|) for k=0 to seg_b_idx-1
    
    // We will use a helper wire array for cumulative times? 
    // No, explicit logic for 8 cities is manageable.
    
    wire [15:0] t_a1_calc;
    wire [15:0] t_b1_calc;
    
    // We need to index the array in the combinational block. 
    // Note: Verilog doesn't allow variable index in continuous assign easily if the array is 2D reg.
    // We can do: assign t_a1_calc = (seg_a_idx == 0) ? 0 : ...
    // But accessing array requires procedural block or logic.
    // We can move this calculation into the always block (sensitivity list *).*
    // Or, we can break the FSM CALC_INTERSECT state into sub-states to compute T_A1 sequentially.
    // 
    // Given the complexity, let's modify the FSM slightly.
    // We will calculate T_A1 and T_B1 at the start of CALC_INTERSECT or store them.
    // 
    // Revised Plan for CALC_INTERSECT state:
    // We will use a sub-state machine or a counter to perform the math in multiple cycles.
    // Cycle 1: Load points, calculate durations.
    // Cycle 2: Calculate Cumulative Times (requires summation).
    // Cycle 3: Calculate Intersection.
    // 
    // Or, we can do the summation logic purely combinationally if we flatten the array access.
    // Since we can't use loops easily in combinational blocks without `for` (which is synthesizable but caution for Icarus),
    // let's write the summation explicitly.
    
    // BUT, we can use the fact that we iterate sequentially. 
    // If we are in CALC_INTERSECT, we can maintain T_A1 register that increments.
    // However, we have nested loops (seg_a and seg_b).
    // T_A1 changes only when seg_a_idx increments.
    // T_B1 changes only when seg_b_idx increments.
    // 
    // Let's add registers for current start times.
    reg [15:0] curr_t_a_start;
    reg [15:0] curr_t_b_start;
    
    // Logic to update these times in the FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_t_a_start <= 16'd0;
            curr_t_b_start <= 16'd0;
        end else begin
            if (state == PROCESS_SETUP) begin
                curr_t_a_start <= 16'd0;
                curr_t_b_start <= 16'd0;
            end else if (state == CALC_INTERSECT) begin
                // Update logic for the next iteration happens after calculation?
                // No, let's calculate for CURRENT iteration first.
                // We update counters AFTER checking.
                
                // But we need T_A1 for current seg_a_idx.
                // At start of CALC_INTERSECT, curr_t_a_start holds the time for seg_a_idx.
                // When we move to next seg_b_idx, T_A1 stays same.
                // When we move to next seg_a_idx, T_A1 increments by previous duration.
            end
        end
    end

    // --- Math Calculation Block (Combinational) ---
    // This uses the `curr_t_a_start` and `curr_t_b_start` registers defined above.
    // We need to fetch the duration of the CURRENT segment to pass to the next iteration.
    
    // Let's calculate T_A2 = T_A1 + Dur_A
    // T_B2 = T_B1 + Dur_B
    
    wire [15:0] t_a2_calc = curr_t_a_start + dur_a;
    wire [15:0] t_b2_calc = curr_t_b_start + dur_b;
    
    // Intersection Math (Determinant method)
    // Line A: (t_a1, p_a1) -> (t_a2, p_a2)
    // Line B: (t_b1, p_b1) -> (t_b2, p_b2)
    
    // Slope (Velocity) is implicit in the line equation.
    // Intersection check using cross product of vectors (t, p)
    // Denom = (p_a2 - p_a1)*(t_b2 - t_b1) - (p_b2 - p_b1)*(t_a2 - t_a1)
    // Note: (t_b2 - t_b1) is dur_b. (t_a2 - t_a1) is dur_a.
    
    wire signed [15:0] dp_a = $signed({1'b0, p_a2}) - $signed({1'b0, p_a1});
    wire signed [15:0] dp_b = $signed({1'b0, p_b2}) - $signed({1'b0, p_b1});
    wire signed [15:0] dt_a = $signed(dur_a);
    wire signed [15:0] dt_b = $signed(dur_b);
    
    wire signed [31:0] den_signed = (dp_a * dt_b) - (dp_b * dt_a);
    
    // If Denom == 0, lines are parallel. We ignore (return invalid).
    wire parallel = (den_signed == 0);
    
    // Numerator for T (Time of intersection)
    // Formula derived from:
    // (p_a1 * dt_a + v_a * t * dt_a) ... actually simpler:
    // (p_a1 * dt_a + (p_a2-p_a1)*(t-t_a1)) ... no.
    // Standard formula: 
    // Num_T = (p_a1*dt_a - p_a2*dt_a) * dt_b - (p_b1*dt_b - p_b2*dt_b) * dt_a  ? No.
    
    // Let's use the explicit formula from the hint description:
    // (p2-p1)*(t4-t3) != (p4-p3)*(t2-t1)
    // Solve for t: 
    // t = ( (p3 - p1)*(t2 - t1)*(t4 - t3) - (p4 - p3)*(t2 - t1)*(t2 - t1) ) / Denom  (Approx)
    
    // Correct formula for intersection of line segments in (t, p) plane:
    // t = ( (p_a1 - p_b1)*dt_a*dt_b + ... ) / Denom ?
    // 
    // Let's stick to the parametric solution:
    // p_a1 + (p_a2 - p_a1) * (t - t_a1) / (t_a2 - t_a1) = p_b1 + (p_b2 - p_b1) * (t - t_b1) / (t_b2 - t_b1)
    // Let v_a = (p_a2 - p_a1) / (t_a2 - t_a1) = dp_a / dt_a
    // p_a1 - v_a*t_a1 + v_a*t = p_b1 - v_b*t_b1 + v_b*t
    // t*(v_a - v_b) = p_b1 - p_a1 - v_b*t_b1 + v_a*t_a1
    // t = (p_b1 - p_a1 - v_b*t_b1 + v_a*t_a1) / (v_a - v_b)
    
    // Multiply by denominators to avoid floats:
    // t * (dp_a/dt_a - dp_b/dt_b) = (p_b1 - p_a1) - (dp_b/dt_b)*t_b1 + (dp_a/dt_a)*t_a1
    // t * (dp_a*dt_b - dp_b*dt_a) / (dt_a*dt_b) = ...
    // t * Denom = (p_b1 - p_a1)*dt_a*dt_b - dp_b*t_b1*dt_a + dp_a*t_a1*dt_b
    
    wire signed [31:0] term1 = $signed({8'd0, p_b1}) - $signed({8'd0, p_a1});
    wire signed [63:0] num_full_signed = (term1 * dt_a * dt_b) - (dp_b * $signed(curr_t_b_start) * dt_a) + (dp_a * $signed(curr_t_a_start) * dt_b);
    
    // Note: Widths are getting large. 16x16x16 = 48 bits. 
    // To fit in 32-bit logic, we might need to truncate or simplify.
    // Given the small range (0-127 pos, 0-~100 time), 16-bit math should be sufficient if we are careful.
    // Let's try to keep it 32-bit where possible.
    
    // Let's simplify the numerator calculation:
    // We want t. t = Num / Den.
    // Num = (p_b1 - p_a1)*dt_a*dt_b - dp_b*t_b1*dt_a + dp_a*t_a1*dt_b
    // Den = dp_a*dt_b - dp_b*dt_a
    
    // All variables are 16-bit signed. Result t is 16-bit.
    // We can calculate this in 32-bit intermediate.
    
    // Let's assume we use 32-bit intermediate registers for the math.
    reg [31:0] num_reg;
    reg [31:0] den_reg;
    reg [15:0] t_intersect_reg;
    reg valid_reg;
    
    // Combinational calculation block (updated whenever inputs change)
    always @(*) begin
        // Defaults
        num_reg = 32'd0;
        den_reg = 32'd0;
        t_intersect_reg = 16'd0;
        valid_reg = 1'b0;
        
        // Check for valid segment lengths (non-zero duration)
        if (dur_a != 0 && dur_b != 0) begin
            // Calculate Denom
            den_reg = (dp_a * dt_b) - (dp_b * dt_a);
            
            if (den_reg != 0) begin
                // Calculate Num
                // Num = (p_b1 - p_a1)*dt_a*dt_b - dp_b*t_b1*dt_a + dp_a*t_a1*dt_b
                // Note: curr_t_a_start and curr_t_b_start are [15:0], treat as signed for math
                
                num_reg = ((($signed({1'b0, p_b1}) - $signed({1'b0, p_a1})) * dt_a * dt_b)) -
                          (dp_b * $signed(curr_t_b_start) * dt_a) +
                          (dp_a * $signed(curr_t_a_start) * dt_b);
                
                // Divide Num by Den to get t
                // Since we are in hardware, we use integer division.
                // Check sign consistency.
                
                // Perform division
                if (num_reg[31] == den_reg[31]) begin
                    t_intersect_reg = num_reg / den_reg;
                end else begin
                    t_intersect_reg = 16'hFFFF; // Negative result (should not happen for t > 0)
                end
                
                // Check if t is strictly inside (t_a1, t_a2) and (t_b1, t_b2)
                // Inclusive or exclusive? "strictly inside" implies exclusive.
                // Check t > t_a1 && t < t_a2
                // Check t > t_b1 && t < t_b2
                
                if (t_intersect_reg > curr_t_a_start && t_intersect_reg < t_a2_calc &&
                    t_intersect_reg > curr_t_b_start && t_intersect_reg < t_b2_calc) begin
                    valid_reg = 1'b1;
                end
            end
        end
    end

    // --- Update Counters and Times in FSM ---
    // We need to modify the CALC_INTERSECT state transition logic slightly to handle the loop increments.
    // Since we separated combinational logic, we can use `valid_reg` to increment `encounter_count`.
    // And we need to update `seg_b_idx`, `seg_a_idx`, `curr_t_a_start`, `curr_t_b_start`.
    
    // We need to modify the ALWAYS block above to handle these increments.
    // However, the ALWAYS block is already complex. 
    // Let's add the increment logic inside the CALC_INTERSECT branch of the ALWAYS block.
    
    // We will use a `next_seg_a_idx`, `next_seg_b_idx` logic.
    // But we can do it sequentially inside the always block.
    
    // Revising the CALC_INTERSECT state in the sequential block:
    // ...
    // In CALC_INTERSECT:
    //   if (valid_reg) encounter_count <= encounter_count + 1;
    //   
    //   // Next iteration logic
    //   if (seg_b_idx < num_segs_b - 1) begin
    //       seg_b_idx <= seg_b_idx + 1;
    //       // T_B_start increments by current segment duration
    //       curr_t_b_start <= curr_t_b_start + dur_b;
    //   end else begin
    //       seg_b_idx <= 0;
    //       curr_t_b_start <= 16'd0;
    //       if (seg_a_idx < num_segs_a - 1) begin
    //           seg_a_idx <= seg_a_idx + 1;
    //           // T_A_start increments by current segment duration
    //           curr_t_a_start <= curr_t_a_start + dur_a;
    //       end else begin
    //           // Done
    //       end
    //   end
    // ...
    
    // NOTE: We must ensure we don't overlap calculation and update in the same cycle causing race.
    // The calculation is combinational, so `valid_reg` updates immediately based on current indices.
    // When we update indices in the clock cycle, the result for the NEW indices will be computed 
    // for the NEXT cycle. This is correct.
    
    // Let's update the main FSM block with this logic.
    // We need to add `valid_reg` and the math block signals to the sensitivity list or handle them inside.
    // Since `valid_reg` is a reg defined in a combinational block, we can read it in the sequential block.
    
    // --- Integration of Logic into Main FSM ---
    // (Modifying the CALC_INTERSECT section of the first always block)
    
    // We need to declare `valid_reg`, `dur_a`, `dur_b` etc. accessible.
    // They are declared as wires/regs above.
    
    // --- Final State Machine Adjustment ---
    // We need to ensure we don't update `seg_a_idx` when we are done.
    
    // Let's modify the CALC_INTERSECT branch of the main FSM (State transition logic) to be precise.

    // Re-writing the State Transition Logic for CALC_INTERSECT:
    // The logic `next_state = CALC_INTERSECT` depends on indices.
    // We used `seg_b_idx >= num_segs_b - 1` etc.
    // This needs to be updated after the cycle where we check the last pair.
    // 
    // Logic:
    // In state CALC_INTERSECT:
    //   // Check intersection (done combinationally)
    //   // If (seg_a_idx == num_segs_a - 1) AND (seg_b_idx == num_segs_b - 1) -> Transition to OUTPUT
    //   // Else, update indices/accumulators.
    
    // --- Simplified Loop Control ---
    // Instead of complex index updates in combinational logic, let's use a counter for the loop.
    // Total pairs = num_segs_a * num_segs_b.
    // We can iterate `pair_index` from 0 to TotalPairs-1.
    // Current A = pair_index / num_segs_b
    // Current B = pair_index % num_segs_b
    // This requires division/modulo, which is heavy.
    
    // Stick to the nested loop structure but fix the transition conditions.
    // The conditions in `next_state` logic must reflect the *updated* state of indices.
    // 
    // Let's use the `cycle_counter` to limit processing time per query to avoid hanging.

    // --- Inserting the Logic Updates into the Main Block ---
    // We need to add the logic for `valid_reg` calculation and index updates.
    // The code block provided above sets up the structure. We need to fill in the missing parts.
    
    // We will insert the logic for `curr_t_a_start` and `curr_t_b_start` updates inside the CALC_INTERSECT block.
    
    // Since the code block is monolithic, we can refer to the variables defined here.
    // Note: The variables `valid_reg`, `dur_a`, `dur_b` are combinational.
    // We must read them in the sequential block.
    
    // Let's refine the `CALC_INTERSECT` state in the sequential block:
    
    // inside the always @(posedge clk) block:
    /*
    CALC_INTERSECT: begin
        // Timeout
        cycle_counter <= cycle_counter + 8'd1;
        
        // 1. Update Count if intersection found
        if (valid_reg) begin
            encounter_count <= encounter_count + 8'd1;
        end
        
        // 2. Update Indices for next cycle
        // If not at end of B loop
        if (seg_b_idx < num_segs_b - 1) begin
            seg_b_idx <= seg_b_idx + 4'd1;
            // Update B cumulative time
            curr_t_b_start <= curr_t_b_start + dur_b;
        end else begin
            // End of B loop, reset B, advance A
            seg_b_idx <= 4'd0;
            curr_t_b_start <= 16'd0;
            
            if (seg_a_idx < num_segs_a - 1) begin
                seg_a_idx <= seg_a_idx + 4'd1;
                // Update A cumulative time
                curr_t_a_start <= curr_t_a_start + dur_a;
            end
            // If A is also at end, we stay here for one cycle to latch the last result?
            // The next_state logic will move us to OUTPUT on the next cycle.
        end
    end
    */
    
    // We need to make sure `valid_reg` calculation uses the correct `curr_t_a_start`.
    // The combinational block updates `valid_reg` whenever `curr_t_a_start` changes.
    // In the cycle where we update `curr_t_a_start`, `valid_reg` will reflect the NEW segment.
    // This is fine, we just need to latch the count for the OLD segment BEFORE updating.
    
    // Actually, standard FSM: 
    // Cycle T: State=CALC. Indices are 0,0. valid_reg=0.
    // Cycle T+1: Indices updated to 0,1. valid_reg updates to 0 or 1 based on 0,1.
    // The check happens on the next cycle.
    // We are checking the CURRENT pair (indices stable during the cycle).
    // So we read `valid_reg` in the clocked block.
    
    // Wait, if we update indices in the clocked block, the update happens at the clock edge.
    // The combinational `valid_reg` depends on indices. 
    // At the rising edge, indices change -> valid_reg updates after combinational delay.
    // The clocked block reads `valid_reg` (which is valid after delay).
    // But the clocked block is sensitive to posedge clk. 
    // We are reading `valid_reg` in the same cycle as indices update?
    // No, the code:
    // always @(posedge clk) ...
    // inside: if (valid_reg) ...
    // This checks `valid_reg` based on the indices present BEFORE the clock edge (or just after?
    // In Verilog, `always @(posedge clk)` uses values from immediately before the edge or after combinational delay?
    // It depends on synthesis. Usually, it uses values stable before the edge.
    // If we update indices on the edge, `valid_reg` takes time to update.
    // So we are effectively checking the PREVIOUS pair.
    // 
    // Correct Approach:
    // Check `valid_reg` of the *current* pair.
    // Update indices to move to the *next* pair.
    // This means we are always 1 cycle behind the loop logic, but it works.
    // 
    // However, we need to handle the start of the loop.
    // At PROCESS_SETUP -> CALC_INTERSECT. Indices 0,0.
    // Cycle 1 (CALC state): Check intersection for (0,0). Update indices -> (0,1).
    // Cycle 2: Check (0,1). Update -> (0,2).
    // ...
    // 
    // This seems correct.

    // --- Fixing the Transition Logic ---
    // In `next_state` logic, we need to know if we are DONE.
    // But `next_state` is combinational and reads current indices.
    // 
    // Condition: 
    // If we are in CALC_INTERSECT and current indices are (lastA, lastB),
    // and we have just processed them (in the previous cycle's update logic),
    // we should transition to OUTPUT.
    // 
    // Problem: The indices update in the cycle. 
    // We need a flag `loop_finished`.
    // 
    // Let's use a flag `processing` inside the FSM.
    // Or, simpler: Use the `cycle_counter` or index check.
    // 
    // If `seg_a_idx == num_segs_a - 1` AND `seg_b_idx == num_segs_b - 1`:
    // We are at the last pair. We process it this cycle.
    // Next cycle, we should move to OUTPUT.
    // BUT, we update indices in the same cycle as checking.
    // 
    // Let's add a `done_processing` wire.
    wire done_processing = (seg_a_idx == num_segs_a - 1) && (seg_b_idx == num_segs_b - 1);
    
    // In the FSM next_state logic:
    // if (state == CALC_INTERSECT) begin
    //     if (done_processing) next_state = OUTPUT_RESULT;
    //     else next_state = CALC_INTERSECT;
    // end
    
    // Wait, if we update indices immediately, `done_processing` becomes false in the next cycle.
    // We need to delay the update or the check.
    // 
    // Revised Update Logic in Sequential Block:
    // if (state == CALC_INTERSECT) begin
    //     if (valid_reg) encounter_count <= encounter_count + 1;
    //     
    //     if (done_processing) begin
    //         // Don't update indices, just move to OUTPUT
    //     end else begin
    //         // Update indices
    //     end
    // end
    
    // This works. If we are at the last pair, we count it (if valid) and transition.
    // 
    // Need to handle case where num_segs_a or num_segs_b is 0.
    // Handled in PROCESS_SETUP.

endmodule
