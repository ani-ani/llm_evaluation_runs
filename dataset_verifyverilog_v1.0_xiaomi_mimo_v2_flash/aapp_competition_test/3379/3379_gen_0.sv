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

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] UNPACK = 4'd1;
    localparam [3:0] REACHABILITY_INIT = 4'd2;
    localparam [3:0] REACHABILITY_COMPUTE = 4'd3;
    localparam [3:0] IDENTIFY_GOOD = 4'd4;
    localparam [3:0] CHECK_SUBSET = 4'd5;
    localparam [3:0] UPDATE_MAX = 4'd6;
    localparam [3:0] NEXT_SUBSET = 4'd7;
    localparam [3:0] FINISH = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [N-1:0] adj [0:N-1];          // Adjacency matrix (unpacked)
    reg [N-1:0] reach [0:N-1];        // Reachability matrix
    reg [N-1:0] good_nodes;            // Bitmask of good nodes
    reg [N-1:0] subset;                // Current subset being checked
    reg [RESULT_WIDTH-1:0] max_width;  // Maximum antichain width found
    reg [RESULT_WIDTH-1:0] current_width; // Width of current subset
    reg [7:0] cycle_count;             // Cycle counter to prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Loop counters
    integer i, j, k, p;
    integer unpack_idx;
    integer reach_k, reach_i, reach_j;
    integer good_i, good_j;
    integer check_u, check_v;
    
    // Combinational signals
    reg [N-1:0] temp_adj_row;
    reg [N-1:0] temp_reach_row;
    reg [N-1:0] reachable_from_cycle;
    reg is_antichain;
    reg [N-1:0] temp_mask;
    reg has_reachable;

    // Reset and State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= {RESULT_WIDTH{1'b0}};
            done <= 1'b0;
            cycle_count <= 8'd0;
            max_width <= {RESULT_WIDTH{1'b0}};
            current_width <= {RESULT_WIDTH{1'b0}};
            subset <= {N{1'b0}};
            good_nodes <= {N{1'b0}};
            unpack_idx <= 0;
            reach_k <= 0;
            reach_i <= 0;
            reach_j <= 0;
            good_i <= 0;
            good_j <= 0;
            check_u <= 0;
            check_v <= 0;
            // Initialize arrays
            for (p = 0; p < N; p = p + 1) begin
                adj[p] <= {N{1'b0}};
                reach[p] <= {N{1'b0}};
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    max_width <= {RESULT_WIDTH{1'b0}};
                    if (start) begin
                        unpack_idx <= 0;
                    end
                end
                
                UNPACK: begin
                    if (unpack_idx < N) begin
                        adj[unpack_idx] <= graph_packed[(unpack_idx * N) +: N];
                        unpack_idx <= unpack_idx + 1;
                    end
                end
                
                REACHABILITY_INIT: begin
                    // Initialize reach matrix from adjacency
                    for (i = 0; i < N; i = i + 1) begin
                        reach[i] <= adj[i];
                    end
                    reach_k <= 0;
                end
                
                REACHABILITY_COMPUTE: begin
                    // Floyd-Warshall algorithm
                    if (reach_k < N) begin
                        for (reach_i = 0; reach_i < N; reach_i = reach_i + 1) begin
                            if (reach[reach_i][reach_k]) begin
                                reach[reach_i] <= reach[reach_i] | reach[reach_k];
                            end
                        end
                        reach_k <= reach_k + 1;
                    end
                end
                
                IDENTIFY_GOOD: begin
                    // Identify nodes in cycles
                    good_nodes <= {N{1'b1}}; // Assume all good initially
                    if (good_i < N) begin
                        for (good_j = 0; good_j < N; good_j = good_j + 1) begin
                            if (good_j != good_i && reach[good_i][good_j] && reach[good_j][good_i]) begin
                                good_nodes[good_i] <= 1'b0;
                            end
                        end
                        good_i <= good_i + 1;
                    end
                end
                
                CHECK_SUBSET: begin
                    // Count bits in current subset and check antichain property
                    current_width <= {RESULT_WIDTH{1'b0}};
                    is_antichain <= 1'b1;
                    check_u <= 0;
                end
                
                UPDATE_MAX: begin
                    if (is_antichain && current_width > max_width) begin
                        max_width <= current_width;
                    end
                end
                
                NEXT_SUBSET: begin
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FINISH: begin
                    result <= max_width;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = UNPACK;
            end
            
            UNPACK: begin
                if (unpack_idx >= N)
                    next_state = REACHABILITY_INIT;
            end
            
            REACHABILITY_INIT: begin
                next_state = REACHABILITY_COMPUTE;
            end
            
            REACHABILITY_COMPUTE: begin
                if (reach_k >= N)
                    next_state = IDENTIFY_GOOD;
            end
            
            IDENTIFY_GOOD: begin
                if (good_i >= N)
                    next_state = CHECK_SUBSET;
            end
            
            CHECK_SUBSET: begin
                // All calculations happen in combinational block
                if (check_u >= N) begin
                    next_state = UPDATE_MAX;
                end else begin
                    next_state = CHECK_SUBSET;
                end
            end
            
            UPDATE_MAX: begin
                next_state = NEXT_SUBSET;
            end
            
            NEXT_SUBSET: begin
                // Check if all subsets are done
                if (subset == {N{1'b1}}) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_SUBSET;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES && state != FINISH && state != IDLE) begin
            next_state = FINISH;
        end
    end

    // Combinational Logic for CHECK_SUBSET state
    always @(*) begin
        temp_mask = subset & good_nodes;
        is_antichain = 1'b1;
        current_width = {RESULT_WIDTH{1'b0}};
        
        // Count width of valid subset
        for (p = 0; p < N; p = p + 1) begin
            if (temp_mask[p]) begin
                current_width = current_width + 1;
            end
        end
        
        // Check antichain property
        for (check_u = 0; check_u < N; check_u = check_u + 1) begin
            if (temp_mask[check_u]) begin
                for (check_v = check_u + 1; check_v < N; check_v = check_v + 1) begin
                    if (temp_mask[check_v]) begin
                        if (reach[check_u][check_v] || reach[check_v][check_u]) begin
                            is_antichain = 1'b0;
                        end
                    end
                end
            end
        end
    end

    // Subset increment logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            subset <= {N{1'b0}};
        end else if (state == NEXT_SUBSET) begin
            // Increment subset (binary counter)
            for (i = 0; i < N; i = i + 1) begin
                if (!subset[i]) begin
                    subset[i] <= 1'b1;
                    for (j = 0; j < i; j = j + 1) begin
                        subset[j] <= 1'b0;
                    end
                    break;
                end
            end
        end
    end

endmodule