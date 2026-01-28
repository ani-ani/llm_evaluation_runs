module topological_width #(
    parameter N = 4,
    parameter GRAPH_WIDTH = N * N,
    parameter RESULT_WIDTH = 4,
    parameter CLK_PERIOD = 10
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [GRAPH_WIDTH-1:0] graph_packed,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] UNPACK_GRAPH    = 4'd1;
    localparam [3:0] FW_INIT         = 4'd2;
    localparam [3:0] FW_COMPUTE      = 4'd3;
    localparam [3:0] COMP_GOOD_NODES = 4'd4;
    localparam [3:0] FIND_ANTICHAIN  = 4'd5;
    localparam [3:0] FINISH          = 4'd6;
    
    reg [3:0] state, next_state;
    
    // Computation registers
    reg [N-1:0] adj [0:N-1];          // Adjacency matrix (unpacked)
    reg [N-1:0] reach [0:N-1];        // Reachability matrix
    reg [N-1:0] bad_nodes;
    reg [N-1:0] good_nodes;
    reg [RESULT_WIDTH-1:0] max_antichain;
    
    // Loop counters
    reg [7:0] i, j, k;
    reg [N-1:0] subset;
    reg subset_valid;
    reg [$clog2(N):0] subset_size;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= {RESULT_WIDTH{1'b0}};
            max_antichain <= {RESULT_WIDTH{1'b0}};
            cycle_count <= 8'd0;
            
            // Initialize all arrays
            for (i = 0; i < N; i = i + 1) begin
                adj[i] <= {N{1'b0}};
                reach[i] <= {N{1'b0}};
            end
            bad_nodes <= {N{1'b0}};
            good_nodes <= {N{1'b0}};
            
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    max_antichain <= {RESULT_WIDTH{1'b0}};
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= UNPACK_GRAPH;
                    end
                end
                
                UNPACK_GRAPH: begin
                    // Unpack graph_packed into adjacency matrix
                    for (i = 0; i < N; i = i + 1) begin
                        adj[i] <= graph_packed[i*N +: N];
                    end
                    state <= FW_INIT;
                end
                
                FW_INIT: begin
                    // Initialize reachability matrix with adj
                    for (i = 0; i < N; i = i + 1) begin
                        reach[i] <= adj[i] | (1 << i); // Include self-reachability
                    end
                    k <= 8'd0;
                    state <= FW_COMPUTE;
                end
                
                FW_COMPUTE: begin
                    // Floyd-Warshall algorithm
                    if (k < N) begin
                        for (i = 0; i < N; i = i + 1) begin
                            for (j = 0; j < N; j = j + 1) begin
                                if (reach[i][k] && reach[k][j]) begin
                                    reach[i][j] <= 1'b1;
                                end
                            end
                        end
                        k <= k + 8'd1;
                    end else begin
                        state <= COMP_GOOD_NODES;
                    end
                end
                
                COMP_GOOD_NODES: begin
                    // Find nodes in cycles or reachable from cycles
                    bad_nodes <= {N{1'b0}};
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) begin
                            if (i != j && reach[i][j] && reach[j][i]) begin
                                bad_nodes[i] <= 1'b1;
                            end
                        end
                    end
                    
                    // Propagate bad nodes to all reachable nodes
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) begin
                            if (bad_nodes[i] && reach[i][j]) begin
                                bad_nodes[j] <= 1'b1;
                            end
                        end
                    end
                    
                    // Good nodes are those not marked bad
                    good_nodes <= ~bad_nodes;
                    
                    // If no good nodes, max antichain is 0
                    if ((~bad_nodes) == {N{1'b0}}) begin
                        max_antichain <= {RESULT_WIDTH{1'b0}};
                        state <= FINISH;
                    end else begin
                        subset <= {N{1'b0}};
                        max_antichain <= {RESULT_WIDTH{1'b0}};
                        state <= FIND_ANTICHAIN;
                    end
                end
                
                FIND_ANTICHAIN: begin
                    // Iterate through all subsets of good_nodes
                    if (subset < (1 << N)) begin
                        subset_valid <= 1'b1;
                        subset_size <= {RESULT_WIDTH{1'b0}};
                        
                        // Check if current subset is subset of good nodes
                        if ((subset & good_nodes) == subset) begin
                            // Check if antichain
                            for (i = 0; i < N; i = i + 1) begin
                                for (j = 0; j < N; j = j + 1) begin
                                    if (subset[i] && subset[j] && (i != j) && (reach[i][j] || reach[j][i])) begin
                                        subset_valid <= 1'b0;
                                    end
                                end
                            end
                            
                            // Count subset size
                            for (i = 0; i < N; i = i + 1) begin
                                subset_size <= subset_size + subset[i];
                            end
                            
                            // Update max_antichain
                            if (subset_valid && (subset_size > max_antichain)) begin
                                max_antichain <= subset_size;
                            end
                        end
                        
                        subset <= subset + 8'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= max_antichain;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Timeout condition
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
                max_antichain <= {RESULT_WIDTH{1'b0}};
            end
        end
    end
    
endmodule