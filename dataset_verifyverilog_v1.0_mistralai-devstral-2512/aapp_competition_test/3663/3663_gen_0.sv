module tree_army_cost_calculator(
    input clk,
    input rst_n,
    input start,
    input [2:0] parent_idx,
    input [15:0] edge_cost,
    input [15:0] army_curr,
    input [15:0] army_req,
    input valid_input,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_DATA = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Node data storage
    reg [2:0] node_parent [0:7];
    reg [15:0] node_edge_cost [0:7];
    reg [15:0] node_army_curr [0:7];
    reg [15:0] node_army_req [0:7];
    
    // Computation variables
    reg signed [15:0] net_flow [0:7];
    reg [31:0] accumulated_cost;
    reg [2:0] current_node;
    reg [2:0] processing_node;
    reg [2:0] child_node;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                node_parent[i] <= 3'd0;
                node_edge_cost[i] <= 16'd0;
                node_army_curr[i] <= 16'd0;
                node_army_req[i] <= 16'd0;
                net_flow[i] <= 16'd0;
            end
            accumulated_cost <= 32'd0;
            current_node <= 3'd0;
            processing_node <= 3'd0;
            child_node <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_DATA;
                        current_node <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD_DATA: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (valid_input && current_node < 8) begin
                        // Store input data for current node
                        node_parent[current_node] <= parent_idx;
                        node_edge_cost[current_node] <= edge_cost;
                        node_army_curr[current_node] <= army_curr;
                        node_army_req[current_node] <= army_req;
                        current_node <= current_node + 3'd1;
                        
                        if (current_node == 8) begin
                            next_state <= COMPUTE;
                            processing_node <= 3'd0;
                        end
                    end else if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (processing_node == 3'd0) begin
                        // Initialize net flows for all nodes
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            net_flow[i] <= node_army_curr[i] - node_army_req[i];
                        end
                        accumulated_cost <= 32'd0;
                        processing_node <= 3'd1; // Start from node 1 (root)
                    end else begin
                        // Process current node
                        reg [2:0] parent;
                        parent = node_parent[processing_node];
                        
                        // Add child's net flow to parent's net flow
                        net_flow[parent] <= net_flow[parent] + net_flow[processing_node];
                        
                        // Calculate cost for this edge
                        reg [31:0] abs_flow;
                        reg [31:0] edge_cost_ext;
                        reg [31:0] product;
                        
                        // Absolute value of net flow
                        if (net_flow[processing_node][15]) begin
                            abs_flow = -net_flow[processing_node];
                        end else begin
                            abs_flow = net_flow[processing_node];
                        end
                        
                        // Extend edge cost to 32 bits
                        edge_cost_ext = node_edge_cost[processing_node];
                        
                        // Multiply and accumulate
                        product = abs_flow * edge_cost_ext;
                        accumulated_cost <= accumulated_cost + product;
                        
                        // Move to next node
                        processing_node <= processing_node + 3'd1;
                        
                        if (processing_node == 8) begin
                            next_state <= OUTPUT;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                OUTPUT: begin
                    result <= accumulated_cost;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule