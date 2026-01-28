module army_movement_cost (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] parent_idx,
    input wire [15:0] edge_cost,
    input wire [15:0] army_curr,
    input wire [15:0] army_req,
    input wire valid_input,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_DATA  = 3'd1;
    localparam [2:0] CALC_NET   = 3'd2;
    localparam [2:0] ACCUM_COST = 3'd3;
    localparam [2:0] PROPAGATE  = 3'd4;
    localparam [2:0] FINISHED   = 3'd5;

    reg [2:0] state;
    reg [2:0] state_next;
    reg [2:0] node_idx;  // Current node being processed (0-7)
    
    // Lookup table for net flows (16-bit signed)
    reg signed [15:0] net_flow [0:7];
    
    // Storage for tree structure
    reg [2:0] parent_store [0:7];
    reg [15:0] cost_store [0:7];
    
    // Temporary calculation registers
    reg signed [15:0] net_temp;
    reg signed [31:0] abs_mult;
    reg [31:0] cost_acc;
    reg [31:0] accumulated_cost;
    
    // Control registers
    reg [2:0] node_counter;  // Counts 0..7 for loading
    reg [2:0] process_node;  // Node being processed in traversal
    reg [31:0] cycle_count;  // Safety counter
    localparam [31:0] MAX_CYCLES = 32'd1000;
    
    integer i;

    // State transition and register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            node_idx <= 3'd0;
            node_counter <= 3'd0;
            process_node <= 3'd0;
            cycle_count <= 32'd0;
            accumulated_cost <= 32'd0;
            cost_acc <= 32'd0;
            net_temp <= 16'sd0;
            abs_mult <= 32'sd0;
            
            // Initialize storage
            for (i = 0; i < 8; i = i + 1) begin
                net_flow[i] <= 16'sd0;
                parent_store[i] <= 3'd0;
                cost_store[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    node_counter <= 3'd0;
                    process_node <= 3'd0;
                    cycle_count <= 32'd0;
                    accumulated_cost <= 32'd0;
                    cost_acc <= 32'd0;
                    net_temp <= 16'sd0;
                    abs_mult <= 32'sd0;
                    
                    // Initialize storage
                    for (i = 0; i < 8; i = i + 1) begin
                        net_flow[i] <= 16'sd0;
                        parent_store[i] <= 3'd0;
                        cost_store[i] <= 16'd0;
                    end
                    
                    if (start) begin
                        state <= LOAD_DATA;
                    end
                end
                
                LOAD_DATA: begin
                    if (valid_input) begin
                        // Store parent and cost for nodes 1-7
                        // Node 0 is root, no parent
                        if (node_counter != 3'd0) begin
                            parent_store[node_counter] <= parent_idx;
                            cost_store[node_counter] <= edge_cost;
                        end
                        // Store initial net flow
                        net_flow[node_counter] <= $signed(army_curr) - $signed(army_req);
                        
                        node_counter <= node_counter + 3'd1;
                    end
                    
                    // Check if all 8 nodes loaded
                    if (node_counter == 3'd7 && (!valid_input || node_counter == 3'd7)) begin
                        state <= CALC_NET;
                        process_node <= 3'd7;  // Start from leaf (node 7)
                    end
                end
                
                CALC_NET: begin
                    // Process nodes from leaves to root (7 down to 0)
                    // Node 0 is root, skip propagation
                    if (process_node != 3'd0) begin
                        net_temp <= net_flow[process_node];
                        state <= ACCUM_COST;
                    end else begin
                        // All nodes processed
                        result <= accumulated_cost;
                        state <= FINISHED;
                    end
                end
                
                ACCUM_COST: begin
                    // Calculate abs(net * cost)
                    // Use signed multiplication
                    abs_mult <= $signed(net_temp) * $signed({{16{cost_store[process_node][15]}}, cost_store[process_node]});
                    state <= PROPAGATE;
                end
                
                PROPAGATE: begin
                    // Add to accumulated cost
                    if (abs_mult[31]) begin
                        accumulated_cost <= accumulated_cost - abs_mult[31:0];
                    end else begin
                        accumulated_cost <= accumulated_cost + abs_mult[31:0];
                    end
                    
                    // Propagate net flow to parent
                    net_flow[parent_store[process_node]] <= net_flow[parent_store[process_node]] + net_temp;
                    
                    // Move to next node
                    process_node <= process_node - 3'd1;
                    state <= CALC_NET;
                    cycle_count <= cycle_count + 32'd1;
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISHED;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule