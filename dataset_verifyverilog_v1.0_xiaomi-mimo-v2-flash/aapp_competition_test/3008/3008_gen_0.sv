module max_ranks_16(
    input clk,
    input rst_n,
    input start,
    input [7:0] a0, a1, a2, a3, a4, a5, a6, a7,
    input [7:0] a8, a9, a10, a11, a12, a13, a14, a15,
    input [7:0] b0, b1, b2, b3, b4, b5, b6, b7,
    input [7:0] b8, b9, b10, b11, b12, b13, b14, b15,
    input [7:0] K,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] FINALIZE = 3'd4;

    // Registers for inputs
    reg [7:0] a_reg [0:15];
    reg [7:0] b_reg [0:15];
    reg [7:0] k_reg;

    // Adjacency matrix: edges[i][j] = 1 if edge i->j exists
    reg [15:0] edges [0:15];

    // DP state
    reg [4:0] dp [0:15];
    reg [4:0] next_dp [0:15];

    // Counters and helpers
    reg [3:0] i_cnt; // Outer loop index
    reg [3:0] j_cnt; // Inner loop index
    reg [3:0] iter_cnt; // Iteration counter for DP
    reg [4:0] max_candidate;
    reg [4:0] local_max;

    // Main FSM
    reg [2:0] state;
    integer idx;

    // Combinational logic for comparison (performed at the start of COMPARE state)
    wire [8:0] sum_a;
    wire [8:0] sum_b;
    wire edge_cond;
    assign sum_a = {1'b0, a_reg[i_cnt]} + {1'b0, k_reg};
    assign sum_b = {1'b0, b_reg[i_cnt]} + {1'b0, k_reg};
    assign edge_cond = (sum_a < a_reg[j_cnt]) | (sum_b < b_reg[j_cnt]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            iter_cnt <= 4'd0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                a_reg[idx] <= 8'd0;
                b_reg[idx] <= 8'd0;
                edges[idx] <= 16'd0;
                dp[idx] <= 5'd0;
                next_dp[idx] <= 5'd0;
            end
            k_reg <= 8'd0;
            local_max <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        i_cnt <= 4'd0;
                    end
                end

                LOAD: begin
                    // Load inputs into registers (single cycle for simplicity or loop if needed)
                    // Since N=16 is small, we can unroll or load sequentially.
                    // Let's load sequentially over 16 cycles.
                    case (i_cnt)
                        4'd0: begin a_reg[0] <= a0; b_reg[0] <= b0; end
                        4'd1: begin a_reg[1] <= a1; b_reg[1] <= b1; end
                        4'd2: begin a_reg[2] <= a2; b_reg[2] <= b2; end
                        4'd3: begin a_reg[3] <= a3; b_reg[3] <= b3; end
                        4'd4: begin a_reg[4] <= a4; b_reg[4] <= b4; end
                        4'd5: begin a_reg[5] <= a5; b_reg[5] <= b5; end
                        4'd6: begin a_reg[6] <= a6; b_reg[6] <= b6; end
                        4'd7: begin a_reg[7] <= a7; b_reg[7] <= b7; end
                        4'd8: begin a_reg[8] <= a8; b_reg[8] <= b8; end
                        4'd9: begin a_reg[9] <= a9; b_reg[9] <= b9; end
                        4'd10: begin a_reg[10] <= a10; b_reg[10] <= b10; end
                        4'd11: begin a_reg[11] <= a11; b_reg[11] <= b11; end
                        4'd12: begin a_reg[12] <= a12; b_reg[12] <= b12; end
                        4'd13: begin a_reg[13] <= a13; b_reg[13] <= b13; end
                        4'd14: begin a_reg[14] <= a14; b_reg[14] <= b14; end
                        4'd15: begin a_reg[15] <= a15; b_reg[15] <= b15; end
                    endcase
                    
                    if (i_cnt == 4'd15) begin
                        k_reg <= K;
                        state <= COMPARE;
                        i_cnt <= 4'd0;
                        j_cnt <= 4'd0;
                    end else begin
                        i_cnt <= i_cnt + 4'd1;
                    end
                end

                COMPARE: begin
                    // Compute edges[i][j] for all pairs
                    // We iterate i_cnt (0-15) and j_cnt (0-15)
                    // If edge_cond is true, set bit j_cnt in edges[i_cnt]
                    if (edge_cond) begin
                        edges[i_cnt][j_cnt] <= 1'b1;
                    end else begin
                        edges[i_cnt][j_cnt] <= 1'b0;
                    end

                    // Increment counters
                    if (j_cnt == 4'd15) begin
                        j_cnt <= 4'd0;
                        if (i_cnt == 4'd15) begin
                            // All pairs computed
                            state <= CALCULATE;
                            iter_cnt <= 4'd0;
                            // Initialize DP: all nodes have rank 1
                            for (idx = 0; idx < 16; idx = idx + 1) begin
                                dp[idx] <= 5'd1;
                            end
                        end else begin
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                    end
                end

                CALCULATE: begin
                    // Perform DP relaxation
                    // For each node u (i_cnt), find max dp[v] where edge[u][v] is set
                    // Update next_dp[u] = max(dp[u], 1 + max_dp_v)
                    
                    // Compute max_next for current i_cnt
                    max_candidate <= 5'd1; // Default is 1 (base rank)
                    
                    // Check all neighbors v for i_cnt
                    // We check neighbors sequentially over 16 cycles to save logic
                    // We need a temporary register to hold the max found so far for this i_cnt
                    
                    // To do this efficiently in one cycle for all nodes, we need parallel logic.
                    // However, iterating over 16 nodes sequentially is simpler for HW.
                    // Let's iterate j_cnt for neighbors.
                    
                    if (j_cnt == 4'd0) begin
                        // Reset max for this node
                        local_max <= 5'd1;
                    end
                    
                    if (edges[i_cnt][j_cnt]) begin
                        if (dp[j_cnt] + 5'd1 > local_max) begin
                            local_max <= dp[j_cnt] + 5'd1;
                        end
                    end
                    
                    if (j_cnt == 4'd15) begin
                        // Done checking neighbors for i_cnt
                        next_dp[i_cnt] <= local_max;
                        
                        // Move to next node
                        if (i_cnt == 4'd15) begin
                            // All nodes processed for this iteration
                            i_cnt <= 4'd0;
                            j_cnt <= 4'd0;
                            iter_cnt <= iter_cnt + 4'd1;
                            
                            // Update DP registers
                            for (idx = 0; idx < 16; idx = idx + 1) begin
                                dp[idx] <= next_dp[idx];
                            end
                            
                            if (iter_cnt == 4'd15) begin
                                state <= FINALIZE;
                            end else begin
                                // Continue with next iteration
                                // Reset counters for next iteration
                                i_cnt <= 4'd0;
                            end
                        end else begin
                            i_cnt <= i_cnt + 4'd1;
                            j_cnt <= 4'd0;
                        end
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                    end
                end

                FINALIZE: begin
                    // Find max(dp[i]) for i=0..15
                    if (i_cnt == 4'd0) begin
                        result <= dp[0];
                    end else begin
                        if (dp[i_cnt] > result) begin
                            result <= dp[i_cnt];
                        end
                    end

                    if (i_cnt == 4'd15) begin
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        i_cnt <= i_cnt + 4'd1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule