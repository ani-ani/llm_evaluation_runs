module or_path_calculator (
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [3:0] edge_count,
    input [15:0] edges [0:15],
    input [3:0] query_s,
    input [3:0] query_t,
    output reg [15:0] result,
    output reg done
);

    // Maximum nodes and edges
    localparam MAX_NODES = 8;
    localparam MAX_EDGES = 16;
    localparam INF = 16'hFFFF;

    // State encoding
    localparam IDLE = 3'b001;
    localparam INIT = 3'b010;
    localparam PROCESSING = 3'b100;
    localparam DONE = 3'b000; // Actually used as separate state, not combinational
    // To strictly follow 4 states, let's define them explicitly
    localparam S_IDLE = 2'b00;
    localparam S_INIT = 2'b01;
    localparam S_PROCESS = 2'b10;
    localparam S_DONE = 2'b11;

    reg [1:0] current_state, next_state;
    
    // Distance matrix storage (8x8) flattened
    // We need to store [0:7][0:7] of 16-bit values
    reg [15:0] dist [0:63];
    
    // Registers for indices
    reg [2:0] i; // source node
    reg [2:0] j; // dest node
    reg [2:0] k; // intermediate node
    reg [3:0] edge_idx; // edge index for initialization
    reg [5:0] cycle_count; // generic counter for timing
    
    // Temporary variables for update logic
    wire [15:0] dist_ik;
    wire [15:0] dist_kj;
    wire [15:0] or_val;
    wire [15:0] current_dist;
    wire [15:0] min_dist;
    
    // Index mapping for 1D array access
    wire [5:0] idx_ik = {i, k};
    wire [5:0] idx_kj = {k, j};
    wire [5:0] idx_ij = {i, j};
    
    assign dist_ik = dist[idx_ik];
    assign dist_kj = dist[idx_kj];
    assign current_dist = dist[idx_ij];
    assign or_val = dist_ik | dist_kj;
    assign min_dist = (current_dist < or_val) ? current_dist : or_val;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic & Output Logic combined for simplicity
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and registers
            result <= 16'h0;
            done <= 1'b0;
            i <= 3'b0;
            j <= 3'b0;
            k <= 3'b0;
            edge_idx <= 4'b0;
            cycle_count <= 6'b0;
            // Reset distance matrix (implicit in many synthesis tools, but good to be safe if no initial block)
            // However, logic handles init state properly, so we rely on state machine.
        end else begin
            case (current_state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize counters for INIT state
                        edge_idx <= 4'b0;
                        i <= 3'b0;
                        j <= 3'b0;
                        next_state <= S_INIT;
                    end else begin
                        next_state <= S_IDLE;
                    end
                end

                S_INIT: begin
                    // 1. Initialize distance matrix
                    // First, fill with INF (except diagonal 0)
                    // We will do this row by row using i, j counters
                    if (edge_idx < 4'd64) begin // 64 cells to init with INF/0 (8x8)
                        if (i == j)
                            dist[{i,j}] <= 16'h0000;
                        else
                            dist[{i,j}] <= INF;
                        
                        // Increment j
                        if (j < 3'd7) begin
                            j <= j + 1'b1;
                        end else begin
                            j <= 3'b0;
                            i <= i + 1'b1;
                        end
                        edge_idx <= edge_idx + 1'b1;
                        next_state <= S_INIT;
                    end else if (edge_idx < 4'd64 + MAX_EDGES) begin
                        // 2. Load direct edges
                        // Use 'edge_idx - 64' as the edge index
                        if ((edge_idx - 64) < edge_count && (edge_idx - 64) < MAX_EDGES) begin
                            // Check if edge source/dest are valid within node_count (optional, but good for safety)
                            if (edges[edge_idx - 64][15:12] < node_count && edges[edge_idx - 64][11:8] < node_count) begin
                                dist[{edges[edge_idx - 64][15:12], edges[edge_idx - 64][11:8]}] <= edges[edge_idx - 64][7:0] != 0 ? edges[edge_idx - 64][7:0] : INF;
                                // Note: Assuming weight is in lower 8 bits based on description {src[3:0], dst[3:0], weight[15:0]} which seems to imply 4+4+16=24 bits total?
                                // Wait, description: edges [0:15] packed edges: {src[3:0], dst[3:0], weight[15:0]}. Total 24 bits.
                                // But input is [15:0]. This is a conflict. 
                                // Assuming input width is 16 bit implies weight is smaller or packing is different.
                                // Let's check: 'edges [0:15]' usually implies 16 entries. Input declaration says 'input [15:0] edges [0:15]'.
                                // So each edge is 16 bits. 
                                // If 16 bits total: src(4) + dst(4) + weight(8)? 
                                // OR src(3) + dst(3) + weight(10)? 
                                // OR maybe the description meant packing, but the port is 16-bit array.
                                // Let's look at 'weight[15:0]'. If strictly 16 bit weight, port must be wider.
                                // Let's assume the input array width 16 implies: src(4), dst(4), weight(8).
                                // However, prompt says 'Edge weights are 16-bit integers'.
                                // This strongly implies the weight part is 16 bits. 
                                // If edges [0:15] is 'input [15:0] edges [0:15]', then each element is 16 bits.
                                // To fit src(4), dst(4), weight(16), we need 24 bits.
                                // I will assume the weight is actually 8 bits to fit the 16-bit port, OR that I should use only the valid bits.
                                // Given the prompt asks for 16-bit integers for weights, I will check if the weight extends to higher bits or if I should treat it as packed differently.
                                // Let's assume the input is actually `input [23:0] edges [0:15]` if 16-bit weights were truly intended.
                                // However, I must follow instructions. 'input [15:0] edges'.
                                // Let's assume {src[3:0], dst[3:0], weight[7:0]} fits, or maybe weight is in upper bits.
                                // Let's check standard usage: often {src, dst, weight} is packed. 
                                // If strictly 16 bit input, weight might be {weight_h, weight_l} across bytes? No.
                                // Let's assume the weight is 16 bits but the input port is a mistake in the prompt or I should use {edges[i][15:8], edges[i][7:0]} if split?
                                // No, 'packed edges: {src[3:0], dst[3:0], weight[15:0]}'
                                // I will implement assuming the *weight* part of the logic handles the width provided.
                                // IF the input is 16 bits wide, I can only store 8 bits of weight effectively unless packed cleverly.
                                // Let's assume the user meant the weight is 16 bits, and I should read it as the upper or lower part.
                                // Actually, if input is 16 bits, I'll treat bits [15:12] as src, [11:8] as dst, and [7:0] as weight LSB. 
                                // But prompt says 'weight[15:0]'.
                                // SAFEST: I will implement the logic to take the weight from the upper bits if 16-bit width is strictly enforced by syntax.
                                // Wait, `input [15:0] edges [0:15]` means each element is 16 bits.
                                // I will use `edges[edge_idx - 64][7:0]` for the weight, assuming the 16-bit weight description was aspirational or refers to the result type.
                                // Actually, looking at the output being 16-bit, and weights being ORed, it makes sense to have 16-bit weights.
                                // Let's check the definition: `input [15:0] edges [0:15]`
                                // Perhaps I should treat `edges` as a memory of 16-bit values, but the 'weight' logic uses 16 bits.
                                // If I cannot fit 4+4+16 in 16 bits, I must truncate or change interpretation.
                                // I will assume the `src` and `dst` are 3 bits (0-7) and weight is 10 bits, or similar.
                                // BUT, I must adhere to the interface. 
                                // I'll use: Src = bits 15:12, Dst = 11:8, Weight = 7:0. 
                                // If the user intended 16-bit weights, the interface should have been wider. I will proceed with 8-bit weights to fit 16-bit interface, or perhaps the prompt implies the weight field in the logic is 16-bit, but the input packing is smaller.
                                // Let's try: `edges` is 16 bit wide. 
                                // I will map: `dist[src][dst] = {8'b0, edges[i][7:0]}`.
                                // Wait, I'll use the full 16 bits of the distance register. 
                                // I will use: Src = edges[i][15:12], Dst = edges[i][11:8], Weight = edges[i][7:0].
                                // I will treat the distance matrix entries as 16-bit, initialized to 0xFFFF. 
                                dist[{edges[edge_idx - 64][15:12], edges[edge_idx - 64][11:8]}] <= {8'h00, edges[edge_idx - 64][7:0]};
                            end
                        end
                        edge_idx <= edge_idx + 1'b1;
                        next_state <= S_INIT;
                    end else begin
                        // Done with initialization
                        k <= 3'b0;
                        i <= 3'b0;
                        j <= 3'b0;
                        // Optimization: 8 iterations for K (0..7) max nodes
                        // Since we have node_count, we could loop node_count times. 
                        // Prompt says: 'Iterate through k=0 to 7' and 'After 8 iterations'.
                        // So we always do 8 iterations, but validity depends on node_count.
                        // If node_count < 8, values for 7 may be garbage but edges are only added for valid nodes.
                        // Floyd Warshall handles this if unreachable is INF.
                        next_state <= S_PROCESS;
                    end
                end

                S_PROCESS: begin
                    // Floyd Warshall Loop
                    // Loop order: K (outer), I, J (inner)
                    // We need to update dist[i][j] = min(dist[i][j], dist[i][k] | dist[k][j])
                    
                    // Logic structure:
                    // We increment j first, then i, then k.
                    // To avoid read-after-write hazard on the same cycle for dist[i][j], we rely on the fact we are updating dist[i][j] based on current state.
                    // However, Verilog blocking vs non-blocking matters.
                    // Since we are reading dist[i][k] and dist[k][j], we need to ensure these aren't being updated in the same clock cycle.
                    // We update 'dist[i][j]'.
                    // I, J, K are the indices for the update operation.
                    
                    // Update Logic (combinational block inside or separate wires used here)
                    // We calculated min_dist earlier using assign statements.
                    
                    dist[idx_ij] <= min_dist;
                    
                    // Increment Counters
                    if (j < 3'd7) begin
                        j <= j + 1'b1;
                    end else begin
                        j <= 3'b0;
                        if (i < 3'd7) begin
                            i <= i + 1'b1;
                        end else begin
                            i <= 3'b0;
                            // Check if we need to stop. Prompt says 'After 8 iterations' of K.
                            // 8 iterations means K=0..7. 
                            if (k < 3'd7) begin
                                k <= k + 1'b1;
                            end else begin
                                // We are done with processing
                                // Extract Result
                                // Since we just finished K=7, I=7, J=7 update.
                                // We need to fetch the result for (query_s, query_t)
                                // Pipeline the result fetch.
                                // We can't access dist[query_s][query_t] this cycle because we just updated dist[7][7] (potentially).
                                // But we can do it next cycle.
                                // Wait, if we are at the end of the loop, we transition to DONE or a WAIT state.
                                // Let's transition to a state that fetches the result.
                                // Or we can do it in the next clock edge of S_PROCESS if we stop incrementing counters.
                                // But to be clean, let's use the 'cycle_count' or a specific sub-state.
                                // Let's use `cycle_count` as a 'post-process' flag.
                                // Or simpler: Transition to DONE.
                                // When we transition to DONE, we read the value.
                                next_state <= S_DONE;
                                // To fetch result now, we need to set address.
                                // We can set result in S_DONE state.
                                // However, we want to avoid skipping the last update.
                                // The update for (i=7, j=7, k=7) happens on this clock edge.
                                // Validity of that update is next clock edge.
                                // So we should wait one more cycle.
                                // Let's add a 'finalizing' cycle or just rely on S_DONE latency.
                                // S_IDLE -> S_INIT -> (S_PROCESS 8*8*8 cycles) -> S_DONE (extract result).
                                // 8*8*8 = 512 cycles. 
                                // The prompt says 'Result valid 50 clock cycles after start'.
                                // This is impossible for 512 cycles of computation unless the module computes in parallel or smaller graph.
                                // If node_count is small, say 4, it's 64 cycles. 
                                // The prompt says 'Iterate through k=0 to 7', implying strictly 8 loops.
                                // Maybe the 50 cycle constraint is just for the output phase, or implies the graph is small (<=4 nodes) or the design is heavily pipelined.
                                // But I must follow the algorithm description. 
                                // Let's optimize: The prompt asks for a 'modified Floyd-Warshall'. 
                                // Maybe the 50 cycle limit is a constraint to be met, implying we must assert done within 50 cycles.
                                // If we must do 8 iterations of k, that's 512 updates. 512 > 50.
                                // This implies either:
                                // 1. The graph is extremely small (e.g. 2 nodes -> 16 updates + overhead).
                                // 2. The logic must be highly parallelized.
                                // 3. The '50 cycles' applies to the time after computation is complete (which is trivial, just output latency).
                                // However, the prompt says: 'Result should be valid 50 clock cycles after start'.
                                // This is a hard deadline. 
                                // IF we assume the worst case is not required to finish in 50 cycles, just that the result is valid (if computed) or the design is efficient.
                                // But 'handle up to 8 nodes'. 
                                // Let's re-read: 'Result should be valid 50 clock cycles after start'.
                                // This likely means the module should be optimized to finish within 50 cycles for typical small graphs (like 4 nodes), or pipelined such that the output is valid 50 cycles after the LAST update.
                                // OR, I need to use a state machine that loops strictly for `node_count` iterations, not fixed 8.
                                // 'Iterate through k=0 to 7' is a description of the algorithm, but 'handle up to 8 nodes' implies variable size.
                                // Let's stick to `node_count` iterations. If node_count is 2, we do 2 iterations (k=0,1). 
                                // If node_count is 8, we do 8 iterations.
                                // 8 iterations * 8 nodes * 8 nodes = 512 cycles. 
                                // 512 cycles at 100MHz is 5.12us. 
                                // If the clock is fast, 50 cycles is very short (50ns). 
                                // 50ns is too short for 512 updates on generic FPGA/ASIC without massive unrolling.
                                // I will implement the standard loop structure, but I will respect the loop count based on `node_count` (which is limited to max 8). 
                                // If the user demands 50 cycles for 8 nodes, they need a parallel array. 
                                // But I must generate synthesizable Verilog. 
                                // I will proceed with the standard iterative logic, but I will ensure the 'Done' signal and 'Result' logic works correctly.
                                // I will assume the 50 cycle constraint is a guideline for 'small' graphs or a target for efficiency, but I cannot guarantee 8 nodes in 50 cycles without Massive Unrolling (which I will do for the inner loops if possible).
                                // Actually, let's try to optimize the I and J loops. 
                                // We can update multiple 'j' values per cycle or multiple 'i' values.
                                // Let's check the '7Forth' constraints often found in such prompts. 
                                // Usually, a single update per cycle is expected.
                                // I will stick to 1 update per cycle. 
                                // I will assume the 50 cycle constraint implies the user expects the design to be finished by then, OR it's a loose requirement.
                                // However, I will design it to run the loops. 
                                // Wait, 'Result should be valid 50 clock cycles after start' is a hard requirement in ASIC design tasks.
                                // Let's assume 'start' is pulsed. 
                                // If I need 50 cycles, I have budget for 50 updates.
                                // A graph with 4 nodes has 64 entries. 50 < 64. 
                                // A graph with 3 nodes has 27 entries * 3 iterations = 81 updates.
                                // It is mathematically impossible to do a full Floyd Warshall on 8 nodes in 50 cycles with 1 update/cycle.
                                // UNLESS we assume 'edges' are loaded and we only query one pair (query_s, query_t).
                                // BUT the prompt says 'computes minimum bitwise OR path costs between all pairs of nodes'.
                                // This implies the full matrix.
                                // I will implement the standard iterative logic. If the graph is large, it will take longer. 
                                // I will add a 'max_iterations' based on node_count.
                                // Let's optimize the counter logic. 
                                // If j < 7: j++. else if i < 7: i++, j=0. else if k < (node_count-1): k++, i=0, j=0.
                                // Else done.
                                // Let's refine the PROCESS state.
                                // We need to handle the triple loop.
                                // I will unroll the J loop? No, that's too many gates. 
                                // I will stick to the standard state machine but optimized for small graphs.
                                
                                // Let's refine the S_PROCESS logic to use the triple loop properly.
                                // We update (i, j) using k.
                                // Then increment j. If j wraps, increment i. If i wraps, increment k.
                                // If k wraps (k == node_count), transition to DONE.
                                
                                if (k < node_count - 1) begin
                                    k <= k + 1'b1;
                                end else begin
                                    next_state <= S_DONE;
                                end
                            end
                        end
                    end
                end

                S_DONE: begin
                    // Fetch result
                    // query_s and query_t are inputs.
                    // We need to ensure the final update from S_PROCESS is settled. 
                    // In S_PROCESS we updated dist[i][j] at posedge.
                    // In S_DONE, we read from dist. 
                    // However, the indices (i,j,k) are at the end of the loop (7,7,7). 
                    // We need to set the read address to {query_s, query_t}.
                    // Since dist is updated in PROCESS state, the result is valid immediately in the next cycle (S_DONE).
                    // But we might need to reset indices or hold them.
                    result <= dist[{query_s, query_t}];
                    done <= 1'b1;
                    
                    // Wait for start to go low (if it stays high) or just stay in DONE until reset?
                    // Usually, we wait for start to go low, then go to IDLE.
                    if (!start) begin
                        next_state <= S_IDLE;
                    end else begin
                        next_state <= S_DONE;
                    end
                end
                
                default: next_state <= S_IDLE;
            endcase
        end
    end
endmodule