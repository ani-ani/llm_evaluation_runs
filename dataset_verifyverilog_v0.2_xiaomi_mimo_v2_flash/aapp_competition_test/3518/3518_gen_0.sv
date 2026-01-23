module min_co2_match (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] p_idx,
    input wire [2:0] q_idx,
    input wire [31:0] weight,
    input wire weight_valid,
    output reg [31:0] result,
    output reg done,
    output reg impossible
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam LOAD_WEIGHTS = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] current_state, next_state;
    
    // Adjacency matrix: 8x8 weights
    reg [31:0] adj [0:7][0:7];
    reg matrix_valid;
    
    // Counter for computation latency
    reg [4:0] compute_counter;
    
    // Predefined valid matchings for 8 nodes
    // Total 28 valid matchings. Each matching is defined by 4 pairs.
    // Pairs are indices into the adjacency matrix.
    
    // Helper array for matchings: [matching_idx][edge_idx] = {p, q}
    reg [2:0] matchings_p [0:27][0:3];
    reg [2:0] matchings_q [0:27][0:3];
    
    // Temporary storage for partial sums for each matching
    reg [31:0] matching_sum [0:27];
    
    // Computation control
    reg computing;
    integer i, j, k, m;
    
    // Initialization of matchings (combinational logic to fill the arrays)
    initial begin
        // Matching 0: 0-1, 2-3, 4-5, 6-7
        matchings_p[0] = '{3'b000, 3'b010, 3'b100, 3'b110};
        matchings_q[0] = '{3'b001, 3'b011, 3'b101, 3'b111};
        // Matching 1: 0-1, 2-4, 3-5, 6-7
        matchings_p[1] = '{3'b000, 3'b010, 3'b011, 3'b110};
        matchings_q[1] = '{3'b001, 3'b100, 3'b101, 3'b111};
        // Matching 2: 0-1, 2-5, 3-4, 6-7
        matchings_p[2] = '{3'b000, 3'b010, 3'b011, 3'b110};
        matchings_q[2] = '{3'b001, 3'b101, 3'b100, 3'b111};
        // Matching 3: 0-1, 2-6, 3-4, 5-7
        matchings_p[3] = '{3'b000, 3'b010, 3'b011, 3'b101};
        matchings_q[3] = '{3'b001, 3'b110, 3'b100, 3'b111};
        // Matching 4: 0-1, 2-6, 3-5, 4-7
        matchings_p[4] = '{3'b000, 3'b010, 3'b011, 3'b100};
        matchings_q[4] = '{3'b001, 3'b110, 3'b101, 3'b111};
        // Matching 5: 0-1, 2-7, 3-4, 5-6
        matchings_p[5] = '{3'b000, 3'b010, 3'b011, 3'b101};
        matchings_q[5] = '{3'b001, 3'b111, 3'b100, 3'b101};
        // Matching 6: 0-1, 2-7, 3-5, 4-6
        matchings_p[6] = '{3'b000, 3'b010, 3'b011, 3'b100};
        matchings_q[6] = '{3'b001, 3'b111, 3'b101, 3'b101};
        // Matching 7: 0-2, 1-3, 4-5, 6-7
        matchings_p[7] = '{3'b000, 3'b001, 3'b100, 3'b110};
        matchings_q[7] = '{3'b010, 3'b011, 3'b101, 3'b111};
        // Matching 8: 0-2, 1-4, 3-5, 6-7
        matchings_p[8] = '{3'b000, 3'b001, 3'b011, 3'b110};
        matchings_q[8] = '{3'b010, 3'b100, 3'b101, 3'b111};
        // Matching 9: 0-2, 1-5, 3-4, 6-7
        matchings_p[9] = '{3'b000, 3'b001, 3'b011, 3'b110};
        matchings_q[9] = '{3'b010, 3'b101, 3'b100, 3'b111};
        // Matching 10: 0-2, 1-6, 3-4, 5-7
        matchings_p[10] = '{3'b000, 3'b001, 3'b011, 3'b101};
        matchings_q[10] = '{3'b010, 3'b110, 3'b100, 3'b111};
        // Matching 11: 0-2, 1-6, 3-5, 4-7
        matchings_p[11] = '{3'b000, 3'b001, 3'b011, 3'b100};
        matchings_q[11] = '{3'b010, 3'b110, 3'b101, 3'b111};
        // Matching 12: 0-2, 1-7, 3-4, 5-6
        matchings_p[12] = '{3'b000, 3'b001, 3'b011, 3'b101};
        matchings_q[12] = '{3'b010, 3'b111, 3'b100, 3'b101};
        // Matching 13: 0-2, 1-7, 3-5, 4-6
        matchings_p[13] = '{3'b000, 3'b001, 3'b011, 3'b100};
        matchings_q[13] = '{3'b010, 3'b111, 3'b101, 3'b101};
        // Matching 14: 0-3, 1-2, 4-5, 6-7
        matchings_p[14] = '{3'b000, 3'b001, 3'b100, 3'b110};
        matchings_q[14] = '{3'b011, 3'b010, 3'b101, 3'b111};
        // Matching 15: 0-3, 1-4, 2-5, 6-7
        matchings_p[15] = '{3'b000, 3'b001, 3'b010, 3'b110};
        matchings_q[15] = '{3'b011, 3'b100, 3'b101, 3'b111};
        // Matching 16: 0-3, 1-5, 2-4, 6-7
        matchings_p[16] = '{3'b000, 3'b001, 3'b010, 3'b110};
        matchings_q[16] = '{3'b011, 3'b101, 3'b100, 3'b111};
        // Matching 17: 0-3, 1-6, 2-4, 5-7
        matchings_p[17] = '{3'b000, 3'b001, 3'b010, 3'b101};
        matchings_q[17] = '{3'b011, 3'b110, 3'b100, 3'b111};
        // Matching 18: 0-3, 1-6, 2-5, 4-7
        matchings_p[18] = '{3'b000, 3'b001, 3'b010, 3'b100};
        matchings_q[18] = '{3'b011, 3'b110, 3'b101, 3'b111};
        // Matching 19: 0-3, 1-7, 2-4, 5-6
        matchings_p[19] = '{3'b000, 3'b001, 3'b010, 3'b101};
        matchings_q[19] = '{3'b011, 3'b111, 3'b100, 3'b101};
        // Matching 20: 0-3, 1-7, 2-5, 4-6
        matchings_p[20] = '{3'b000, 3'b001, 3'b010, 3'b100};
        matchings_q[20] = '{3'b011, 3'b111, 3'b101, 3'b101};
        // Matching 21: 0-4, 1-2, 3-5, 6-7
        matchings_p[21] = '{3'b000, 3'b001, 3'b011, 3'b110};
        matchings_q[21] = '{3'b100, 3'b010, 3'b101, 3'b111};
        // Matching 22: 0-4, 1-3, 2-5, 6-7
        matchings_p[22] = '{3'b000, 3'b001, 3'b010, 3'b110};
        matchings_q[22] = '{3'b100, 3'b011, 3'b101, 3'b111};
        // Matching 23: 0-4, 1-5, 2-3, 6-7
        matchings_p[23] = '{3'b000, 3'b001, 3'b010, 3'b110};
        matchings_q[23] = '{3'b100, 3'b101, 3'b011, 3'b111};
        // Matching 24: 0-4, 1-6, 2-3, 5-7
        matchings_p[24] = '{3'b000, 3'b001, 3'b010, 3'b101};
        matchings_q[24] = '{3'b100, 3'b110, 3'b011, 3'b111};
        // Matching 25: 0-4, 1-7, 2-3, 5-6
        matchings_p[25] = '{3'b000, 3'b001, 3'b010, 3'b101};
        matchings_q[25] = '{3'b100, 3'b111, 3'b011, 3'b101};
        // Matching 26: 0-5, 1-2, 3-4, 6-7
        matchings_p[26] = '{3'b000, 3'b001, 3'b011, 3'b110};
        matchings_q[26] = '{3'b101, 3'b010, 3'b100, 3'b111};
        // Matching 27: 0-6, 1-2, 3-4, 5-7
        matchings_p[27] = '{3'b000, 3'b001, 3'b011, 3'b101};
        matchings_q[27] = '{3'b110, 3'b010, 3'b100, 3'b111};
    end

    // State Transition and Outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            impossible <= 0;
            matrix_valid <= 0;
            computing <= 0;
            // Clear adjacency matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    adj[i][j] <= 0;
                end
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    if (start) begin
                        current_state <= LOAD_WEIGHTS;
                        matrix_valid <= 0;
                    end
                end

                LOAD_WEIGHTS: begin
                    if (weight_valid && !start) begin // Load weights only when start is deasserted as per spec
                        if (p_idx != q_idx && p_idx < 8 && q_idx < 8) begin
                            adj[p_idx][q_idx] <= weight;
                            adj[q_idx][p_idx] <= weight;
                        end
                    end
                    
                    if (!start) begin
                        current_state <= COMPUTE;
                        matrix_valid <= 1;
                        compute_counter <= 0;
                        // Initialize sums to 0
                        for (m = 0; m < 28; m = m + 1) begin
                            matching_sum[m] <= 0;
                        end
                    end
                end

                COMPUTE: begin
                    // Cycle 1: Sum 4 edges for each matching using temporary logic (accumulated over cycles or parallel)
                    // To meet 20 cycle latency, we can process stages. 
                    // Let's do it in 2 cycles for parallelism or 4 cycles sequentially.
                    // Spec says "evaluate all possible... in parallel". 
                    // If we sum 4 edges, we can do it in 1 cycle if we add 4 numbers.
                    // However, 28 matchings * 4 edges is 112 lookups. 
                    // Let's assume we can sum all 4 edges in 1 cycle.
                    
                    if (compute_counter == 0) begin
                        // Compute sums for all matchings in parallel
                        for (m = 0; m < 28; m = m + 1) begin
                            matching_sum[m] <= 
                                adj[matchings_p[m][0]][matchings_q[m][0]] +
                                adj[matchings_p[m][1]][matchings_q[m][1]] +
                                adj[matchings_p[m][2]][matchings_q[m][2]] +
                                adj[matchings_p[m][3]][matchings_q[m][3]];
                        end
                        compute_counter <= 1;
                    end else if (compute_counter == 1) begin
                        // Find minimum among 28 values. 
                        // Since 28 is large for combinational logic in 1 cycle, we can use a pipelined reduction or sequential scan.
                        // Spec says latency 20 cycles. So we can afford a sequential scan (28 cycles) or a comparator tree.
                        // Let's do a sequential min-find to be robust, but unrolled slightly.
                        // Or, let's use a simple min-find state logic.
                        // Actually, the spec says "evaluate in parallel", implying we might want a fast tree.
                        // But 28 inputs is a lot. Let's just iterate over the 28 stored sums.
                        // 
                        // Let's start the min search here.
                        
                        // Initialize min with first valid matching (if it exists)
                        if (matrix_valid) begin
                            result <= matching_sum[0];
                            // Check for impossible (zero weight might be valid, but if matrix was not touched, it's 0. 
                            // Spec says "If no perfect matching exists". 
                            // Since 8 nodes is always perfectly matchable, impossible might trigger if weights are missing?
                            // The example says 4 nodes (0-1, 2-3) works. 8 nodes always works structurally.
                            // Impossible only if we are asked to match on unconnected nodes? 
                            // With 8 nodes, any permutation is a perfect matching. 
                            // However, if we treat zero as "no edge", the sum might be 0.
                            // Let's assume "impossible" is if all matchings sum to 0 (or some specific invalid marker).
                            // But 0 is a valid weight (0 cost).
                            // Let's stick to the structural validity. 8 nodes always has perfect matchings.
                            impossible <= 0;
                            
                            // Start sequential min check from index 1
                            // We use a 'k' counter for the min loop.
                            // Since we are in a clocked block, we need a register for the loop index.
                            // Let's use compute_counter to track the sub-step or add a new counter.
                            // Let's use 'i' inside the block carefully, or a dedicated register.
                            // We'll use 'i' as 'm' in the loop, but since it's a loop over 28 items, we need a state.
                            // Let's just do it with 'compute_counter' > 0.
                            // Let's reset a loop index.
                            // Actually, let's just compare 4 items per cycle to finish in 7 cycles.
                            
                            // Optimized min find: Compare 4 per cycle (28/4 = 7 cycles + 1 setup = 8 cycles total)
                            // Current cycle 1: compare 1-4 against current min
                            if (matching_sum[1] < result) result <= matching_sum[1];
                            if (matching_sum[2] < result) result <= matching_sum[2];
                            if (matching_sum[3] < result) result <= matching_sum[3];
                            compute_counter <= 2;
                        end
                    end else if (compute_counter == 2) begin
                        // Cycle 2: compare 5-8
                        if (matching_sum[4] < result) result <= matching_sum[4];
                        if (matching_sum[5] < result) result <= matching_sum[5];
                        if (matching_sum[6] < result) result <= matching_sum[6];
                        if (matching_sum[7] < result) result <= matching_sum[7];
                        compute_counter <= 3;
                    end else if (compute_counter == 3) begin
                        // Cycle 3: compare 9-12
                        if (matching_sum[8] < result) result <= matching_sum[8];
                        if (matching_sum[9] < result) result <= matching_sum[9];
                        if (matching_sum[10] < result) result <= matching_sum[10];
                        if (matching_sum[11] < result) result <= matching_sum[11];
                        compute_counter <= 4;
                    end else if (compute_counter == 4) begin
                        // Cycle 4: compare 13-16
                        if (matching_sum[12] < result) result <= matching_sum[12];
                        if (matching_sum[13] < result) result <= matching_sum[13];
                        if (matching_sum[14] < result) result <= matching_sum[14];
                        if (matching_sum[15] < result) result <= matching_sum[15];
                        compute_counter <= 5;
                    end else if (compute_counter == 5) begin
                        // Cycle 5: compare 17-20
                        if (matching_sum[16] < result) result <= matching_sum[16];
                        if (matching_sum[17] < result) result <= matching_sum[17];
                        if (matching_sum[18] < result) result <= matching_sum[18];
                        if (matching_sum[19] < result) result <= matching_sum[19];
                        compute_counter <= 6;
                    end else if (compute_counter == 6) begin
                        // Cycle 6: compare 21-24
                        if (matching_sum[20] < result) result <= matching_sum[20];
                        if (matching_sum[21] < result) result <= matching_sum[21];
                        if (matching_sum[22] < result) result <= matching_sum[22];
                        if (matching_sum[23] < result) result <= matching_sum[23];
                        compute_counter <= 7;
                    end else if (compute_counter == 7) begin
                        // Cycle 7: compare 25-27
                        if (matching_sum[24] < result) result <= matching_sum[24];
                        if (matching_sum[25] < result) result <= matching_sum[25];
                        if (matching_sum[26] < result) result <= matching_sum[26];
                        if (matching_sum[27] < result) result <= matching_sum[27];
                        compute_counter <= 8;
                    end else if (compute_counter == 8) begin
                        // Cycle 8: Buffer/Extra cycle to ensure result is stable or handle edge cases
                        // Actually, latency is 20 cycles. We are using ~9 cycles here (Load(1) + Compute(9)).
                        // We can wait or fill with NOPs to match exact timing, or finish early.
                        // "Latency: 20 clock cycles after start deasserts".
                        // Let's add wait cycles to meet 20.
                        // We are at cycle 9 roughly.
                        compute_counter <= 9;
                    end else if (compute_counter == 18) begin // Adjusted to fit roughly 20 cycles total
                        current_state <= DONE_STATE;
                        done <= 1;
                    end else begin
                        compute_counter <= compute_counter + 1;
                    end
                end

                DONE_STATE: begin
                    done <= 0;
                    if (!start) begin
                        current_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule