module HongcowWorldSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [6:0] m,
    input wire [3:0] k,
    input wire [3:0] gov_nodes [0:15],
    input wire [3:0] edges_u [0:15],
    input wire [3:0] edges_v [0:15],
    output reg [15:0] result,
    output reg done
);

    // Constants
    localparam [3:0] MAX_NODES = 4'd16;
    localparam [6:0] MAX_EDGES = 7'd64;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // FSM States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS_EDGES = 3'd2;
    localparam [2:0] IDENTIFY_GOV = 3'd3;
    localparam [2:0] CALC_RESULT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // FSM State Register
    reg [2:0] state, next_state;

    // Cycle Counter
    reg [7:0] cycle_count;

    // Union-Find Data Structures
    reg [3:0] parent [0:15];
    reg [3:0] size [0:15];

    // Edge Processing
    reg [3:0] edge_index;
    reg [3:0] u, v;

    // Government Component Tracking
    reg [3:0] gov_component [0:15];
    reg [3:0] gov_component_size [0:15];
    reg [3:0] gov_component_count;
    reg [3:0] largest_gov_component;
    reg [3:0] largest_gov_size;

    // Result Calculation
    reg [15:0] total_possible_edges;
    reg [15:0] non_gov_nodes;
    reg [15:0] edges_to_largest;

    // Find Function with Path Compression
    function [3:0] find(input [3:0] node);
        reg [3:0] root;
        reg [3:0] current;
        reg [3:0] next;
        reg [3:0] i;
        
        current = node;
        root = node;
        
        // Find root
        while (parent[root] != root) begin
            root = parent[root];
        end
        
        // Path compression
        current = node;
        while (current != root) begin
            next = parent[current];
            parent[current] = root;
            current = next;
        end
        
        find = root;
    endfunction

    // Union Function
    task union(input [3:0] a, input [3:0] b);
        reg [3:0] root_a;
        reg [3:0] root_b;
        
        root_a = find(a);
        root_b = find(b);
        
        if (root_a != root_b) begin
            if (size[root_a] < size[root_b]) begin
                parent[root_a] = root_b;
                size[root_b] = size[root_b] + size[root_a];
            end else begin
                parent[root_b] = root_a;
                size[root_a] = size[root_a] + size[root_b];
            end
        end
    endtask

    // Initialize Union-Find
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            edge_index <= 4'd0;
            gov_component_count <= 4'd0;
            largest_gov_component <= 4'd0;
            largest_gov_size <= 4'd0;
            total_possible_edges <= 16'd0;
            non_gov_nodes <= 16'd0;
            edges_to_largest <= 16'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                size[i] <= 4'd1;
                gov_component[i] <= 4'd0;
                gov_component_size[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    cycle_count <= 8'd0;
                    edge_index <= 4'd0;
                    gov_component_count <= 4'd0;
                    largest_gov_component <= 4'd0;
                    largest_gov_size <= 4'd0;
                    total_possible_edges <= 16'd0;
                    non_gov_nodes <= 16'd0;
                    edges_to_largest <= 16'd0;
                    
                    // Initialize Union-Find
                    for (i = 0; i < 16; i = i + 1) begin
                        parent[i] <= i;
                        size[i] <= 4'd1;
                        gov_component[i] <= 4'd0;
                        gov_component_size[i] <= 4'd0;
                    end
                    
                    next_state <= PROCESS_EDGES;
                end
                
                PROCESS_EDGES: begin
                    if (edge_index < m) begin
                        u = edges_u[edge_index];
                        v = edges_v[edge_index];
                        union(u, v);
                        edge_index <= edge_index + 4'd1;
                        next_state <= PROCESS_EDGES;
                    end else begin
                        next_state <= IDENTIFY_GOV;
                    end
                end
                
                IDENTIFY_GOV: begin
                    // Identify government components
                    for (i = 0; i < k; i = i + 1) begin
                        reg [3:0] node;
                        reg [3:0] root;
                        reg [3:0] j;
                        reg found;
                        
                        node = gov_nodes[i];
                        root = find(node);
                        
                        // Check if this component is already tracked
                        found = 1'b0;
                        for (j = 0; j < gov_component_count; j = j + 1) begin
                            if (gov_component[j] == root) begin
                                found = 1'b1;
                            end
                        end
                        
                        if (!found && gov_component_count < 16) begin
                            gov_component[gov_component_count] = root;
                            gov_component_size[gov_component_count] = size[root];
                            gov_component_count <= gov_component_count + 4'd1;
                            
                            // Track largest government component
                            if (size[root] > largest_gov_size) begin
                                largest_gov_component <= root;
                                largest_gov_size <= size[root];
                            end
                        end
                    end
                    
                    next_state <= CALC_RESULT;
                end
                
                CALC_RESULT: begin
                    reg [3:0] j;
                    reg [3:0] root;
                    reg [15:0] component_edges;
                    
                    // Calculate total possible edges within all components
                    for (j = 0; j < gov_component_count; j = j + 1) begin
                        root = gov_component[j];
                        component_edges = size[root] * (size[root] - 4'd1) / 2;
                        total_possible_edges <= total_possible_edges + component_edges;
                    end
                    
                    // Calculate non-government nodes
                    non_gov_nodes <= n - largest_gov_size;
                    
                    // Calculate edges to largest government component
                    edges_to_largest <= largest_gov_size * non_gov_nodes;
                    
                    // Final result
                    result <= total_possible_edges + edges_to_largest - m;
                    
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter for safety
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                cycle_count <= 8'd0;
                next_state <= IDLE;
            end
        end
    end

endmodule