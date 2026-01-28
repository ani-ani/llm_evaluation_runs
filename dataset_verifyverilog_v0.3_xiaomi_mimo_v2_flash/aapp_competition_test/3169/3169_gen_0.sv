module TopModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [13:0] x1_0, x1_1, x1_2, x1_3, x1_4, x1_5, x1_6, x1_7,
    input wire [13:0] y1_0, y1_1, y1_2, y1_3, y1_4, y1_5, y1_6, y1_7,
    input wire [13:0] x2_0, x2_1, x2_2, x2_3, x2_4, x2_5, x2_6, x2_7,
    input wire [13:0] y2_0, y2_1, y2_2, y2_3, y2_4, y2_5, y2_6, y2_7,
    output reg [3:0] data_out,
    output reg valid_out,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_DEPS = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [2:0] i, j, k; // Loop counters for 0..7
    reg [3:0] remaining_nodes;
    
    // Storage for stick coordinates (latched)
    reg [13:0] x1 [0:7];
    reg [13:0] y1 [0:7];
    reg [13:0] x2 [0:7];
    reg [13:0] y2 [0:7];
    
    // Adjacency matrix: adj[i][j] = 1 means i depends on j (j must be removed before i)
    reg [7:0] adj [0:7];
    
    // In-degree array
    reg [3:0] indegree [0:7];
    
    // Temporary storage for dependency calculation
    reg [13:0] x_a, x_b, y1_a, y1_b, y2_a, y2_b;
    wire [63:0] y1_at_x_a, y1_at_x_b, y2_at_x_a, y2_at_x_b;
    wire [63:0] y1_at_x_a2, y1_at_x_b2, y2_at_x_a2, y2_at_x_b2;
    
    // Combinational logic for line interpolation (Fixed Point Q14.50 format)
    // We need to calculate y = y1 + (y2-y1)*(x-x1)/(x2-x1)
    // Using 64-bit intermediate to avoid overflow
    
    // Helper signals for comparison
    wire [63:0] dx1, dy1, dx2, dy2;
    wire [63:0] x_diff1, x_diff2;
    wire [63:0] term1, term2, term3, term4;
    wire [63:0] y_j_val_a, y_j_val_b, y_i_val_a, y_i_val_b;
    
    // Assignment for signed comparison
    // We will use comparator logic directly
    
    // Output buffer for topological sort
    reg found;
    
    // Combinational wire for dependency result
    reg dep_result;
    
    // Flops for state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_out <= 1'b0;
            done <= 1'b0;
            data_out <= 4'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            remaining_nodes <= 4'd0;
            // Initialize arrays
            x1[0] <= 14'd0; x1[1] <= 14'd0; x1[2] <= 14'd0; x1[3] <= 14'd0;
            x1[4] <= 14'd0; x1[5] <= 14'd0; x1[6] <= 14'd0; x1[7] <= 14'd0;
            y1[0] <= 14'd0; y1[1] <= 14'd0; y1[2] <= 14'd0; y1[3] <= 14'd0;
            y1[4] <= 14'd0; y1[5] <= 14'd0; y1[6] <= 14'd0; y1[7] <= 14'd0;
            x2[0] <= 14'd0; x2[1] <= 14'd0; x2[2] <= 14'd0; x2[3] <= 14'd0;
            x2[4] <= 14'd0; x2[5] <= 14'd0; x2[6] <= 14'd0; x2[7] <= 14'd0;
            y2[0] <= 14'd0; y2[1] <= 14'd0; y2[2] <= 14'd0; y2[3] <= 14'd0;
            y2[4] <= 14'd0; y2[5] <= 14'd0; y2[6] <= 14'd0; y2[7] <= 14'd0;
            // Initialize adj and indegree
            adj[0] <= 8'd0; adj[1] <= 8'd0; adj[2] <= 8'd0; adj[3] <= 8'd0;
            adj[4] <= 8'd0; adj[5] <= 8'd0; adj[6] <= 8'd0; adj[7] <= 8'd0;
            indegree[0] <= 4'd0; indegree[1] <= 4'd0; indegree[2] <= 4'd0; indegree[3] <= 4'd0;
            indegree[4] <= 4'd0; indegree[5] <= 4'd0; indegree[6] <= 4'd0; indegree[7] <= 4'd0;
        end else begin
            state <= next_state;
            // Default outputs
            valid_out <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 3'd0;
                    if (start) begin
                        // Latch stick data
                        x1[0] <= x1_0; y1[0] <= y1_0; x2[0] <= x2_0; y2[0] <= y2_0;
                        x1[1] <= x1_1; y1[1] <= y1_1; x2[1] <= x2_1; y2[1] <= y2_1;
                        x1[2] <= x1_2; y1[2] <= y1_2; x2[2] <= x2_2; y2[2] <= y2_2;
                        x1[3] <= x1_3; y1[3] <= y1_3; x2[3] <= x2_3; y2[3] <= y2_3;
                        x1[4] <= x1_4; y1[4] <= y1_4; x2[4] <= x2_4; y2[4] <= y2_4;
                        x1[5] <= x1_5; y1[5] <= y1_5; x2[5] <= x2_5; y2[5] <= y2_5;
                        x1[6] <= x1_6; y1[6] <= y1_6; x2[6] <= x2_6; y2[6] <= y2_6;
                        x1[7] <= x1_7; y1[7] <= y1_7; x2[7] <= x2_7; y2[7] <= y2_7;
                        // Clear adjacency and indegree
                        adj[0] <= 8'd0; adj[1] <= 8'd0; adj[2] <= 8'd0; adj[3] <= 8'd0;
                        adj[4] <= 8'd0; adj[5] <= 8'd0; adj[6] <= 8'd0; adj[7] <= 8'd0;
                        indegree[0] <= 4'd0; indegree[1] <= 4'd0; indegree[2] <= 4'd0; indegree[3] <= 4'd0;
                        indegree[4] <= 4'd0; indegree[5] <= 4'd0; indegree[6] <= 4'd0; indegree[7] <= 4'd0;
                    end
                end
                
                COMPUTE_DEPS: begin
                    // Compute dependency for (i, j) pair
                    // i is candidate, j is potential blocker
                    // Dependency exists if j is below i and projections overlap
                    if (i < N && j < N && i != j) begin
                        if (dep_result) begin
                            // j must be removed before i (i depends on j)
                            adj[i][j] <= 1'b1;
                            indegree[i] <= indegree[i] + 4'd1;
                        end
                    end
                end
                
                OUTPUT: begin
                    // Scan for indegree 0
                    found <= 1'b0;
                    for (k = 0; k < 8; k = k + 1) begin
                        if (k < N && found == 1'b0 && indegree[k] == 4'd0) begin
                            data_out <= k;
                            valid_out <= 1'b1;
                            indegree[k] <= 4'd15; // Mark as removed (use 15 as removed marker)
                            found <= 1'b1;
                            remaining_nodes <= remaining_nodes - 4'd1;
                        end
                    end
                    // Decrement indegrees of successors if we output something
                    // Note: In strict Kahn's, we do this after outputting.
                    // Since we can only output one per cycle, we handle decrement logic separately
                    // or combine it if found.
                end
            endcase
        end
    end

    // State Transition Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_DEPS;
            end
            COMPUTE_DEPS: begin
                // We iterate i=0..N-1, j=0..N-1
                // Logic handled in sequential block with counters
                // If computation is done, go to OUTPUT
                if (i >= N) next_state = OUTPUT;
                else next_state = COMPUTE_DEPS;
            end
            OUTPUT: begin
                if (remaining_nodes == 4'd0) next_state = IDLE;
                else next_state = OUTPUT;
            end
            default: next_state = IDLE;
        endcase
    end

    // Counter and loop control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 3'd0;
            j <= 3'd0;
            remaining_nodes <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    i <= 3'd0;
                    j <= 3'd0;
                    remaining_nodes <= N;
                end
                COMPUTE_DEPS: begin
                    if (i < N) begin
                        if (j < N) begin
                            // We process the comparison in parallel or sequential?
                            // Given constraints, sequential is safer for logic usage.
                            // We effectively use 'dep_result' computed combinationally based on current i,j
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end
                end
                OUTPUT: begin
                    // We already handled output in the main block.
                    // We need to decrement indegrees of successors of the node we just output.
                    // But we only know which node was output this cycle in the main block.
                    // We need to propagate this to clear dependencies.
                    // To simplify: The 'found' logic in OUTPUT state sets the found flag.
                    // We need to clear adjacencies for the found node.
                    // This is tricky to do in a single cycle if we also scan.
                    // Let's refine the OUTPUT block logic.
                    // We will use k to both find AND clear.
                    // Actually, the previous OUTPUT block logic was flawed for sequential clearing.
                    // Better approach for OUTPUT:
                    // 1. Scan for node with indegree 0 that is not removed.
                    // 2. Output it.
                    // 3. Decrement indegrees of its neighbors in the SAME CYCLE or NEXT cycle.
                    // 4. Mark node as removed.
                    // To keep it simple and correct in hardware:
                    // We output one node. Then in the SAME cycle, we walk through its successors.
                    // This might be too much logic for one cycle if N=8. 
                    // Let's stick to: Scan, Output, Set a flag 'outputting'.
                    // If 'outputting' is high, we skip scan and perform decrement.
                    
                    // Re-implementation of OUTPUT logic for robustness:
                    // We will use k as the index to decrement, and a flag to control phase.
                end
            endcase
        end
    end

    // Refactored OUTPUT logic
    reg output_phase; // 0: find, 1: clear
    reg [3:0] output_node;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_phase <= 1'b0;
            output_node <= 4'd15;
        end else begin
            if (state == OUTPUT) begin
                if (!output_phase) begin
                    // Phase 0: Find node with indegree 0
                    if (!found && k < N && indegree[k] == 4'd0) begin
                        data_out <= k;
                        valid_out <= 1'b1;
                        output_node <= k;
                        indegree[k] <= 4'd15; // Mark removed
                        remaining_nodes <= remaining_nodes - 4'd1;
                        output_phase <= 1'b1; // Switch to clear phase
                        k <= 3'd0; // Reset k for clearing loop
                    end else if (k < N) begin
                        k <= k + 3'd1;
                    end
                end else begin
                    // Phase 1: Clear dependencies of output_node
                    // Check if k is a successor of output_node (i.e. adj[k][output_node] == 1)
                    // Wait, adj[i] stores dependencies of i. So adj[i][j] = 1 means i depends on j.
                    // If we removed j (output_node), we need to decrement indegree of i.
                    // So we iterate i (renamed k here) and check adj[k][output_node]
                    if (k < N) begin
                        if (adj[k][output_node]) begin
                            if (indegree[k] > 0) begin
                                indegree[k] <= indegree[k] - 4'd1;
                            end
                            // Clear the bit to avoid double decrement if we loop back (though we won't)
                            adj[k][output_node] <= 1'b0;
                        end
                        k <= k + 3'd1;
                    end else begin
                        // Done clearing
                        output_phase <= 1'b0;
                        output_node <= 4'd15;
                        k <= 3'd0; // Reset for next find
                    end
                end
            end else begin
                output_phase <= 1'b0;
                output_node <= 4'd15;
                k <= 3'd0;
            end
        end
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == OUTPUT && remaining_nodes == 4'd0 && !valid_out && !output_phase) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Dependency Calculation Combinational Logic
    // This block computes if stick `j` is below stick `i` at overlapping x-projection.
    // We use 64-bit arithmetic for precision.
    // y_at_x = y1 + (y2-y1) * (x - x1) / (x2 - x1)
    
    // Helper wires to compute signed values
    wire signed [63:0] s_dx1, s_dx2, s_dy1, s_dy2;
    wire signed [63:0] s_x1, s_x2, s_y1, s_y2;
    wire signed [63:0] s_x1_j, s_x2_j;
    wire signed [63:0] overlap_x_a, overlap_x_b;
    
    // Helper for y interpolation
    // We calculate at the overlap endpoints.
    // Overlap exists if max(x1_i, x1_j) < min(x2_i, x2_j)
    // Let's compute at x_a = max(x1_i, x1_j) and x_b = min(x2_i, x2_j)
    
    reg [13:0] x_start, x_end;
    reg signed [63:0] y_i_start, y_i_end, y_j_start, y_j_end;
    
    always @(*) begin
        // Default: no dependency
        dep_result = 1'b0;
        
        if (i < N && j < N && i != j) begin
            // 1. Check Overlap
            // x_proj_i = [x1[i], x2[i]] (assuming x1 < x2)
            // x_proj_j = [x1[j], x2[j]]
            // Since sticks are not vertical and specific orientation not guaranteed, 
            // we assume x1 is left endpoint, x2 is right endpoint. 
            // If not, the problem "sticks are not vertical" implies line segments.
            // Let's define x_left = min(x1, x2), x_right = max(x1, x2).
            
            // To be synthesizable and simple:
            // Check if intervals [min(x1_i,x2_i), max(x1_i,x2_i)] and 
            // [min(x1_j,x2_j), max(x1_j,x2_j)] overlap.
            
            // Let's assume x1 < x2 for all inputs as standard convention or sort them.
            // Given "line segments", x1 is start, x2 is end. 
            
            // Calculate overlap bounds
            // overlap_start = max(x1_i, x1_j)
            // overlap_end = min(x2_i, x2_j)
            
            // Use combinational comparisons
            if (x1[i] < x1[j]) overlap_x_a = x1[j]; else overlap_x_a = x1[i];
            if (x2[i] > x2[j]) overlap_x_b = x2[j]; else overlap_x_b = x2[i];
            
            // Check if valid overlap (start < end)
            if (overlap_x_a < overlap_x_b) begin
                // Calculate y values at these x positions for both sticks
                // y = y1 + (y2-y1)*(x-x1)/(x2-x1)
                
                // Stick i values
                // We need signed arithmetic. Cast inputs to signed 64-bit.
                s_dx1 = {50'd0, x2[i] - x1[i]}; // width conversion
                s_dy1 = {50'd0, y2[i] - y1[i]};
                s_x1_vec = {50'd0, x1[i]};
                s_y1_vec = {50'd0, y1[i]};
                
                s_dx1_j = {50'd0, x2[j] - x1[j]};
                s_dy1_j = {50'd0, y2[j] - y1[j]};
                s_x1_j_vec = {50'd0, x1[j]};
                s_y1_j_vec = {50'd0, y1[j]};
                
                // At x = overlap_x_a
                // dy/dx * (x - x1)
                // i at x_a
                // Handle division by zero? x1 != x2 guaranteed.
                
                // We use fixed point arithmetic. 
                // To avoid overflow during multiplication, we cast to 64-bit first.
                // (y2-y1) is 14 bit. (x-x1) is 14 bit. Product is 28 bit. Fits in 64-bit.
                // Divide by (x2-x1) which is 14 bit.
                
                // Let's compute the values explicitly.
                // y_i(x) = y1_i + (dy_i * (x - x1_i)) / dx_i
                
                // Temporary calc for i
                // dx_i = x2[i] - x1[i]
                // dy_i = y2[i] - y1[i]
                // diff_x_a_i = overlap_x_a - x1[i]
                
                // Since we can't do modular arithmetic easily in combinational block without
                // large intermediate signals, let's do it carefully.
                
                // We'll define intermediate signals.
                // Note: This is a complex combinatorial path. Ensure logic levels are managed.
                
                // y_i at x_a:
                // product = (y2[i] - y1[i]) * (overlap_x_a - x1[i])
                // y_i_start = y1[i] + product / (x2[i] - x1[i])
                
                // y_j at x_a:
                // product_j = (y2[j] - y1[j]) * (overlap_x_a - x1[j])
                // y_j_start = y1[j] + product_j / (x2[j] - x1[j])
                
                // We do the same for x_b.
                
                // Since we need to check if y_j < y_i, we can compute (y_j - y_i) < 0.
                // (y1_j + dy_j*(x-x1_j)/dx_j) - (y1_i + dy_i*(x-x1_i)/dx_i) < 0
                // Multiply both sides by dx_i * dx_j (positive? if x2 > x1).
                // If x2 < x1, dx is negative. Reverses inequality.
                // Given constraints "line segments", assume x1 < x2.
                
                // Let's stick to calculating y values and comparing.
                // We use 64-bit intermediates.
                
                // Sign extension for inputs
                wire signed [63:0] x1_i_s = {{50{x1_i[13]}}, x1_i};
                wire signed [63:0] x2_i_s = {{50{x2_i[13]}}, x2_i};
                wire signed [63:0] y1_i_s = {{50{y1_i[13]}}, y1_i};
                wire signed [63:0] y2_i_s = {{50{y2_i[13]}}, y2_i};
                wire signed [63:0] x1_j_s = {{50{x1_j[13]}}, x1_j};
                wire signed [63:0] x2_j_s = {{50{x2_j[13]}}, x2_j};
                wire signed [63:0] y1_j_s = {{50{y1_j[13]}}, y1_j};
                wire signed [63:0] y2_j_s = {{50{y2_j[13]}}, y2_j};
                wire signed [63:0] ov_a = {{50{overlap_x_a[13]}}, overlap_x_a};
                wire signed [63:0] ov_b = {{50{overlap_x_b[13]}}, overlap_x_b};
                
                // Calculations for i at x_a
                wire signed [63:0] dy_i = y2_i_s - y1_i_s;
                wire signed [63:0] dx_i = x2_i_s - x1_i_s;
                wire signed [63:0] diff_x_i_a = ov_a - x1_i_s;
                wire signed [127:0] temp_i_a = dy_i * diff_x_i_a;
                wire signed [63:0] y_i_val_a = y1_i_s + (temp_i_a / dx_i);
                
                // Calculations for j at x_a
                wire signed [63:0] dy_j = y2_j_s - y1_j_s;
                wire signed [63:0] dx_j = x2_j_s - x1_j_s;
                wire signed [63:0] diff_x_j_a = ov_a - x1_j_s;
                wire signed [127:0] temp_j_a = dy_j * diff_x_j_a;
                wire signed [63:0] y_j_val_a = y1_j_s + (temp_j_a / dx_j);
                
                // Calculations for i at x_b
                wire signed [63:0] diff_x_i_b = ov_b - x1_i_s;
                wire signed [127:0] temp_i_b = dy_i * diff_x_i_b;
                wire signed [63:0] y_i_val_b = y1_i_s + (temp_i_b / dx_i);
                
                // Calculations for j at x_b
                wire signed [63:0] diff_x_j_b = ov_b - x1_j_s;
                wire signed [127:0] temp_j_b = dy_j * diff_x_j_b;
                wire signed [63:0] y_j_val_b = y1_j_s + (temp_j_b / dx_j);
                
                // Check condition: y_j < y_i at both ends
                // Use combinational signals computed above
                // Note: Verilog standard 2001 allows these wires inside the block if declared before.
                // But for Icarus compatibility, let's keep the logic contained.
                // Since we can't declare wires inside always @(*) easily without a block, 
                // we will calculate directly in the condition if possible or define them outside.
                
                // However, to strictly follow instructions and avoid complex wire definitions outside,
                // let's inline the logic or use helper always blocks. 
                // Given the complexity, let's define the calculation in a separate combinational block
                // or just do it inline. 
                
                // Inline check:
                // We use the logic derived above.
                // To be safe with sizes:
                // dy * diff = 14 bit * 14 bit = 28 bit. / 14 bit = 14 bit result. Fits in 64-bit easily.
                
                // We need to ensure we are using signed arithmetic for the subtraction.
                // The logic above is valid.
                
                // Let's compute the y values using temporary registers/wires if needed.
                // But strictly inside always @(*) is fine for synthesis if we compute intermediate values.
                
                // Since Icarus Verilog might have issues with complex nested ternary or arithmetic in always @(*),
                // we will stick to the direct comparison logic.
                
                // Re-check overlap condition:
                // overlap_x_a < overlap_x_b
                
                // Compare at x_a and x_b
                // Check if y_j_val_a < y_i_val_a && y_j_val_b < y_i_val_b
                
                // We need to define the calculation for y values.
                // Let's do it step by step in the block.
                
                // Because we cannot use 2D arrays in function arguments for Icarus, 
                // we pass individual values. The combinational logic is heavy.
                
                // We will create a local block to calculate.
                // However, pure combinational logic with multi-cycle depth (division) is okay.
                
                // Let's calculate y_i and y_j at x_a and x_b.
                // We'll use temporary variables inside the always block.
                // Note: Division in hardware is tricky, but for N<=8 and synthesis to ASIC/FPGA,
                // division by small values might be optimized or inferred.
                // However, integer division is computationally expensive.
                // Given the constraints (N<=8, 14-bit inputs), we assume the synthesis tool handles it.
                // Or we can use a binary divider. But that adds many cycles.
                // For "Efficient Verilog", we rely on synthesis inference.
                
                // However, for a purely combinatorial dependency check, we might need a state machine
                // for division, or compute it sequentially in COMPUTE_DEPS state.
                // The instructions say "Compute dependency graph: edge j->i exists if..."
                // The state is COMPUTE_DEPS. We are iterating i,j.
                // This suggests we compute this relation for one pair per cycle or fill a table.
                // Given the FSM structure, we have a few cycles per pair.
                // Division takes time. 
                // But wait, the instructions say "Use 64-bit intermediate arithmetic for comparisons."
                // It implies parallel or standard arithmetic.
                // Let's assume we do the division combinatorially for now, as it's a small width (14-bit divisor).
                
                // ➡➡➡ CRITICAL: Icarus Verilog Compatibility ➡➡➡
                // Icarus Verilog is slow/buggy with complex integer division in combinatorial logic.
                // A better approach for synthesis is often to avoid division if possible, 
                // but here it's required by math.
                // 
                // Alternative: Cross product check.
                // Stick J is below Stick I if the line segment of J is entirely below I.
                // This can be checked by verifying that (y2_j - y1_j) * (x1_i - x1_j) + ...
                // Actually, a robust geometric check for two segments:
                // (y2_j - y1_j)*(x1_i - x1_j) < (y2_i - y1_i)*(x1_i - x1_j) ?
                // No, that's for the same x.
                
                // The problem states: "j is below i if y_j(x) < y_i(x) at both ends."
                // This implies we MUST calculate y values.
                
                // Let's implement the division using standard operator.
                // We will define the logic using intermediate wires to ensure correct behavior.
                
                // Define local calculation wires
                wire signed [63:0] dy_i_loc = {{50{y2_i[13]}}, y2_i} - {{50{y1_i[13]}}, y1_i};
                wire signed [63:0] dx_i_loc = {{50{x2_i[13]}}, x2_i} - {{50{x1_i[13]}}, x1_i};
                wire signed [63:0] dy_j_loc = {{50{y2_j[13]}}, y2_j} - {{50{y1_j[13]}}, y1_j};
                wire signed [63:0] dx_j_loc = {{50{x2_j[13]}}, x2_j} - {{50{x1_j[13]}}, x1_j};
                
                // Check valid dx (non-zero)
                if (dx_i_loc == 0 || dx_j_loc == 0) begin
                    dep_result = 1'b0; // Should not happen (not vertical)
                end else begin
                    // Endpoints of overlap
                    wire signed [63:0] x_start_s = {{50{overlap_x_a[13]}}, overlap_x_a};
                    wire signed [63:0] x_end_s = {{50{overlap_x_b[13]}}, overlap_x_b};
                    
                    // Y at start
                    wire signed [127:0] y_i_start_full = (dy_i_loc * (x_start_s - {{50{x1_i[13]}}, x1_i})) / dx_i_loc;
                    wire signed [127:0] y_j_start_full = (dy_j_loc * (x_start_s - {{50{x1_j[13]}}, x1_j})) / dx_j_loc;
                    wire signed [63:0] y_i_start_val = {{50{y1_i[13]}}, y1_i} + y_i_start_full[63:0];
                    wire signed [63:0] y_j_start_val = {{50{y1_j[13]}}, y1_j} + y_j_start_full[63:0];
                    
                    // Y at end
                    wire signed [127:0] y_i_end_full = (dy_i_loc * (x_end_s - {{50{x1_i[13]}}, x1_i})) / dx_i_loc;
                    wire signed [127:0] y_j_end_full = (dy_j_loc * (x_end_s - {{50{x1_j[13]}}, x1_j})) / dx_j_loc;
                    wire signed [63:0] y_i_end_val = {{50{y1_i[13]}}, y1_i} + y_i_end_full[63:0];
                    wire signed [63:0] y_j_end_val = {{50{y1_j[13]}}, y1_j} + y_j_end_full[63:0];
                    
                    // Compare
                    // We need to check strict inequality.
                    if (y_j_start_val < y_i_start_val && y_j_end_val < y_i_end_val) begin
                        dep_result = 1'b1;
                    end else begin
                        dep_result = 1'b0;
                    end
                end
            end
        end
    end
    
    // Note: The above logic is a bit dense for synthesis. 
    // To ensure robustness, we might want to pipeline the dependency calculation.
    // However, given N<=8, total pairs = 64. Even if we take 10 cycles per pair, it's 640 cycles. 
    // The testbench might have short timeouts.
    // Optimization: We calculate the condition based on cross products without division.
    // "Sticks do not intersect" and "Straight down removal".
    // If stick J is below I, the vector from (x1_i, y1_i) to (x1_j, y1_j) should be "below" the slope of I.
    // Actually, a standard line segment relationship test:
    // Stick J is below I if both endpoints of J are below the line of I.
    // We can use the cross product (orientation) to check if a point is to the left/right or above/below.
    // 
    // Let (x1, y1) -> (x2, y2) be the line vector.
    // Let (x, y) be the point.
    // The line equation can be written as: (y2-y1)(x-x1) - (x2-x1)(y-y1) = 0
    // If y > y_line, the point is above. 
    // y_line = y1 + (y2-y1)(x-x1)/(x2-x1)
    // y > y1 + (y2-y1)(x-x1)/(x2-x1)
    // y - y1 > (y2-y1)(x-x1)/(x2-x1)
    // 
    // Multiply by (x2-x1). If (x2-x1) > 0, inequality holds. If < 0, reverse.
    // Since sticks are not vertical, x2 != x1.
    // The problem says "Arthur sits at y=0". Sticks are probably x1 < x2 (oriented right).
    // Let's assume x2 > x1 for all. If not, we can normalize inputs.
    
    // Normalized check:
    // If x2_i > x1_i, check if (y2_j - y1_j) * (x1_i - x1_j) ??? No.
    // 
    // Let's stick to the "point below line" test.
    // Point (x_p, y_p) is below line (x1, y1)-(x2, y2) if:
    // (y2 - y1) * (x_p - x1) - (x2 - x1) * (y_p - y1) > 0 ? 
    // (Wait, usually orientation test is (y2-y1)(xp-x1) - (x2-x1)(yp-y1)).
    // If this is positive, point is to the left (for x1->x2 going right).
    // Actually, let's use the slope comparison directly.
    // 
    // If x2 > x1:
    // y_p < y1 + (y2-y1)*(x_p-x1)/(x2-x1)
    // <=> (y_p - y1)*(x2-x1) < (y2-y1)*(x_p-x1)
    // This avoids division! (Assuming x2 > x1).
    // 
    // To handle x2 < x1 (if inputs allow), we must normalize or check sign of dx.
    // The problem says "sticks are not vertical", but doesn't guarantee x1 < x2.
    // We must be robust.
    
    // Let's update the dependency logic to use multiplication only (avoiding division).
    // This is much more synthesizable.
    
    always @(*) begin
        dep_result = 1'b0;
        if (i < N && j < N && i != j) begin
            // Check overlap
            // Normalize x coordinates for interval overlap check (logic is independent of order)
            wire [13:0] x_i_low = (x1[i] < x2[i]) ? x1[i] : x2[i];
            wire [13:0] x_i_high = (x1[i] < x2[i]) ? x2[i] : x1[i];
            wire [13:0] x_j_low = (x1[j] < x2[j]) ? x1[j] : x2[j];
            wire [13:0] x_j_high = (x1[j] < x2[j]) ? x2[j] : x1[j];
            
            // Overlap range
            wire [13:0] ov_a_calc = (x_i_low > x_j_low) ? x_i_low : x_j_low;
            wire [13:0] ov_b_calc = (x_i_high < x_j_high) ? x_i_high : x_j_high;
            
            if (ov_a_calc < ov_b_calc) begin
                // Overlap exists. Check if j is below i.
                // We check at endpoints of overlap: ov_a and ov_b.
                // We need to check if y_j(x) < y_i(x) at these points.
                // Use the cross-product form to avoid division.
                // Check: (y2 - y1)*(x - x1) - (x2 - x1)*(y - y1) > 0 ?
                // No, we need the actual y value comparison.
                // The inequality derived:
                // (y_p - y1)*(x2 - x1) < (y2 - y1)*(x_p - x1)  (if x2 > x1)
                // (y_p - y1)*(x2 - x1) > (y2 - y1)*(x_p - x1)  (if x2 < x1)
                
                // Let's define check for point P against Line I.
                // LHS = (y_p - y1_i) * (x2_i - x1_i)
                // RHS = (y2_i - y1_i) * (x_p - x1_i)
                // We want y_p < y_i(x_p) => LHS < RHS (if x2_i > x1_i)
                
                // We need to compute this for both endpoints of overlap.
                
                // Helper signals
                wire signed [63:0] dx_i = {{50{x2_i[13]}}, x2_i} - {{50{x1_i[13]}}, x1_i};
                wire signed [63:0] dy_i = {{50{y2_i[13]}}, y2_i} - {{50{y1_i[13]}}, y1_i};
                wire signed [63:0] dx_j = {{50{x2_j[13]}}, x2_j} - {{50{x1_j[13]}}, x1_j};
                
                // Point A
                wire signed [63:0] x_a_s = {{50{ov_a_calc[13]}}, ov_a_calc};
                
                // We need y at A for j. But y at A for j is on the line j.
                // So we can use the same inequality for j's endpoints? 
                // No, we need to check j's points relative to i's line.
                // Wait, j is a line segment. We need to check if j is strictly below i.
                // Since they don't intersect, j is either entirely above or entirely below.
                // We only need to check j's endpoints against i's line (or vice versa).
                // Actually, simpler: Check endpoints of j against line i.
                // If both (x1_j, y1_j) and (x2_j, y2_j) are below line i in the x-interval of i,
                // then j is below i.
                // But wait, the projection overlap condition is already checked.
                // So we check y1_j and y2_j against line i.
                // But we must only check them where they exist? 
                // The problem says "j is below i if y_j(x) < y_i(x) at both ends [of overlap]".
                // This implies we evaluate y_j at overlap endpoints.
                // Since j is a straight line, y_j(ov_a) is linearly interpolated.
                // We can compute y_j(ov_a) using the cross-product logic too.
                // 
                // Let's calculate y_j at overlap endpoints.
                // y_val = y1_j + dy_j * (x - x1_j) / dx_j
                // Using multiplication: (y_val - y1_j) * dx_j = dy_j * (x - x1_j)
                // So we compare (y_val - y1_j) * dx_j with dy_j * (x - x1_j).
                // But we don't know y_val, we want to check if y_val < y_i(x).
                // 
                // Let's stick to calculating y values using division. 
                // It is the most accurate and direct way.
                // Given N <= 8, and likely small x range (14 bits), division is acceptable.
                // The synthesis tool will infer a divider.
                
                // Let's refine the division logic to be robust.
                // We use the computed y values from the previous attempt but ensure we use
                // correct slicing for the intermediate 127-bit results.
                
                // Re-evaluate inputs for division
                // dy * diff = 14-bit * 14-bit = 28-bit. Fits in 64-bit easily.
                // Result of division is ~14-bit. Fits in 64-bit.
                
                // We need signed arithmetic. 
                // `reg signed` is not allowed for ports in Icarus sometimes, but `wire signed` is fine.
                
                // Let's use the "Cross Product" method to avoid division entirely if possible.
                // Actually, we can check if j is below i by checking the endpoints of j against i.
                // If (x1_j, y1_j) is within [x1_i, x2_i], check if it is below.
                // If (x2_j, y2_j) is within [x1_i, x2_i], check if it is below.
                // If the whole segment j is inside, checking endpoints is sufficient.
                // If j extends beyond, checking overlap endpoints is necessary.
                // The problem specifically says "at both ends [of overlap]".
                // This requires calculating y at overlap ends.
                
                // Let's use the division. It's cleaner for "exact" spec match.
                
                // To make it synthesizable in Icarus (which chokes on large comb divs):
                // We assume x2 > x1 for all (normalized inputs). If not, we can't easily fix without logic.
                // Let's add a normalization step in IDLE to ensure x1 < x2?
                // Or handle sign in logic.
                
                // Let's calculate y_i and y_j at overlap endpoints.
                // We define local parameters for clarity.
                
                // 1. dx_i, dy_i
                // 2. x_a, x_b
                // 3. diff_i_a = x_a - x1_i
                // 4. y_i_a = y1_i + (dy_i * diff_i_a) / dx_i
                
                // We'll do it in two steps to avoid clutter.
                
                // Sign extend inputs
                wire signed [63:0] s_x1_i = {{50{x1[i][13]}}, x1[i]};
                wire signed [63:0] s_x2_i = {{50{x2[i][13]}}, x2[i]};
                wire signed [63:0] s_y1_i = {{50{y1[i][13]}}, y1[i]};
                wire signed [63:0] s_y2_i = {{50{y2[i][13]}}, y2[i]};
                wire signed [63:0] s_x1_j = {{50{x1[j][13]}}, x1[j]};
                wire signed [63:0] s_x2_j = {{50{x2[j][13]}}, x2[j]};
                wire signed [63:0] s_y1_j = {{50{y1[j][13]}}, y1[j]};
                wire signed [63:0] s_y2_j = {{50{y2[j][13]}}, y2[j]};
                
                // Overlap endpoints (calculated as unsigned in previous block, cast here)
                // We need to recalculate ov_a and ov_b inside the combinational block
                // or pass them in. Since this is always @(*), we can use local params.
                wire signed [63:0] x_i_low_s = (s_x1_i < s_x2_i) ? s_x1_i : s_x2_i;
                wire signed [63:0] x_i_high_s = (s_x1_i < s_x2_i) ? s_x2_i : s_x1_i;
                wire signed [63:0] x_j_low_s = (s_x1_j < s_x2_j) ? s_x1_j : s_x2_j;
                wire signed [63:0] x_j_high_s = (s_x1_j < s_x2_j) ? s_x2_j : s_x1_j;
                
                wire signed [63:0] ov_a_s = (x_i_low_s > x_j_low_s) ? x_i_low_s : x_j_low_s;
                wire signed [63:0] ov_b_s = (x_i_high_s < x_j_high_s) ? x_i_high_s : x_j_high_s;
                
                // Slopes
                wire signed [63:0] dx_i_val = s_x2_i - s_x1_i;
                wire signed [63:0] dy_i_val = s_y2_i - s_y1_i;
                wire signed [63:0] dx_j_val = s_x2_j - s_x1_j;
                wire signed [63:0] dy_j_val = s_y2_j - s_y1_j;
                
                // Calculate Y at A and B for I and J
                // y = y1 + dy * (x - x1) / dx
                // To avoid division: (y - y1) * dx = dy * (x - x1)
                // We want to check if y_j < y_i.
                // => (y_j - y1_j) * dx_j = dy_j * (x - x1_j)
                // => (y_j - y1_j) = (dy_j * (x - x1_j)) / dx_j
                // => y_j = y1_j + (dy_j * (x - x1_j)) / dx_j
                
                // Let's perform the division. It's 64-bit / 64-bit.
                // For Icarus, we must be careful. We can compute this.
                
                // Division signals
                // We need 128-bit intermediate for multiplication to avoid overflow before division?
                // 64-bit * 64-bit = 128-bit.
                // dy is 14-bit. (x-x1) is 14-bit. Product is 28-bit. Fits in 64-bit.
                // Wait, x is 14-bit (0-16383). dx is 14-bit.
                // If we use signed 64-bit, we have plenty of room.
                
                // y_i at A
                wire signed [63:0] diff_i_a = ov_a_s - s_x1_i;
                wire signed [127:0] prod_i_a = dy_i_val * diff_i_a;
                // Division: prod / dx_i_val
                // Note: Division by 0 is undefined. Problem says x1 != x2.
                wire signed [63:0] y_i_a = s_y1_i + (prod_i_a / dx_i_val);
                
                // y_j at A
                wire signed [63:0] diff_j_a = ov_a_s - s_x1_j;
                wire signed [127:0] prod_j_a = dy_j_val * diff_j_a;
                wire signed [63:0] y_j_a = s_y1_j + (prod_j_a / dx_j_val);
                
                // y_i at B
                wire signed [63:0] diff_i_b = ov_b_s - s_x1_i;
                wire signed [127:0] prod_i_b = dy_i_val * diff_i_b;
                wire signed [63:0] y_i_b = s_y1_i + (prod_i_b / dx_i_val);
                
                // y_j at B
                wire signed [63:0] diff_j_b = ov_b_s - s_x1_j;
                wire signed [127:0] prod_j_b = dy_j_val * diff_j_b;
                wire signed [63:0] y_j_b = s_y1_j + (prod_j_b / dx_j_val);
                
                // Check condition
                if (y_j_a < y_i_a && y_j_b < y_i_b) begin
                    dep_result = 1'b1;
                end
            end
        end
    end

    // To ensure synthesis works with large combinatorial paths, 
    // we might need to break up the dependency check.
    // However, the problem asks for a single module.
    // The logic above is correct but might be slow. 
    // Given N<=8, we have 64 pairs. We loop through them.
    // We can insert a wait state or just rely on the cycle count.
    // The current FSM loops i/j counters in COMPUTE_DEPS.
    // We process one pair per cycle.
    // The division operation takes time. 
    // If we assume a single-cycle divider (not realistic for ASIC), we are done.
    // If we assume a pipelined divider, we need more states.
    // Given the "Efficient Verilog" constraint and Icarus compatibility, 
    // we will assume the synthesis tool handles the combinational division logic,
    // or that the testbench is not cycle-strict for dependency computation.
    // 
    // Alternative: Use a pure combinational block for ALL dependencies.
    // Since N <= 8, we can unroll the loops. 
    // This avoids the complex FSM control for dependency calc.
    // It increases area but simplifies timing/FSM.
    // Let's try a purely combinational dependency calculation enabled by 'start'.
    // This is likely the "ASIC designer" approach: resource sharing vs logic depth.
    // With N=8, unrolling is fine.
    
    // Let's rewrite the COMPUTE_DEPS state logic to use a simpler approach.
    // Actually, the current FSM structure is already quite tight.
    // Let's stick to the FSM but make sure the dependency logic is safe.
    
    // One final check: "0 <= x,y <= 16383 (14-bit)".
    // Inputs are 14-bit. Signed arithmetic extends this.
    // The calculation y = y1 + (y2-y1)*(x-x1)/(x2-x1)
    // x coordinates are positive. x1, x2 in [0, 16383].
    // The problem does not state x1 < x2. We handled normalization in the logic.
    
    // However, the "Cross Product" method is much safer for synthesis and Icarus.
    // Let's implement the dependency check using cross products to avoid division.
    // The condition "j is below i" means for all x in overlap, y_j(x) < y_i(x).
    // Since lines are linear, checking endpoints is sufficient.
    // 
    // We want to check if y_j(x) < y_i(x).
    // Rearrange: y_i(x) - y_j(x) > 0.
    // y_i(x) = y1_i + (dy_i/dx_i)*(x-x1_i)
    // y_j(x) = y1_j + (dy_j/dx_j)*(x-x1_j)
    // 
    // This involves fractions with different denominators.
    // (y1_i - y1_j) + (dy_i/dx_i)*(x-x1_i) - (dy_j/dx_j)*(x-x1_j) > 0
    // Multiply by dx_i * dx_j:
    // (y1_i - y1_j)*dx_i*dx_j + dy_i*dx_j*(x-x1_i) - dy_j*dx_i*(x-x1_j) > 0
    // 
    // This is a valid check without division!
    // We calculate this value at overlap endpoints x = A and x = B.
    // If value > 0 at both A and B, then j is below i.
    // Wait, sign depends on signs of dx_i and dx_j.
    // If dx_i < 0, multiplying by it flips the inequality (y_i(x) < y_j(x)).
    // The problem implies removing sticks by translating down (y decreases).
    // So we assume the geometry is such that we look for "blocking".
    // If dx_i and dx_j have different signs, the geometry is complex.
    // Given the problem context (Arthur at y=0, removing down), likely x1 is left, x2 is right (x2 > x1).
    // Let's assume dx > 0 for all sticks. If not, we can normalize inputs.
    
    // Normalization logic in IDLE state:
    // If x1 > x2, swap (x1, y1) and (x2, y2).
    // This ensures dx > 0.
    
    // Let's add normalization.
    
    // In IDLE state, after latching inputs:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == IDLE && start) begin
                // Normalize stick 0
                if (x1_0 > x2_0) begin
                    x1[0] <= x2_0; y1[0] <= y2_0;
                    x2[0] <= x1_0; y2[0] <= y1_0;
                end
                // Repeat for all sticks...
                // Actually, we can't repeat the block for each stick without duplication.
                // We use a loop. But Verilog doesn't support loops in always blocks easily for assignment.
                // We will do it explicitly for N<=8.
                
                // Stick 0
                if (x1_0 > x2_0) begin x1[0] <= x2_0; y1[0] <= y2_0; x2[0] <= x1_0; y2[0] <= y1_0; end
                else begin x1[0] <= x1_0; y1[0] <= y1_0; x2[0] <= x2_0; y2[0] <= y2_0; end
                // Stick 1
                if (x1_1 > x2_1) begin x1[1] <= x2_1; y1[1] <= y2_1; x2[1] <= x1_1; y2[1] <= y1_1; end
                else begin x1[1] <= x1_1; y1[1] <= y1_1; x2[1] <= x2_1; y2[1] <= y2_1; end
                // Stick 2
                if (x1_2 > x2_2) begin x1[2] <= x2_2; y1[2] <= y2_2; x2[2] <= x1_2; y2[2] <= y1_2; end
                else begin x1[2] <= x1_2; y1[2] <= y1_2; x2[2] <= x2_2; y2[2] <= y2_2; end
                // Stick 3
                if (x1_3 > x2_3) begin x1[3] <= x2_3; y1[3] <= y2_3; x2[3] <= x1_3; y2[3] <= y1_3; end
                else begin x1[3] <= x1_3; y1[3] <= y1_3; x2[3] <= x2_3; y2[3] <= y2_3; end
                // Stick 4
                if (x1_4 > x2_4) begin x1[4] <= x2_4; y1[4] <= y2_4; x2[4] <= x1_4; y2[4] <= y1_4; end
                else begin x1[4] <= x1_4; y1[4] <= y1_4; x2[4] <= x2_4; y2[4] <= y2_4; end
                // Stick 5
                if (x1_5 > x2_5) begin x1[5] <= x2_5; y1[5] <= y2_5; x2[5] <= x1_5; y2[5] <= y1_5; end
                else begin x1[5] <= x1_5; y1[5] <= y1_5; x2[5] <= x2_5; y2[5] <= y2_5; end
                // Stick 6
                if (x1_6 > x2_6) begin x1[6] <= x2_6; y1[6] <= y2_6; x2[6] <= x1_6; y2[6] <= y1_6; end
                else begin x1[6] <= x1_6; y1[6] <= y1_6; x2[6] <= x2_6; y2[6] <= y2_6; end
                // Stick 7
                if (x1_7 > x2_7) begin x1[7] <= x2_7; y1[7] <= y2_7; x2[7] <= x1_7; y2[7] <= y1_7; end
                else begin x1[7] <= x1_7; y1[7] <= y1_7; x2[7] <= x2_7; y2[7] <= y2_7; end
            end
        end
    end
    
    // Updated dependency logic using cross-product (no division)
    // Assumption: x2[i] > x1[i] (guaranteed by normalization)
    always @(*) begin
        dep_result = 1'b0;
        if (i < N && j < N && i != j) begin
            // Overlap check
            // We use the normalized x1, x2
            // x range for i: [x1[i], x2[i]]
            // x range for j: [x1[j], x2[j]]
            
            // overlap_start = max(x1[i], x1[j])
            // overlap_end = min(x2[i], x2[j])
            
            wire [13:0] ov_start = (x1[i] > x1[j]) ? x1[i] : x1[j];
            wire [13:0] ov_end = (x2[i] < x2[j]) ? x2[i] : x2[j];
            
            if (ov_start < ov_end) begin
                // Check at ov_start and ov_end
                // Condition: y_j(x) < y_i(x)
                // => y1_j + dy_j*(x-x1_j)/dx_j < y1_i + dy_i*(x-x1_i)/dx_i
                // Multiply by dx_i * dx_j (both > 0 due to normalization):
                // y1_j*dx_i*dx_j + dy_j*dx_i*(x-x1_j) < y1_i*dx_i*dx_j + dy_i*dx_j*(x-x1_i)
                // 
                // Let LHS = y1_j*dx_i*dx_j + dy_j*dx_i*(x-x1_j)
                // Let RHS = y1_i*dx_i*dx_j + dy_i*dx_j*(x-x1_i)
                // Check LHS < RHS
                // Check RHS - LHS > 0
                
                // We need 64-bit intermediates for products.
                // dy is 14-bit, dx is 14-bit. Product is 28-bit. y1 is 14-bit.
                // The term y1*dx_i*dx_j is 14+14+14 = 42 bits. Fits in 64-bit signed.
                
                // Helper values for calc
                wire signed [63:0] dx_i_s = {{50{x2[i][13]}}, x2[i]} - {{50{x1[i][13]}}, x1[i]};
                wire signed [63:0] dy_i_s = {{50{y2[i][13]}}, y2[i]} - {{50{y1[i][13]}}, y1[i]};
                wire signed [63:0] dx_j_s = {{50{x2[j][13]}}, x2[j]} - {{50{x1[j][13]}}, x1[j]};
                wire signed [63:0] dy_j_s = {{50{y2[j][13]}}, y2[j]} - {{50{y1[j][13]}}, y1[j]};
                
                // Check at ov_start
                // x = ov_start
                wire signed [63:0] x_start_s = {{50{ov_start[13]}}, ov_start};
                
                // RHS = y1_i*dx_i*dx_j + dy_i*dx_j*(x-x1_i)
                // LHS = y1_j*dx_i*dx_j + dy_j*dx_i*(x-x1_j)
                
                // Common term: dx_i * dx_j
                wire signed [127:0] dx_prod = dx_i_s * dx_j_s;
                wire signed [63:0] dx_prod_64 = dx_prod[63:0]; // Safe truncation as values are small
                
                // y1 terms
                wire signed [127:0] y1_i_term = {{64{y1[i][13]}}, y1[i]} * dx_prod_64;
                wire signed [127:0] y1_j_term = {{64{y1[j][13]}}, y1[j]} * dx_prod_64;
                
                // Slope terms
                // dy_i * dx_j * (x - x1_i)
                wire signed [127:0] slope_i_term = (dy_i_s * dx_j_s) * (x_start_s - {{50{x1[i][13]}}, x1[i]});
                // dy_j * dx_i * (x - x1_j)
                wire signed [127:0] slope_j_term = (dy_j_s * dx_i_s) * (x_start_s - {{50{x1[j][13]}}, x1[j]});
                
                wire signed [127:0] rhs_start = y1_i_term + slope_i_term;
                wire signed [127:0] lhs_start = y1_j_term + slope_j_term;
                
                // Check at ov_end
                wire signed [63:0] x_end_s = {{50{ov_end[13]}}, ov_end};
                
                wire signed [127:0] slope_i_term_end = (dy_i_s * dx_j_s) * (x_end_s - {{50{x1[i][13]}}, x1[i]});
                wire signed [127:0] slope_j_term_end = (dy_j_s * dx_i_s) * (x_end_s - {{50{x1[j][13]}}, x1[j]});
                
                wire signed [127:0] rhs_end = y1_i_term + slope_i_term_end;
                wire signed [127:0] lhs_end = y1_j_term + slope_j_term_end;
                
                // Compare
                if (lhs_start < rhs_start && lhs_end < rhs_end) begin
                    dep_result = 1'b1;
                end
            end
        end
    end
    
    // Note on the cross-product logic:
    // This method works because we normalized x1 < x2, so dx > 0. 
    // If dx < 0, the inequality would flip. Normalization handles this.
    // The logic is purely combinatorial and uses only multiplication/addition/subtraction,
    // which is much more friendly to synthesis tools (especially Icarus Verilog) than division.
    
endmodule
