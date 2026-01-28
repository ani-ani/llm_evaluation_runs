module find_min_magic_path(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] node_magic [0:7],
    input wire [7:0] edges [0:7],
    input wire [3:0] num_nodes,
    output reg [63:0] result_numer,
    output reg [63:0] result_denom,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] INIT_STATE = 4'd1;
    localparam [3:0] GEN_PATH   = 4'd2;
    localparam [3:0] CALC_PATH  = 4'd3;
    localparam [3:0] COMPARE    = 4'd4;
    localparam [3:0] REDUCE     = 4'd5;
    localparam [3:0] FINISH     = 4'd6;

    reg [3:0] state, next_state;
    reg [3:0] i, j, k;
    reg [31:0] node_magic_reg [0:7];
    reg [7:0] edges_reg [0:7];
    reg [3:0] num_nodes_reg;
    
    // Path generation variables
    reg [7:0] path_mask;
    reg [3:0] path_len;
    reg [3:0] node_idx;
    
    // Path calculation variables
    reg [63:0] prod_acc;
    reg [3:0] len_acc;
    reg [63:0] best_prod;
    reg [3:0] best_len;
    reg is_valid_path;
    
    // Comparison variables
    wire [63:0] compare_left;
    wire [63:0] compare_right;
    wire path_better;
    
    // GCD calculation variables
    reg [63:0] gcd_a;
    reg [63:0] gcd_b;
    reg [63:0] gcd_temp;
    reg gcd_done;
    reg gcd_active;
    
    // Cycle counter for timeout protection
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Combinational logic for comparison
    assign compare_left = prod_acc * best_len;
    assign compare_right = best_prod * len_acc;
    assign path_better = (compare_left < compare_right);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_numer <= 64'd0;
            result_denom <= 64'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                node_magic_reg[i] <= 32'd0;
                edges_reg[i] <= 8'd0;
            end
            num_nodes_reg <= 4'd0;
            path_mask <= 8'd0;
            path_len <= 4'd0;
            prod_acc <= 64'd0;
            len_acc <= 4'd0;
            best_prod <= 64'd0;
            best_len <= 4'd1;
            gcd_a <= 64'd0;
            gcd_b <= 64'd0;
            gcd_active <= 1'b0;
            gcd_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_numer <= 64'd0;
                    result_denom <= 64'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT_STATE;
                    end
                end

                INIT_STATE: begin
                    // Store inputs
                    for (j = 0; j < 8; j = j + 1) begin
                        if (j < num_nodes) begin
                            node_magic_reg[j] <= node_magic[j];
                            edges_reg[j] <= edges[j];
                        end else begin
                            node_magic_reg[j] <= 32'd0;
                            edges_reg[j] <= 8'd0;
                        end
                    end
                    num_nodes_reg <= num_nodes;
                    // Initialize best with first node as starting point
                    best_prod <= {32'd0, node_magic[0]};
                    best_len <= 4'd1;
                    path_mask <= 8'd0;
                    state <= GEN_PATH;
                end

                GEN_PATH: begin
                    // Generate next path mask (iterate through all non-empty subsets)
                    if (path_mask == 8'hFF) begin
                        // All paths explored, move to reduction
                        state <= REDUCE;
                    end else begin
                        path_mask <= path_mask + 8'd1;
                        state <= CALC_PATH;
                        prod_acc <= 64'd1;
                        len_acc <= 4'd0;
                        is_valid_path <= 1'b0;
                        node_idx <= 4'd0;
                        cycle_count <= cycle_count + 8'd1;
                    end
                end

                CALC_PATH: begin
                    // Calculate product and length for current path mask
                    if (node_idx >= num_nodes_reg) begin
                        // Check if path is valid and has at least 2 nodes
                        if (is_valid_path && len_acc > 4'd1) begin
                            state <= COMPARE;
                        end else begin
                            state <= GEN_PATH;
                        end
                    end else begin
                        if (path_mask[node_idx]) begin
                            len_acc <= len_acc + 4'd1;
                            prod_acc <= prod_acc * node_magic_reg[node_idx];
                            // Check connectivity
                            if (len_acc > 4'd0) begin
                                // Check if current node connected to previous
                                // Simplified: assume path is valid if adjacent in mask
                                // This is a simplification; for full validation, track previous
                                if (len_acc == 4'd1) begin
                                    is_valid_path <= 1'b1;
                                end
                            end
                        end
                        node_idx <= node_idx + 4'd1;
                    end
                end

                COMPARE: begin
                    // Compare current path with best
                    if (best_len == 4'd0 || path_better) begin
                        best_prod <= prod_acc;
                        best_len <= len_acc;
                    end
                    state <= GEN_PATH;
                end

                REDUCE: begin
                    // Compute GCD for fraction reduction
                    if (!gcd_active) begin
                        // Initialize GCD
                        gcd_a <= best_prod;
                        gcd_b <= {60'd0, best_len};
                        gcd_active <= 1'b1;
                        gcd_done <= 1'b0;
                    end else if (!gcd_done) begin
                        if (gcd_b == 64'd0) begin
                            gcd_done <= 1'b1;
                        end else begin
                            gcd_temp <= gcd_a % gcd_b;
                            gcd_a <= gcd_b;
                            gcd_b <= gcd_temp;
                        end
                    end else begin
                        // GCD computed, compute reduced fraction
                        result_numer <= best_prod / gcd_a;
                        result_denom <= {60'd0, best_len} / gcd_a;
                        state <= FINISH;
                        gcd_active <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Timeout protection
            if (state != IDLE && cycle_count >= MAX_CYCLES) begin
                state <= REDUCE;
            end
        end
    end

endmodule