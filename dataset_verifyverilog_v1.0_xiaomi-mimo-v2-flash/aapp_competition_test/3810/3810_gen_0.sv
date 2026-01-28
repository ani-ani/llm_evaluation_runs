module BoxPileSolver(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [5:0] data,
    input [3:0] addr,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_N = 4'd16;
    localparam [7:0] MAX_CYCLE = 8'd200;
    
    // Phases
    localparam [1:0] PHASE_IDLE = 2'd0;
    localparam [1:0] PHASE_INPUT = 2'd1;
    localparam [1:0] PHASE_GRAPH = 2'd2;
    localparam [1:0] PHASE_DP = 2'd3;
    localparam [1:0] PHASE_COMBINE = 2'd4;
    localparam [1:0] PHASE_DONE = 2'd5;
    
    // Registers for input storage
    reg [5:0] arr_reg [0:15];
    reg [3:0] n_reg;
    reg [3:0] input_idx;
    reg input_done;
    
    // Graph representation
    reg [15:0] adj_matrix [0:15]; // adj_matrix[i] has bits set for nodes j where a[i] divides a[j]
    reg [15:0] visited;
    reg [3:0] comp_nodes [0:15]; // Nodes in current component
    reg [3:0] comp_size;
    reg [3:0] comp_idx;
    reg [3:0] comp_count;
    reg [15:0] global_visited;
    
    // Component tracking
    reg [3:0] comp_sizes [0:15]; // Size of each component
    reg [15:0] comp_masks [0:15]; // Bitmask of nodes in each component
    
    // DP state
    reg [31:0] dp_table [0:15][0:65535]; // dp_table[k][mask]
    reg [15:0] inMask [0:15]; // For each node in component, which nodes divide it
    reg [15:0] current_comp_mask;
    reg [3:0] current_comp_size;
    reg [15:0] dp_mask;
    reg [3:0] dp_k;
    reg [31:0] dp_temp;
    reg [31:0] comp_result;
    reg [31:0] total_result;
    
    // Combination state
    reg [3:0] comb_comp_idx;
    reg [31:0] binom_temp;
    
    // Control registers
    reg [1:0] phase;
    reg [7:0] cycle_counter;
    reg [3:0] i, j, k, m; // iteration variables
    reg [3:0] inner_i, inner_j, inner_k;
    reg [31:0] temp_mult;
    reg [31:0] temp_sum;
    
    // Internal signals
    wire [31:0] fact_val;
    wire [31:0] inv_fact_val;
    wire [31:0] binom_val;
    wire [31:0] mod_add_result;
    wire [31:0] mod_mult_result;
    wire [31:0] mod_sub_result;
    
    // Combinatorial helpers
    assign fact_val = compute_factorial(dp_k);
    assign inv_fact_val = compute_inv_factorial(dp_k);
    assign binom_val = compute_binomial(n_reg, comp_sizes[comb_comp_idx]);
    
    // Modulo arithmetic functions (combinational for synthesis)
    function automatic [31:0] mod_mult(input [31:0] a, input [31:0] b);
        reg [63:0] prod;
        begin
            prod = a * b;
            prod = prod % MOD;
            mod_mult = prod[31:0];
        end
    endfunction
    
    function automatic [31:0] mod_add(input [31:0] a, input [31:0] b);
        reg [32:0] sum;
        begin
            sum = a + b;
            if (sum >= MOD)
                mod_add = sum - MOD;
            else
                mod_add = sum[31:0];
        end
    endfunction
    
    function automatic [31:0] mod_sub(input [31:0] a, input [31:0] b);
        reg [32:0] diff;
        begin
            diff = a - b;
            if (a < b)
                mod_sub = diff + MOD;
            else
                mod_sub = diff[31:0];
        end
    endfunction
    
    // Factorial computation (combinational, small values only)
    function automatic [31:0] compute_factorial(input [3:0] val);
        reg [31:0] res;
        reg [3:0] idx;
        begin
            res = 32'd1;
            for (idx = 4'd1; idx <= val; idx = idx + 4'd1) begin
                res = mod_mult(res, {28'd0, idx});
            end
            compute_factorial = res;
        end
    endfunction
    
    function automatic [31:0] compute_inv_factorial(input [3:0] val);
        // For small values, we can compute inverse directly
        // Since MOD is prime, inv(n) = n^(MOD-2) mod MOD
        // But for n <= 16, we use precomputed values
        begin
            case(val)
                4'd0: compute_inv_factorial = 32'd1;
                4'd1: compute_inv_factorial = 32'd1;
                4'd2: compute_inv_factorial = 32'd500000004; // 2^(-1) mod MOD
                4'd3: compute_inv_factorial = 32'd333333336; // 3^(-1) mod MOD
                4'd4: compute_inv_factorial = 32'd250000002; // 4^(-1) mod MOD
                4'd5: compute_inv_factorial = 32'd400000003; // 5^(-1) mod MOD
                4'd6: compute_inv_factorial = 32'd166666668; // 6^(-1) mod MOD
                4'd7: compute_inv_factorial = 32'd142857144; // 7^(-1) mod MOD
                4'd8: compute_inv_factorial = 32'd125000001; // 8^(-1) mod MOD
                4'd9: compute_inv_factorial = 32'd111111112; // 9^(-1) mod MOD
                4'd10: compute_inv_factorial = 32'd700000005; // 10^(-1) mod MOD
                4'd11: compute_inv_factorial = 32'd90909091; // 11^(-1) mod MOD
                4'd12: compute_inv_factorial = 32'd83333334; // 12^(-1) mod MOD
                4'd13: compute_inv_factorial = 32'd76923077; // 13^(-1) mod MOD
                4'd14: compute_inv_factorial = 32'd71428572; // 14^(-1) mod MOD
                4'd15: compute_inv_factorial = 32'd66666667; // 15^(-1) mod MOD
                4'd16: compute_inv_factorial = 32'd625000004; // 16^(-1) mod MOD
                default: compute_inv_factorial = 32'd1;
            endcase
        end
    endfunction
    
    function automatic [31:0] compute_binomial(input [3:0] n_in, input [3:0] k_in);
        reg [31:0] num, den, res;
        begin
            if (k_in > n_in) begin
                compute_binomial = 32'd0;
            end else if (k_in == 4'd0 || k_in == n_in) begin
                compute_binomial = 32'd1;
            end else begin
                // C(n,k) = n! / (k! * (n-k)!)
                num = compute_factorial(n_in);
                den = mod_mult(compute_factorial(k_in), compute_factorial(n_in - k_in));
                // Compute modular inverse using Fermat's little theorem
                // For small den, we use the inverse function
                res = mod_mult(num, compute_inv_factorial(k_in));
                res = mod_mult(res, compute_inv_factorial(n_in - k_in));
                compute_binomial = res;
            end
        end
    endfunction
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            phase <= PHASE_IDLE;
            result <= 32'd0;
            done <= 1'b0;
            ready <= 1'b1;
            cycle_counter <= 8'd0;
            input_idx <= 4'd0;
            input_done <= 1'b0;
            n_reg <= 4'd0;
            visited <= 16'd0;
            global_visited <= 16'd0;
            comp_count <= 4'd0;
            comp_idx <= 4'd0;
            comp_size <= 4'd0;
            comb_comp_idx <= 4'd0;
            total_result <= 32'd1;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                arr_reg[i] <= 6'd0;
                adj_matrix[i] <= 16'd0;
                comp_sizes[i] <= 4'd0;
                comp_masks[i] <= 16'd0;
                inMask[i] <= 16'd0;
                for (j = 0; j < 65536; j = j + 1) begin
                    dp_table[i][j] <= 32'd0;
                end
            end
        end else begin
            case (phase)
                PHASE_IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    result <= 32'd0;
                    total_result <= 32'd1;
                    if (start) begin
                        phase <= PHASE_INPUT;
                        ready <= 1'b0;
                        input_idx <= 4'd0;
                        input_done <= 1'b0;
                        n_reg <= n;
                        cycle_counter <= 8'd0;
                        // Initialize arrays
                        for (i = 0; i < 16; i = i + 1) begin
                            arr_reg[i] <= 6'd0;
                            adj_matrix[i] <= 16'd0;
                            comp_sizes[i] <= 4'd0;
                            comp_masks[i] <= 16'd0;
                            inMask[i] <= 16'd0;
                        end
                    end
                end
                
                PHASE_INPUT: begin
                    // Store input values (cycles 0-16)
                    if (input_idx < n_reg && !input_done) begin
                        // Read from addr/data interface
                        // For synthesis, we'll simulate sequential reading
                        // In real implementation, this would be an external memory interface
                        // Here we assume data is available on each cycle
                        arr_reg[addr] <= data;
                        input_idx <= input_idx + 4'd1;
                        if (input_idx == n_reg - 4'd1) begin
                            input_done <= 1'b1;
                        end
                    end else if (input_done) begin
                        phase <= PHASE_GRAPH;
                        cycle_counter <= 8'd0;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end
                
                PHASE_GRAPH: begin
                    // Build divisibility graph (cycles 17-32)
                    if (cycle_counter < 8'd32) begin
                        // Iterate through pairs (i, j)
                        if (i < n_reg) begin
                            if (j < n_reg) begin
                                // Check if arr_reg[i] divides arr_reg[j]
                                if (arr_reg[i] != 6'd0 && arr_reg[j] % arr_reg[i] == 6'd0) begin
                                    adj_matrix[i] <= adj_matrix[i] | (16'd1 << j);
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            phase <= PHASE_DP;
                            i <= 4'd0;
                            comp_idx <= 4'd0;
                            comp_count <= 4'd0;
                            global_visited <= 16'd0;
                            cycle_counter <= 8'd0;
                        end
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end
                
                PHASE_DP: begin
                    // Component detection and DP
                    if (cycle_counter < 8'd64) begin
                        // Find next unvisited node
                        if (i < n_reg && !global_visited[i]) begin
                            // Start new component
                            visited <= (16'd1 << i);
                            comp_size <= 4'd0;
                            comp_nodes[0] <= i;
                            global_visited <= global_visited | (16'd1 << i);
                            i <= i + 4'd1;
                            inner_i <= 4'd0; // BFS/DFS pointer
                            k <= 4'd1; // Component size
                            m <= 4'd0; // Temporary index
                            
                            // Initialize component
                            comp_masks[comp_count] <= 16'd0;
                        end else if (i < n_reg && global_visited[i]) begin
                            i <= i + 4'd1;
                        end else if (i >= n_reg && comp_size > 4'd0) begin
                            // Process current component
                            if (inner_i < k) begin
                                // BFS to expand component
                                for (m = 0; m < n_reg; m = m + 1) begin
                                    if (!global_visited[m] && 
                                        (adj_matrix[comp_nodes[inner_i]] >> m) & 1'b1) begin
                                        global_visited <= global_visited | (16'd1 << m);
                                        comp_nodes[k] <= m;
                                        k <= k + 4'd1;
                                    end
                                end
                                inner_i <= inner_i + 4'd1;
                            end else begin
                                // Component complete, run DP
                                comp_size <= k;
                                comp_sizes[comp_count] <= k;
                                // Store bitmask
                                for (m = 0; m < k; m = m + 1) begin
                                    comp_masks[comp_count] <= comp_masks[comp_count] | (16'd1 << comp_nodes[m]);
                                end
                                // Setup DP
                                current_comp_size <= k;
                                current_comp_mask <= comp_masks[comp_count];
                                dp_k <= 4'd0;
                                dp_mask <= 16'd0;
                                phase <= PHASE_DP; // Continue DP
                                i <= i + 4'd1; // Continue component search
                                comp_count <= comp_count + 4'd1;
                                
                                // Compute inMask for DP
                                for (inner_i = 0; inner_i < k; inner_i = inner_i + 1) begin
                                    inMask[inner_i] <= 16'd0;
                                    for (inner_j = 0; inner_j < k; inner_j = inner_j + 1) begin
                                        if (inner_i != inner_j && 
                                            (adj_matrix[comp_nodes[inner_j]] >> comp_nodes[inner_i]) & 1'b1) begin
                                            inMask[inner_i] <= inMask[inner_i] | (16'd1 << inner_j);
                                        end
                                    end
                                end
                                
                                // Initialize DP base case
                                for (inner_i = 0; inner_i < k; inner_i = inner_i + 1) begin
                                    dp_table[inner_i][(1 << inner_i)] <= 32'd1;
                                end
                            end
                        end else if (i >= n_reg && comp_size == 4'd0) begin
                            // All nodes processed or no more components
                            if (comp_count > 4'd0) begin
                                phase <= PHASE_DP;
                                comp_idx <= 4'd0;
                                dp_k <= 4'd1; // Start with k=1
                                dp_mask <= 16'd0;
                            end else begin
                                phase <= PHASE_DONE;
                            end
                        end
                    end else begin
                        // Timeout - should not reach here
                        phase <= PHASE_DONE;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // DP computation (in separate block if needed)
                end
                
                PHASE_DP: begin
                    // Compute DP table for current component
                    if (comp_idx < comp_count) begin
                        if (dp_k < comp_sizes[comp_idx]) begin
                            if (dp_mask < (1 << comp_sizes[comp_idx])) begin
                                // Calculate dp_table[dp_k][dp_mask]
                                // Sum over last added element j
                                dp_temp <= 32'd0;
                                inner_k <= 4'd0;
                                
                                // Transition: for each j not in mask but inmask[j] is subset of mask
                                for (inner_k = 0; inner_k < comp_sizes[comp_idx]; inner_k = inner_k + 1) begin
                                    if (!(dp_mask & (16'd1 << inner_k))) begin
                                        // Check if all predecessors are in mask
                                        if ((inMask[inner_k] & dp_mask) == inMask[inner_k]) begin
                                            if (dp_k == 4'd0) begin
                                                dp_temp <= mod_add(dp_temp, 32'd1);
                                            end else begin
                                                dp_temp <= mod_add(dp_temp, dp_table[dp_k - 4'd1][dp_mask | (16'd1 << inner_k)]);
                                            end
                                        end
                                    end
                                end
                                
                                dp_table[dp_k][dp_mask] <= dp_temp;
                                
                                // Move to next mask
                                dp_mask <= dp_mask + 16'd1;
                            end else begin
                                dp_mask <= 16'd0;
                                dp_k <= dp_k + 4'd1;
                            end
                        end else begin
                            // Component DP complete
                            comp_result <= dp_table[comp_sizes[comp_idx] - 4'd1][((1 << comp_sizes[comp_idx]) - 1)];
                            
                            // Multiply result
                            total_result <= mod_mult(total_result, comp_result);
                            
                            // Next component
                            comp_idx <= comp_idx + 4'd1;
                            dp_k <= 4'd0;
                            dp_mask <= 16'd0;
                        end
                    end else begin
                        // All components done
                        phase <= PHASE_COMBINE;
                        comb_comp_idx <= 4'd0;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end
                
                PHASE_COMBINE: begin
                    // Combine component results (already multiplied in DP phase)
                    // Multiply by binomial coefficient C(n, comp_size)
                    if (comb_comp_idx < comp_count) begin
                        // Multiply by binomial coefficient
                        binom_temp <= compute_binomial(n_reg, comp_sizes[comb_comp_idx]);
                        total_result <= mod_mult(total_result, binom_temp);
                        comb_comp_idx <= comb_comp_idx + 4'd1;
                    end else begin
                        result <= total_result;
                        phase <= PHASE_DONE;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end
                
                PHASE_DONE: begin
                    // Done pulse
                    done <= 1'b1;
                    ready <= 1'b1;
                    phase <= PHASE_IDLE;
                    cycle_counter <= 8'd0;
                    // Reset iteration variables
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    m <= 4'd0;
                end
                
                default: begin
                    phase <= PHASE_IDLE;
                    ready <= 1'b1;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter timeout (prevent infinite loops)
            if (cycle_counter > MAX_CYCLE) begin
                phase <= PHASE_DONE;
                result <= 32'd0;
                done <= 1'b1;
                ready <= 1'b1;
            end
        end
    end

endmodule