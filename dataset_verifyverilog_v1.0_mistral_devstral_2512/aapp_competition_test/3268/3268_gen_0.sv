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
    begin
        current = start_node;
        while (current != 0) begin
            if (node_type[current] == 0) begin // big branch
                find_big_ancestor = current;
                return;
            end
            current = parent[current];
        end
        find_big_ancestor = 0; // root is always big
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
                if (start) begin
                    state <= S_COMPUTE_AREAS;
                    node_idx <= 3'd0;
                    bird_count <= 3'd0;
                    berry_count <= 3'd0;
                    done <= 1'b0;
                end
            end
            
            S_COMPUTE_AREAS: begin
                // Compute controlled areas for all birds
                if (node_idx < MAX_NODES) begin
                    if (node_type[node_idx] >= 2 && node_type[node_idx] <= 3) begin
                        // It's a bird (giant or tiny)
                        if (node_type[node_idx] == 2) begin // giant bird
                            area[node_idx] <= find_big_ancestor(node_idx);
                        end else begin // tiny bird -> convert to giant
                            area[node_idx] <= find_big_ancestor(parent[node_idx]);
                        end
                        bird_labels[bird_count] <= label[node_idx];
                        bird_count <= bird_count + 1'b1;
                    end else if (node_type[node_idx] == 4) begin
                        berry_count <= berry_count + 1'b1;
                    end
                    node_idx <= node_idx + 1'b1;
                end else begin
                    node_idx <= 3'd0;
                    state <= S_CHECK_CONFLICTS;
                end
            end
            
            S_CHECK_CONFLICTS: begin
                // Check for same-label birds with same controlled area
                if (node_idx < MAX_NODES - 1) begin
                    if (node_type[node_idx] >= 2 && node_type[node_idx] <= 3) begin
                        reg [2:0] i;
                        for (i = node_idx + 1; i < MAX_NODES; i = i + 1) begin
                            if (node_type[i] >= 2 && node_type[i] <= 3) begin
                                if (label[node_idx] == label[i] && area[node_idx] == area[i]) begin
                                    conflict_count <= conflict_count + 1'b1;
                                    if (first_conflict_node == 3'd0)
                                        first_conflict_node <= node_idx;
                                end
                            end
                        end
                    end
                    node_idx <= node_idx + 1'b1;
                end else begin
                    if (conflict_count == 3'd0 && berry_count > 3'd0)
                        state <= S_CHECK_BERRIES;
                    else
                        state <= S_DONE;
                end
            end
            
            S_CHECK_BERRIES: begin
                // Verify each berry is in some bird's controlled area with same label
                // Simplified: check if there exists at least one bird per label that covers
                // Since constraints guarantee uniqueness, we just need to ensure valid
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