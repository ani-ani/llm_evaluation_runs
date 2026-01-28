module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] k_in,
    input wire city_valid,
    input wire [31:0] city_x,
    input wire [31:0] city_y,
    input wire [15:0] city_pop,
    output reg result_valid,
    output reg [31:0] result_dist_sq,
    output reg busy
);

    // Constants
    localparam [3:0] MAX_N = 4'd16;
    localparam [6:0] MAX_EDGES = 7'd120; // 16*15/2
    localparam [5:0] MAX_EDGES_PER_STATE = 6'd30; // Process 30 edges per cycle to finish in time
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] GEN_EDGES = 3'd2;
    localparam [2:0] SORT_EDGES = 3'd3;
    localparam [2:0] CHECK_CONDITION = 3'd4;
    localparam [2:0] DONE = 3'd5;
    
    reg [2:0] state, next_state;
    
    // City Data Memory (packed for synthesis)
    reg [31:0] city_x_reg [0:15];
    reg [31:0] city_y_reg [0:15];
    reg [15:0] city_pop_reg [0:15];
    
    // Input counters
    reg [3:0] city_idx;
    reg [3:0] n_val;
    reg [3:0] k_val;
    
    // Edge Storage: Packed: [63:32] dist_sq, [31:16] city_b, [15:0] city_a
    reg [63:0] edges [0:119];
    reg [6:0] edge_count;
    reg [6:0] sort_limit;
    
    // Sorting registers
    reg [6:0] sort_idx;
    reg swap_flag;
    
    // DSU and Remainder Sets
    reg [3:0] parent [0:15];
    reg [15:0] rem_set [0:15]; // Bitmask of possible remainders
    reg [3:0] dsu_i;
    reg [3:0] dsu_j;
    reg dsu_busy;
    
    // Result finding logic
    reg [6:0] edge_proc_idx;
    reg condition_met;
    
    // Loop integer
    integer i;
    
    // --- FSM Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            result_valid <= 1'b0;
            result_dist_sq <= 32'd0;
            city_idx <= 4'd0;
            n_val <= 4'd0;
            k_val <= 4'd0;
            edge_count <= 7'd0;
            for (i = 0; i < 120; i = i + 1) edges[i] <= 64'd0;
            for (i = 0; i < 16; i = i + 1) begin
                city_x_reg[i] <= 32'd0;
                city_y_reg[i] <= 32'd0;
                city_pop_reg[i] <= 16'd0;
                parent[i] <= 4'd0;
                rem_set[i] <= 16'd0;
            end
            dsu_busy <= 1'b0;
            condition_met <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        n_val <= n_in;
                        k_val <= k_in;
                        city_idx <= 4'd0;
                    end
                end
                
                LOAD: begin
                    if (city_valid && city_idx < n_val) begin
                        city_x_reg[city_idx] <= city_x;
                        city_y_reg[city_idx] <= city_y;
                        city_pop_reg[city_idx] <= city_pop;
                        city_idx <= city_idx + 4'd1;
                    end
                end
                
                GEN_EDGES: begin
                    // Combinational generation logic is complex in hardware, 
                    // so we do it iteratively here or use a helper state.
                    // We'll generate a few edges per cycle to save area/time.
                    // Since N is small, we can generate all in one go if logic fits,
                    // but iterative is safer. Let's assume we need to store them.
                    // Actually, for 16 cities, 120 edges is small. 
                    // We will generate sequentially in CHECK_CONDITION phase 
                    // to save memory usage on edge sorting!
                    // If we sort, we need memory. Let's stick to generating on fly.
                    // REVISION: The prompt asks for sorting. We must sort.
                    // We will generate edges in a loop state.
                end
                
                SORT_EDGES: begin
                    // Bubble sort one pass per state entry or multiple swaps
                    // We will swap if needed
                    if (swap_flag) begin
                        edges[sort_idx] <= edges[sort_idx + 7'd1];
                        edges[sort_idx + 7'd1] <= edges[sort_idx];
                    end
                end
                
                CHECK_CONDITION: begin
                    // DSU Updates happen here
                    if (dsu_busy) begin
                        // DSU Find A
                        if (parent[dsu_i] != dsu_i) begin
                            // Path compression (simplified: just return root for now)
                            dsu_i <= parent[dsu_i];
                        end else begin
                            // Found root A
                            // DSU Find B (handled in next cycle logic ideally, but let's simplify)
                            // We need a multi-cycle DSU logic or simple logic.
                            // Let's use a simplified non-compressing logic or assume 1 cycle find.
                            // For 16 nodes, iterative find is fast.
                        end
                    end
                end
                
                DONE: begin
                    result_valid <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end
    
    // --- Next State Logic ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD;
            
            LOAD: if (city_idx >= n_val) next_state = GEN_EDGES;
            
            GEN_EDGES: begin
                // Assume edges are generated and stored in a few cycles
                // For simplicity in this code block, we jump to sort
                // Real implementation would need a counter to generate all pairs
                next_state = SORT_EDGES;
            end
            
            SORT_EDGES: begin
                // Bubble sort logic
                // If sorted, move to CHECK
                // This is tricky in pure combinational next_state logic without counters.
                // We'll need internal sort counters.
                next_state = CHECK_CONDITION; // Default pass
            end
            
            CHECK_CONDITION: begin
                if (condition_met) next_state = DONE;
                else next_state = DONE; // If no solution found, output max or fail
            end
            
            DONE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // --- Helper Logic: Edge Generation ---
    // Since we need to store edges for sorting, we need a generation process.
    // Let's add explicit generation counters.
    reg [3:0] gen_i, gen_j;
    reg [63:0] dist_sq_temp;
    reg [63:0] dx, dy;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gen_i <= 4'd0;
            gen_j <= 4'd0;
            edge_count <= 7'd0;
        end else if (state == GEN_EDGES) begin
            if (gen_i < n_val) begin
                if (gen_j < n_val) begin
                    if (gen_i < gen_j) begin
                        // Calculate squared distance
                        // dx = x_j - x_i
                        // dy = y_j - y_i
                        // Q16.16 subtraction
                        // We only care about integer part for sorting usually, 
                        // but let's do full Q16.16 math for accuracy.
                        // For squared: (dx*dx + dy*dy). 
                        // dx is Q16.16, dx*dx is Q32.32. 
                        // We can keep result as Q32.32 or trunc lower bits.
                        // Let's keep 64-bit result.
                        
                        // Hardware multiplier instantiation or logic:
                        // Since this is behavioral, we use standard operators.
                        // Note: Synthesis tool will infer multipliers.
                        
                        // We calculate here combinationaly but register the result
                        // To avoid long paths, we might need to pipeline, 
                        // but for 16 nodes, it's fine.
                        dist_sq_temp = 0; // Placeholder for calculation
                        // Actual calculation logic would go here in a real implementation
                        // For the sake of this constrained module, we approximate.
                        // If we were to implement fully:
                        // wire signed [31:0] dx = city_x_reg[gen_j] - city_x_reg[gen_i];
                        // wire signed [31:0] dy = city_y_reg[gen_j] - city_y_reg[gen_i];
                        // wire [63:0] sq = (dx * dx) + (dy * dy);
                        
                        // Store edge
                        edges[edge_count] <= {32'd0, gen_j, gen_i}; // dist set to 0 for now, corrected in sort phase or pre-calc
                        edge_count <= edge_count + 7'd1;
                    end
                    gen_j <= gen_j + 4'd1;
                end else begin
                    gen_j <= 4'd0;
                    gen_i <= gen_i + 4'd1;
                end
            end
        end
    end

    // --- Fix: Integrating calculations into a cleaner flow ---
    // To make this synthesizable and correct, we merge the logic.
    // The previous logic was split. Let's rewrite the core body to be robust.
    
endmodule

module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] k_in,
    input wire city_valid,
    input wire [31:0] city_x,
    input wire [31:0] city_y,
    input wire [15:0] city_pop,
    output reg result_valid,
    output reg [31:0] result_dist_sq,
    output reg busy
);

    // --- States ---
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_CITIES = 3'd1;
    localparam [2:0] PREPARE_EDGES = 3'd2;
    localparam [2:0] SORT_EDGES = 3'd3;
    localparam [2:0] PROCESS_EDGES = 3'd4;
    localparam [2:0] FINISHED = 3'd5;

    reg [2:0] state, next_state;

    // --- Storage ---
    reg [31:0] cx [0:15];
    reg [31:0] cy [0:15];
    reg [15:0] cp [0:15];
    
    // Edge format: {dist_sq[31:0], city_b[3:0], city_a[3:0]} -> 39 bits total
    // We use 64-bit for alignment, upper bits zero
    reg [63:0] edges [0:119];
    
    // DSU state
    reg [3:0] parent [0:15];
    reg [15:0] comp_mask [0:15];
    
    // --- Registers ---
    reg [3:0] n_val, k_val;
    reg [3:0] idx; // General purpose index
    reg [3:0] idx2;
    reg [6:0] edge_cnt;
    reg [6:0] sort_idx;
    reg [6:0] proc_idx;
    reg signed [31:0] dx, dy;
    reg [63:0] temp_dist;
    reg [3:0] root_a, root_b;
    reg [15:0] temp_mask;
    
    // --- Helpers for DSU ---
    reg [3:0] find_a, find_b;
    reg find_a_done, find_b_done;
    reg [3:0] path_stack [0:15]; // Small stack for find path
    reg [3:0] stack_ptr;
    
    integer i;

    // --- FSM & Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            result_valid <= 1'b0;
            result_dist_sq <= 32'hFFFFFFFF; // Default invalid
            for (i = 0; i < 16; i = i + 1) begin
                cx[i] <= 32'd0;
                cy[i] <= 32'd0;
                cp[i] <= 16'd0;
            end
            edge_cnt <= 7'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        n_val <= n_in;
                        k_val <= k_in;
                        idx <= 4'd0;
                    end
                end

                LOAD_CITIES: begin
                    if (city_valid && idx < n_val) begin
                        cx[idx] <= city_x;
                        cy[idx] <= city_y;
                        cp[idx] <= city_pop;
                        idx <= idx + 4'd1;
                    end
                end

                PREPARE_EDGES: begin
                    // Generate all edges
                    if (idx < n_val) begin
                        if (idx2 < n_val) begin
                            if (idx < idx2) begin
                                // Calculate squared distance
                                // dx = cx[idx2] - cx[idx] (Q16.16)
                                // dy = cy[idx2] - cy[idx]
                                dx <= cx[idx2] - cx[idx];
                                dy <= cy[idx2] - cy[idx];
                                // We use a next-cycle calculation for product to keep timing clean
                                // But for Verilog, we can do it inline if we register later.
                                // Let's calculate temp_dist in logic.
                                edges[edge_cnt][15:0] <= {idx[3:0], idx2[3:0]}; // Store IDs
                                edge_cnt <= edge_cnt + 7'd1;
                            end
                            idx2 <= idx2 + 4'd1;
                        end else begin
                            idx2 <= 4'd0;
                            idx <= idx + 4'd1;
                        end
                    end
                end
                
                // We need a cycle to compute the distance product to avoid timing issues
                // Actually, let's combine PREPARE and DIST_CALC.
                // Revised approach: Generate 1 edge per cycle or use comb logic.
                // For 120 edges, sequential generation is fine.
                
                SORT_EDGES: begin
                    // Bubble sort: iterate through list
                    // We swap if distance of sort_idx > distance of sort_idx+1
                    // Logic is combinational for comparison, registered for swap
                    // To save space, we do one pass per state visit or use index tracking.
                    // Let's do a standard bubble sort pass logic here (combinational check)
                    // We need to keep track of sorted status.
                    // For this code, we assume a simple sort loop.
                    // We will increment sort_idx. If swap needed, we swap and set a flag.
                    // Actually, sorting 120 elements in 10k cycles is easy.
                    // We'll do: if edges[sort_idx][63:32] > edges[sort_idx+1][63:32], swap.
                end

                PROCESS_EDGES: begin
                    // DSU Logic
                    // 1. Find Root of A
                    // 2. Find Root of B
                    // 3. If different, Merge and Update Mask
                    // 4. Check if mask has bit 0 set.
                    // We need multiple cycles for this.
                    
                    // We will use a simple sequential logic for DSU
                    if (proc_idx < edge_cnt) begin
                        // We iterate here
                    end
                end

                FINISHED: begin
                    result_valid <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end

    // --- Combinational Logic for Distance Calculation (in PREPARE_EDGES) ---
    // We split the generation to calculate products.
    // Since we need to calculate distance for sorting, we must store it properly.
    // Let's refine the PREPARE_EDGES state to actually fill the distance field.
    
    // --- DSU Helper Logic (Find with Path Compression) ---
    // Recursive/Iterative find in hardware is tricky. 
    // We will implement a non-recursive find for small N.
    
    reg [3:0] current_find_node;
    reg [3:0] find_root_result;
    reg finding_root;
    
    // --- Next State Logic ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD_CITIES;
            
            LOAD_CITIES: if (idx >= n_val) next_state = PREPARE_EDGES;
            
            PREPARE_EDGES: begin
                // We need to generate 120 edges. 
                // To make it simple, we jump to SORT after a few cycles, 
                // but we must ensure edges are ready.
                // We use a separate counter for edge generation loop.
                // Let's assume we do this in a loop state or integrated.
                // If idx >= n_val AND idx2 >= n_val, we are done.
                if (idx >= n_val) next_state = SORT_EDGES;
            end
            
            SORT_EDGES: begin
                // Bubble sort finish condition: sort_idx reaches end without swaps or fixed iterations
                // We will perform a fixed number of passes (N^2) or track swaps.
                // For N=120, 120 passes is safe.
                // We increment sort_idx. When sort_idx reaches edge_cnt-1, reset to 0 and increment pass counter.
                // If pass counter >= edge_cnt, done.
                // Simplified: Just run for fixed cycles (e.g., 200 cycles) to ensure sorted.
                // Or check if sorted. Let's use a generic "SORTING" loop.
                // We will move to PROCESS when sorting is deemed complete.
                // For this code, let's assume a simple pass-based approach.
                // If we are done sorting (tracked via internal counter), go to PROCESS.
                if (/* sort complete */) next_state = PROCESS_EDGES;
            end
            
            PROCESS_EDGES: begin
                if (proc_idx >= edge_cnt || condition_met) next_state = FINISHED;
            end
            
            FINISHED: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // --- Logic Blocks for Details ---
    // To make this synthesizable and concise, we combine some logic.
    
    // 1. Edge Generation & Distance Calc
    reg [6:0] gen_i, gen_j;
    always @(posedge clk) begin
        if (state == PREPARE_EDGES) begin
            if (gen_i < n_val) begin
                if (gen_j < n_val) begin
                    if (gen_i < gen_j) begin
                        // Calculate distance squared
                        // dx = cx[gen_j] - cx[gen_i];
                        // dy = cy[gen_j] - cy[gen_i];
                        // product: (dx * dx) + (dy * dy)
                        // We need 32x32 multipliers.
                        // Let's assume we have a DSP block or logic.
                        // We will perform calculation in one cycle.
                        // Inputs are Q16.16, output is Q32.32. We take upper 32 bits for integer comparison (Q32.0)
                        // Or keep full 64 bit for accuracy.
                        // For simplicity in code, we calculate here.
                        
                        // Since this is a single always block logic, we need to be careful with combinational paths.
                        // We will register the calculation result in a temporary register before writing to edges array.
                        // To save space, we write to edges array directly but might need multi-cycle logic.
                        // We'll use a comb logic block for distance calc.
                    end
                    gen_j <= gen_j + 1;
                end else begin
                    gen_j <= 0;
                    gen_i <= gen_i + 1;
                end
            end
        end else begin
            gen_i <= 0;
            gen_j <= 0;
        end
    end

    // 2. Sorting Logic (Bubble Sort)
    // We need a state variable for sort pass index
    reg [6:0] sort_pass;
    
    always @(posedge clk) begin
        if (state == SORT_EDGES) begin
            if (sort_idx < edge_cnt - 1) begin
                // Compare dist_sq parts [63:32]
                if (edges[sort_idx][63:32] > edges[sort_idx + 1][63:32]) begin
                    // Swap
                    edges[sort_idx] <= edges[sort_idx + 1];
                    edges[sort_idx + 1] <= edges[sort_idx];
                end
                sort_idx <= sort_idx + 1;
            end else begin
                sort_idx <= 0;
                if (sort_pass < edge_cnt) sort_pass <= sort_pass + 1;
                // If sort_pass >= edge_cnt, we are done. Move to next state via next_state logic.
                // We need to hook this up.
            end
        end else begin
            sort_idx <= 0;
            sort_pass <= 0;
        end
    end

    // 3. DSU Processing
    // We need to find roots. This takes cycles.
    // We'll implement a sequential find.
    
    reg [1:0] dsu_phase; // 0: find root A, 1: find root B, 2: merge, 3: check
    reg [3:0] root_a_reg, root_b_reg;
    reg [3:0] u, v; // current edge cities
    
    always @(posedge clk) begin
        if (state == PROCESS_EDGES) begin
            case (dsu_phase)
                2'd0: begin // Find Root A
                    if (parent[u] == u) begin
                        root_a_reg <= u;
                        dsu_phase <= 2'd1;
                    end else begin
                        u <= parent[u];
                    end
                end
                2'd1: begin // Find Root B
                    if (parent[v] == v) begin
                        root_b_reg <= v;
                        dsu_phase <= 2'd2;
                    end else begin
                        v <= parent[v];
                    end
                end
                2'd2: begin // Merge
                    if (root_a_reg != root_b_reg) begin
                        // Merge B into A (arbitrary)
                        parent[root_b_reg] <= root_a_reg;
                        // Merge masks (Convolution)
                        // new_mask = mask[A] | mask[B] | ((mask[A] convolved with mask[B]) mod K)
                        // Since K <= 16, we can do this with a small loop or logic.
                        // For this code, we approximate the merge logic.
                        // We iterate r1 from 0 to K-1, r2 from 0 to K-1.
                        // We need a sub-iteration here.
                        // To avoid infinite states, we hardcode a "mask update" cycle.
                        // We will compute the new mask in a combinational block and register it.
                        temp_mask <= comp_mask[root_a_reg] | comp_mask[root_b_reg];
                        // Actually, we need a loop to compute convolution. 
                        // We can use a separate state or a helper loop.
                        // Let's use a simple logic: update mask in a few cycles.
                        dsu_phase <= 2'd3; // Proceed to check
                    end else begin
                        // Already connected, skip
                        dsu_phase <= 2'd3;
                    end
                end
                2'd3: begin // Check condition and Move to next edge
                    // Check if any component has remainder 0
                    // We only check the root of the merged component (or all? Prompt says "any connected component")
                    // For efficiency, we check roots. Since we updated root_a, check root_a.
                    if (comp_mask[root_a_reg][0]) begin
                        condition_met <= 1'b1;
                        result_dist_sq <= edges[proc_idx][63:32];
                    end
                    
                    // Next edge
                    proc_idx <= proc_idx + 1;
                    dsu_phase <= 2'd0;
                    // Load next edge cities
                    u <= edges[proc_idx + 1][3:0];
                    v <= edges[proc_idx + 1][7:4];
                end
            endcase
        end else begin
            // Initialize for processing
            proc_idx <= 0;
            dsu_phase <= 2'd0;
            condition_met <= 1'b0;
            // Initialize DSU
            if (state == PREPARE_EDGES) begin
                 for (i = 0; i < 16; i = i + 1) begin
                    parent[i] <= i[3:0];
                    // Initial mask: only population % K
                    // But prompt says: subset sum divisible by K.
                    // If we have a single city with pop P, remainder is P % K.
                    // Also remainder 0 is always possible? No, empty set sum is 0. 
                    // Wait, usually subset sum includes empty set (sum=0). 
                    // So remainder 0 is ALWAYS possible for any component.
                    // BUT, the problem implies non-empty subset? 
                    // "subset of cities whose population sum is divisible by K"
                    // Usually implies non-empty unless specified.
                    // Let's assume non-empty subset. 
                    // If empty set is allowed, answer is always D=0 (trivial).
                    // Assuming non-empty.
                    comp_mask[i] <= (1 << (cp[i] % k_val));
                 end
            end
        end
    end
    
    // --- Mask Convolution Logic (Combinational for the merge) ---
    // This is complex. We need to compute: set of (r1+r2)%K for r1 in maskA, r2 in maskB.
    // Since K is small (16), we can do this in one cycle using a lookup or loops.
    // We need to trigger this update when dsu_phase == 2'd2.
    // We will use a separate always block or integrate it.
    
    reg [15:0] conv_res;
    integer r1, r2;
    always @(*) begin
        conv_res = comp_mask[root_a_reg] | comp_mask[root_b_reg];
        // If we are merging, calculate combinations
        // This loop must be unrolled or static for synthesis.
        // For 16 bits, it's feasible.
        for (r1 = 0; r1 < 16; r1 = r1 + 1) begin
            for (r2 = 0; r2 < 16; r2 = r2 + 1) begin
                if (comp_mask[root_a_reg][r1] && comp_mask[root_b_reg][r2]) begin
                    conv_res[(r1 + r2) % 16] = 1'b1;
                end
            end
        end
    end
    
    // Register the result of convolution
    always @(posedge clk) begin
        if (state == PROCESS_EDGES && dsu_phase == 2'd2 && root_a_reg != root_b_reg) begin
            comp_mask[root_a_reg] <= conv_res;
        end
    end

    // --- Fixing Next State Logic for Sort ---
    // We need to track if sorting is done.
    // We'll add a variable or use existing ones.
    // If sort_pass >= edge_cnt, we are done.
    
    always @(*) begin
        if (state == SORT_EDGES) begin
            if (sort_pass >= edge_cnt) next_state = PROCESS_EDGES;
            else next_state = SORT_EDGES;
        end
    end

    // --- Tie up loose ends ---
    // We need to handle the case where K=0? No, K is 1-16.
    // We need to handle "no solution". 
    // If we finish PROCESS_EDGES without condition_met, we still need to output something.
    // The prompt asks for "minimal distance D". 
    // If no such D exists, we might output a max value or error.
    // We'll set a flag "found". If not found by end, result_dist_sq remains 0xFFFFFFFF.
    
    // Also, the distance calculation in PREPARE_EDGES needs to be explicit.
    // We added gen_i/gen_j logic but didn't hook up the calculation fully.
    // Let's add a helper block for that.
    
    // Calculate Dist Sq: (cx - cx)^2 + (cy - cy)^2
    wire signed [31:0] dx_wire = cx[gen_j] - cx[gen_i];
    wire signed [31:0] dy_wire = cy[gen_j] - cy[gen_i];
    wire [63:0] dist_sq_wire = (dx_wire * dx_wire) + (dy_wire * dy_wire);
    // We only care about the upper 32 bits for sorting (integer part) or full 64.
    // Q16.16 squared is Q32.32. For sorting, we can compare Q32.32.
    // Let's store the full 64-bit result in edges[63:0].
    
    always @(posedge clk) begin
        if (state == PREPARE_EDGES && gen_i < n_val && gen_j < n_val && gen_i < gen_j) begin
            edges[edge_cnt][63:0] <= {dist_sq_wire, gen_j[3:0], gen_i[3:0]};
            edge_cnt <= edge_cnt + 1;
        end
    end

    // --- Handling Start Input ---
    // Start should trigger a reset of internal state.
    // We handled it in IDLE state.
    
endmodule

// Revised Main Module to ensure clean state transitions and valid output
// Combining all parts into a single synthesizable module

module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] k_in,
    input wire city_valid,
    input wire [31:0] city_x,
    input wire [31:0] city_y,
    input wire [15:0] city_pop,
    output reg result_valid,
    output reg [31:0] result_dist_sq,
    output reg busy
);

    // --- Parameters ---
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_LOAD = 3'd1;
    localparam [2:0] S_GEN = 3'd2;
    localparam [2:0] S_SORT = 3'd3;
    localparam [2:0] S_PROC = 3'd4;
    localparam [2:0] S_DONE = 3'd5;

    // --- Registers & Memories ---
    reg [2:0] state;
    reg [3:0] n_val, k_val;
    
    // City data
    reg [31:0] cx [0:15];
    reg [31:0] cy [0:15];
    reg [15:0] cp [0:15];
    
    // Edge array: 120 entries. Format: {DistSq[63:0], CityB[3:0], CityA[3:0]}
    // We store full 64-bit distance for accurate comparison
    reg [63:0] edges [0:119];
    
    // DSU
    reg [3:0] parent [0:15];
    reg [15:0] mask [0:15];
    
    // Counters & State Variables
    reg [3:0] idx, idx2;
    reg [6:0] edge_count;
    reg [6:0] sort_idx, sort_pass;
    reg [6:0] proc_idx;
    reg found;
    reg [1:0] phase; // Multi-purpose sub-state
    reg [3:0] u_root, v_root;
    
    // Helper for convolution
    integer i, r1, r2;
    reg [15:0] new_mask;
    
    // Combinational wires for distance calculation
    wire signed [31:0] dx = cx[idx2] - cx[idx];
    wire signed [31:0] dy = cy[idx2] - cy[idx];
    wire [63:0] dist_sq = (dx * dx) + (dy * dy);

    // --- FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 1'b0;
            result_valid <= 1'b0;
            result_dist_sq <= 32'hFFFF_FFFF;
            edge_count <= 7'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        n_val <= n_in;
                        k_val <= k_in;
                        idx <= 4'd0;
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    if (city_valid && idx < n_val) begin
                        cx[idx] <= city_x;
                        cy[idx] <= city_y;
                        cp[idx] <= city_pop;
                        idx <= idx + 4'd1;
                    end else if (!city_valid && idx == n_val) begin
                        // Wait for input stream to finish (or just proceed if sync)
                        // Assuming city_valid pulses for each city
                        state <= S_GEN;
                        idx <= 4'd0;
                        idx2 <= 4'd1;
                        edge_count <= 7'd0;
                    end
                end

                S_GEN: begin
                    // Generate edges
                    if (idx < n_val) begin
                        if (idx2 < n_val) begin
                            // Store edge
                            edges[edge_count][63:0] <= {dist_sq, idx2, idx};
                            edge_count <= edge_count + 7'd1;
                            idx2 <= idx2 + 4'd1;
                        end else begin
                            idx <= idx + 4'd1;
                            idx2 <= idx + 4'd1;
                        end
                    end else begin
                        // Init DSU
                        for (i = 0; i < 16; i = i + 1) begin
                            parent[i] <= i[3:0];
                            // Mask: bit set for (pop % k)
                            // Note: Empty set not considered per problem statement usually
                            if (k_val != 0)
                                mask[i] <= (1 << (cp[i] % k_val));
                            else
                                mask[i] <= 16'h0001; // K=0 is invalid but handle gracefully
                        end
                        state <= S_SORT;
                        sort_idx <= 7'd0;
                        sort_pass <= 7'd0;
                    end
                end

                S_SORT: begin
                    // Bubble sort
                    if (sort_idx < edge_count - 7'd1) begin
                        if (edges[sort_idx][63:32] > edges[sort_idx + 7'd1][63:32]) begin
                            edges[sort_idx] <= edges[sort_idx + 7'd1];
                            edges[sort_idx + 7'd1] <= edges[sort_idx];
                        end
                        sort_idx <= sort_idx + 7'd1;
                    end else begin
                        sort_idx <= 7'd0;
                        if (sort_pass < edge_count) begin
                            sort_pass <= sort_pass + 7'd1;
                        end else begin
                            state <= S_PROC;
                            proc_idx <= 7'd0;
                            phase <= 2'd0;
                            found <= 1'b0;
                        end
                    end
                end

                S_PROC: begin
                    if (found || proc_idx >= edge_count) begin
                        state <= S_DONE;
                    end else begin
                        case (phase)
                            2'd0: begin // Get vertices from edge
                                // Check if edge is valid (cities < n_val)
                                // Edges generated are valid
                                // Load u, v
                                u_root <= edges[proc_idx][3:0];
                                v_root <= edges[proc_idx][7:4];
                                phase <= 2'd1;
                            end
                            2'd1: begin // Find Root U
                                if (parent[u_root] != u_root) u_root <= parent[u_root];
                                else phase <= 2'd2;
                            end
                            2'd2: begin // Find Root V
                                if (parent[v_root] != v_root) v_root <= parent[v_root];
                                else phase <= 2'd3;
                            end
                            2'd3: begin // Merge and Check
                                if (u_root != v_root) begin
                                    // Merge v_root into u_root
                                    parent[v_root] <= u_root;
                                    
                                    // Convolution of masks
                                    new_mask = mask[u_root] | mask[v_root];
                                    for (r1 = 0; r1 < 16; r1 = r1 + 1) begin
                                        if (mask[u_root][r1]) begin
                                            for (r2 = 0; r2 < 16; r2 = r2 + 1) begin
                                                if (mask[v_root][r2]) begin
                                                    new_mask[(r1+r2)%16] = 1'b1;
                                                end
                                            end
                                        end
                                    end
                                    mask[u_root] <= new_mask;
                                    
                                    if (new_mask[0]) begin
                                        found <= 1'b1;
                                        result_dist_sq <= edges[proc_idx][63:32];
                                    end
                                end
                                // Next edge
                                proc_idx <= proc_idx + 7'd1;
                                phase <= 2'd0;
                            end
                        endcase
                    end
                end

                S_DONE: begin
                    result_valid <= 1'b1;
                    busy <= 1'b0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule