module bird_berry_assigner #(
    parameter MAX_NODES = 8,
    parameter MAX_LABEL_BITS = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Tree structure: node 0 is root
    input wire [2:0] parent [0:MAX_NODES-1],      // Parent index (0-7)
    input wire [2:0] node_type [0:MAX_NODES-1],   // 0:big branch, 1:small branch, 2:giant bird, 3:tiny bird, 4:berry
    input wire [MAX_LABEL_BITS-1:0] label [0:MAX_NODES-1], // ASCII char label
    
    output reg valid,              // 1 if labeling is valid after tiny->giant conversion
    output reg [2:0] conflict_count, // number of same-label birds with same controlled area
    output reg [2:0] first_conflict_node, // node ID of first conflict
    output reg done                // computation finished
);

// State definitions
localparam [2:0] S_IDLE = 3'b000;
localparam [2:0] S_COMPUTE_AREAS = 3'b001;
localparam [2:0] S_CHECK_CONFLICTS = 3'b010;
localparam [2:0] S_CHECK_BERRIES = 3'b011;
localparam [2:0] S_DONE = 3'b100;

reg [2:0] state;
reg [2:0] node_idx;
reg [2:0] area [0:MAX_NODES-1];  // Controlled area root for each bird
reg [MAX_LABEL_BITS-1:0] bird_labels [0:MAX_NODES-1]; // Labels of birds only
reg [2:0] bird_count;
reg [2:0] berry_count;

// Helper: Find closest big branch ancestor
function automatic [2:0] find_big_ancestor;
    input [2:0] start_node;
    reg [2:0] current;
    reg found;
    begin
        current = start_node;
        found = 0;
        while (!found && current != 0) begin
            if (node_type[current] == 0) begin // big branch
                found = 1;
            end else begin
                current = parent[current];
            end
        end
        find_big_ancestor = current;
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        conflict_count <= 3'd0;
        first_conflict_node <= 3'd0;
        node_idx <= 3'd0;
        bird_count <= 3'd0;
        berry_count <= 3'd0;
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    state <= S_COMPUTE_AREAS;
                    node_idx <= 3'd0;
                    bird_count <= 3'd0;
                    berry_count <= 3'd0;
                end
            end
            
            S_COMPUTE_AREAS: begin
                if (node_idx < MAX_NODES) begin
                    if (node_type[node_idx] >= 3'd2 && node_type[node_idx] <= 3'd3) begin
                        // It's a bird (giant or tiny)
                        if (node_type[node_idx] == 3'd2) begin // giant bird
                            area[node_idx] <= find_big_ancestor(node_idx);
                        end else begin // tiny bird -> convert to giant
                            area[node_idx] <= find_big_ancestor(parent[node_idx]);
                        end
                        if (bird_count < MAX_NODES) begin
                            bird_labels[bird_count] <= label[node_idx];
                            bird_count <= bird_count + 3'd1;
                        end
                    end else if (node_type[node_idx] == 3'd4) begin
                        berry_count <= berry_count + 3'd1;
                    end
                    node_idx <= node_idx + 3'd1;
                end else begin
                    node_idx <= 3'd0;
                    state <= S_CHECK_CONFLICTS;
                end
            end
            
            S_CHECK_CONFLICTS: begin
                if (node_idx < MAX_NODES) begin
                    if (node_type[node_idx] >= 3'd2 && node_type[node_idx] <= 3'd3) begin
                        reg [2:0] i;
                        for (i = node_idx + 3'd1; i < MAX_NODES; i = i + 3'd1) begin
                            if (node_type[i] >= 3'd2 && node_type[i] <= 3'd3) begin
                                if (label[node_idx] == label[i] && area[node_idx] == area[i]) begin
                                    conflict_count <= conflict_count + 3'd1;
                                    if (first_conflict_node == 3'd0)
                                        first_conflict_node <= node_idx;
                                end
                            end
                        end
                    end
                    node_idx <= node_idx + 3'd1;
                end else begin
                    if (conflict_count == 3'd0 && berry_count > 3'd0)
                        state <= S_CHECK_BERRIES;
                    else
                        state <= S_DONE;
                end
            end
            
            S_CHECK_BERRIES: begin
                valid <= (conflict_count == 3'd0);
                state <= S_DONE;
            end
            
            S_DONE: begin
                done <= 1'b1;
                if (conflict_count == 3'd0 && berry_count > 3'd0)
                    valid <= 1'b1;
                else
                    valid <= 1'b0;
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule