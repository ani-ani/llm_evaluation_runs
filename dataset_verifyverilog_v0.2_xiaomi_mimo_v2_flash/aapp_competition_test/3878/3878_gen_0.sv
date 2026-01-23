module graph_optimizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] adj_matrix_0,
    input [15:0] adj_matrix_1,
    input [15:0] adj_matrix_2,
    input [15:0] adj_matrix_3,
    input [15:0] adj_matrix_4,
    input [15:0] adj_matrix_5,
    input [15:0] adj_matrix_6,
    input [15:0] adj_matrix_7,
    input [15:0] adj_matrix_8,
    input [15:0] adj_matrix_9,
    input [15:0] adj_matrix_10,
    input [15:0] adj_matrix_11,
    input [15:0] adj_matrix_12,
    input [15:0] adj_matrix_13,
    input [15:0] adj_matrix_14,
    input [15:0] adj_matrix_15,
    input [3:0] n,
    output reg [3:0] result_steps,
    output reg [15:0] result_mask,
    output reg done
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam BUILD_COMPLEMENTS = 4'd1;
    localparam INIT_LEVEL = 4'd2;
    localparam CHECK_SOLUTION = 4'd3;
    localparam NEXT_MASK = 4'd4;
    localparam NEXT_LEVEL = 4'd5;
    localparam DONE = 4'd6;

    reg [3:0] state;
    reg [15:0] adj [0:15];
    reg [3:0] n_reg;
    reg [15:0] comp_adj [0:15];
    reg [3:0] build_idx;

    // BFS / Generator Registers
    reg [3:0] current_k; // Current subset size (steps)
    reg [15:0] current_mask;
    reg [15:0] next_mask_reg; // To store calculated next mask

    // Gosper Hack Registers
    reg [15:0] c_val;
    reg [15:0] r_val;
    reg [15:0] temp_xor;
    reg [3:0] ctz_val; // Count trailing zeros of c
    reg [15:0] temp_shift;

    // Combinational signals
    wire [15:0] c_wire;
    wire [15:0] r_wire;
    wire [15:0] xor_wire;
    wire [15:0] shifted_xor_wire;
    wire [15:0] next_wire;

    // Coverage Check Wires
    // We need to check if current_mask covers the complement graph
    // For each node i (0 to n_reg-1), if !current_mask[i], then (current_mask & comp_adj[i]) must equal comp_adj[i]
    // We will check this in combinational logic block to speed up state machine.
    // To avoid massive combinational logic path, we can check 4 nodes per cycle or use a flag.
    // Given n<=16, we can unroll the loop or check sequentially in state machine.
    // Let's check sequentially in CHECK_SOLUTION to save logic area and timing.
    reg [3:0] check_idx;
    reg is_covered_reg;

    // Helper for CTZ (Count Trailing Zeros)
    // Combinational priority encoder for c_wire (which is power of 2)
    wire [3:0] ctz_wire;
    assign ctz_wire = (c_wire[0]) ? 4'd0 :
                      (c_wire[1]) ? 4'd1 :
                      (c_wire[2]) ? 4'd2 :
                      (c_wire[3]) ? 4'd3 :
                      (c_wire[4]) ? 4'd4 :
                      (c_wire[5]) ? 4'd5 :
                      (c_wire[6]) ? 4'd6 :
                      (c_wire[7]) ? 4'd7 :
                      (c_wire[8]) ? 4'd8 :
                      (c_wire[9]) ? 4'd9 :
                      (c_wire[10]) ? 4'd10 :
                      (c_wire[11]) ? 4'd11 :
                      (c_wire[12]) ? 4'd12 :
                      (c_wire[13]) ? 4'd13 :
                      (c_wire[14]) ? 4'd14 :
                      (c_wire[15]) ? 4'd15 : 4'd0;

    // Gosper Logic Combinational
    assign c_wire = current_mask & -current_mask;
    assign r_wire = current_mask + c_wire;
    assign xor_wire = r_wire ^ current_mask;
    assign shifted_xor_wire = xor_wire >> 2;
    assign next_wire = r_wire | (shifted_xor_wire >> ctz_wire);

    // Coverage Logic Combinational (Iterative check)
    // To keep logic depth low, we will do this in 1 cycle using a generate-like loop (manually unrolled or sequential in FSM).
    // Sequential is safer for synthesis area. We will use the CHECK_SOLUTION state to iterate check_idx.

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result_steps <= 0;
            result_mask <= 0;
            build_idx <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 0;
                comp_adj[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        n_reg <= n;
                        adj[0] <= adj_matrix_0;
                        adj[1] <= adj_matrix_1;
                        adj[2] <= adj_matrix_2;
                        adj[3] <= adj_matrix_3;
                        adj[4] <= adj_matrix_4;
                        adj[5] <= adj_matrix_5;
                        adj[6] <= adj_matrix_6;
                        adj[7] <= adj_matrix_7;
                        adj[8] <= adj_matrix_8;
                        adj[9] <= adj_matrix_9;
                        adj[10] <= adj_matrix_10;
                        adj[11] <= adj_matrix_11;
                        adj[12] <= adj_matrix_12;
                        adj[13] <= adj_matrix_13;
                        adj[14] <= adj_matrix_14;
                        adj[15] <= adj_matrix_15;
                        build_idx <= 0;
                        state <= BUILD_COMPLEMENTS;
                    end
                end

                BUILD_COMPLEMENTS: begin
                    if (build_idx < 16) begin
                        // Compute complement: flip bits, mask valid range
                        // Note: self-loops in complement don't matter for vertex cover (vertex covers itself)
                        // But strictly speaking, if comp_adj[i][i] is 1, (mask>>i)&1 must be 1.
                        // Standard vertex cover problem usually considers edges (u,v) where u!=v.
                        // The problem description says "all pairs of guests friends".
                        // Let's assume no self-loops. If present, they are covered if i is selected.
                        comp_adj[build_idx] <= ~(adj[build_idx]) & (((1 << n_reg) - 1) & 16'hFFFE); // Mask 0
                        if (build_idx < n_reg) begin
                             comp_adj[build_idx][build_idx] <= 1'b0; // Explicitly clear self if needed
                        end
                        build_idx <= build_idx + 1;
                    end else begin
                        state <= INIT_LEVEL;
                    end
                end

                INIT_LEVEL: begin
                    current_k <= 0;
                    current_mask <= 0;
                    check_idx <= 0;
                    state <= CHECK_SOLUTION;
                end

                CHECK_SOLUTION: begin
                    // Iteratively check if current_mask covers the graph
                    // We check one node per cycle to save area and meet timing
                    // Nodes to check: 0 to n_reg-1
                    if (check_idx < n_reg) begin
                        // If current node is NOT selected
                        if (!(current_mask[check_idx])) begin
                            // Then all its complement neighbors must be selected
                            if ((current_mask & comp_adj[check_idx]) != comp_adj[check_idx]) begin
                                // Not covered. Go to NEXT_MASK to find new mask.
                                state <= NEXT_MASK;
                                // If current_k is 0, this fail happens immediately (since mask 0 is empty, and comp graph non-empty usually).
                                // If we are in INIT_LEVEL (k=0), we fail fast.
                            end else begin
                                // This node is covered. Check next node.
                                check_idx <= check_idx + 1;
                            end
                        end else begin
                            // Node selected, covers all edges incident to it. Check next node.
                            check_idx <= check_idx + 1;
                        end
                    end else begin
                        // All nodes checked, solution found!
                        result_steps <= current_k;
                        result_mask <= current_mask;
                        state <= DONE;
                    end
                end

                NEXT_MASK: begin
                    // Generate next subset of size current_k
                    // If current_k == 0, we just finished checking empty set. Move to k=1.
                    if (current_k == 0) begin
                        current_k <= 1;
                        current_mask <= (1 << 1) - 1; // 00...001
                        check_idx <= 0;
                        state <= CHECK_SOLUTION;
                    end else begin
                        // Gosper's Hack to get next lexicographical subset with same popcount
                        // Logic is combinational, we just latch it.
                        // c = mask & -mask
                        // r = mask + c
                        // next = r | (((r ^ mask) >> 2) >> ctz(c))

                        // Check if current_mask is valid (e.g., bits beyond n_reg are 0)
                        // Actually, Gosper generates masks. We must stop if MSB > n_reg-1.
                        // However, Gosper naturally stops when the mask is too large (e.g., 111000 for n=5, K=3 is valid, next is 100011 which is invalid if we mask by n).
                        // We should mask the generated next_mask by (1<<n_reg)-1.

                        // Let's calculate next_wire (combinational) and check it.
                        // We need to see if the new mask has any bit set >= n_reg.
                        // If (next_wire >> n_reg) != 0, then we overflowed. Move to NEXT_LEVEL.

                        if (| (next_wire >> n_reg)) begin
                            // Overflow, need larger subset size
                            state <= NEXT_LEVEL;
                        end else begin
                            // Valid next mask
                            current_mask <= next_wire;
                            check_idx <= 0;
                            state <= CHECK_SOLUTION;
                        end
                    end
                end

                NEXT_LEVEL: begin
                    // Increment subset size
                    if (current_k < n_reg) begin
                        current_k <= current_k + 1;
                        current_mask <= (1 << (current_k + 1)) - 1;
                        check_idx <= 0;
                        state <= CHECK_SOLUTION;
                    end else begin
                        // Should not happen (n is always a solution), but safe fallback
                        state <= DONE;
                        result_steps <= n_reg;
                        result_mask <= ((1 << n_reg) - 1);
                    end
                end

                DONE: begin
                    done <= 1;
                    // Wait for reset or start de-assertion
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
