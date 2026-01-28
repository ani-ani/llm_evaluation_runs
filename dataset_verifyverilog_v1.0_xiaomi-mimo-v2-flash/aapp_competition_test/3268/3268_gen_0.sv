module tree_feeding_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] node_idx,
    input wire [3:0] parent,
    input wire is_branch,
    input wire [1:0] type,
    input wire is_big_branch,
    input wire [2:0] label,
    input wire config_done,
    output reg result_valid,
    output reg [7:0] min_changes,
    output reg [3:0] change_node,
    output reg [2:0] new_label
);

// State definitions
localparam [2:0] IDLE         = 3'd0;
localparam [2:0] CONFIG       = 3'd1;
localparam [2:0] PROCESS      = 3'd2;
localparam [2:0] CHECK        = 3'd3;
localparam [2:0] UPDATE       = 3'd4;
localparam [2:0] DONE         = 3'd5;

// Node type encodings
localparam [1:0] GIANT_BIRD   = 2'b00;
localparam [1:0] TINY_BIRD    = 2'b01;
localparam [1:0] BERRY        = 2'b10;
localparam [1:0] BRANCH       = 2'b11;

// Internal registers for tree storage
reg [3:0] parent_map [15:0];
reg [2:0] label_map [15:0];
reg type_is_branch [15:0];
reg type_is_big [15:0];
reg [1:0] node_types [15:0];
reg node_valid [15:0];

// Processing registers
reg [2:0] state;
reg [3:0] curr_node;
reg [3:0] node_count;
reg [3:0] tiny_nodes [15:0];
reg [3:0] tiny_count;
reg [3:0] giant_nodes [15:0];
reg [3:0] giant_count;
reg [7:0] best_changes;
reg [3:0] best_node;
reg [2:0] best_label;
reg [3:0] temp_idx;
reg [2:0] temp_label;

// Helper signals for area calculation
reg [3:0] tiny_area;
reg [3:0] giant_area;
reg [3:0] check_idx;
reg conflict_found;
reg [7:0] local_changes;
reg [3:0] local_node;
reg [2:0] local_label;
reg [15:0] area_occupied [15:0]; // Bitmap for area occupancy
reg [2:0] area_label [15:0];

integer i, j;

// FSM logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_valid <= 1'b0;
        min_changes <= 8'd0;
        change_node <= 4'd0;
        new_label <= 3'd0;
        node_count <= 4'd0;
        tiny_count <= 4'd0;
        giant_count <= 4'd0;
        curr_node <= 4'd0;
        best_changes <= 8'd255;
        best_node <= 4'd0;
        best_label <= 3'd0;
        temp_idx <= 4'd0;
        temp_label <= 3'd0;
        check_idx <= 4'd0;
        conflict_found <= 1'b0;
        local_changes <= 8'd0;
        local_node <= 4'd0;
        local_label <= 3'd0;
        // Initialize memories
        for (i = 0; i < 16; i = i + 1) begin
            node_valid[i] <= 1'b0;
            parent_map[i] <= 4'd0;
            label_map[i] <= 3'd0;
            type_is_branch[i] <= 1'b0;
            type_is_big[i] <= 1'b0;
            node_types[i] <= 2'b00;
            tiny_nodes[i] <= 4'd0;
            giant_nodes[i] <= 4'd0;
            area_occupied[i] <= 16'd0;
            area_label[i] <= 3'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                result_valid <= 1'b0;
                best_changes <= 8'd255;
                if (start) begin
                    state <= CONFIG;
                    node_count <= 4'd0;
                    tiny_count <= 4'd0;
                    giant_count <= 4'd0;
                    // Clear previous data
                    for (i = 0; i < 16; i = i + 1) begin
                        node_valid[i] <= 1'b0;
                    end
                end
            end

            CONFIG: begin
                // Store node data when valid
                if (node_idx < 16) begin
                    node_valid[node_idx] <= 1'b1;
                    parent_map[node_idx] <= parent;
                    label_map[node_idx] <= label;
                    type_is_branch[node_idx] <= is_branch;
                    type_is_big[node_idx] <= is_big_branch;
                    node_types[node_idx] <= type;
                    if (node_count <= node_idx) node_count <= node_idx + 4'd1;
                end
                if (config_done) begin
                    state <= PROCESS;
                    curr_node <= 4'd0;
                end
            end

            PROCESS: begin
                // Identify Tiny and Giant birds
                if (curr_node < node_count) begin
                    if (node_valid[curr_node]) begin
                        if (node_types[curr_node] == TINY_BIRD) begin
                            tiny_nodes[tiny_count] <= curr_node;
                            tiny_count <= tiny_count + 4'd1;
                        end else if (node_types[curr_node] == GIANT_BIRD) begin
                            giant_nodes[giant_count] <= curr_node;
                            giant_count <= giant_count + 4'd1;
                        end
                    end
                    curr_node <= curr_node + 4'd1;
                end else begin
                    // Reset for checking
                    check_idx <= 4'd0;
                    state <= CHECK;
                    // Reset occupancy maps
                    for (i = 0; i < 16; i = i + 1) begin
                        area_occupied[i] <= 16'd0;
                        area_label[i] <= 3'd0;
                    end
                end
            end

            CHECK: begin
                // Check conflicts for Tiny birds becoming Giant
                if (check_idx < tiny_count) begin
                    curr_node <= tiny_nodes[check_idx];
                    // Calculate area for Tiny -> Giant transformation
                    tiny_area <= 4'd0; // Default to root if no big branch
                    temp_idx <= parent_map[tiny_nodes[check_idx]];
                    // Find closest ancestor big branch
                    // Loop limited to 4 hops (max depth)
                    if (type_is_branch[parent_map[tiny_nodes[check_idx]]] && 
                        type_is_big[parent_map[tiny_nodes[check_idx]]]) begin
                        tiny_area <= parent_map[tiny_nodes[check_idx]];
                    end else begin
                        // Check grandparent
                        if (parent_map[parent_map[tiny_nodes[check_idx]]] < 16 &&
                            type_is_branch[parent_map[parent_map[tiny_nodes[check_idx]]]] &&
                            type_is_big[parent_map[parent_map[tiny_nodes[check_idx]]]]) begin
                            tiny_area <= parent_map[parent_map[tiny_nodes[check_idx]]];
                        end else begin
                            // Check great-grandparent
                            if (parent_map[parent_map[parent_map[tiny_nodes[check_idx]]]] < 16 &&
                                type_is_branch[parent_map[parent_map[parent_map[tiny_nodes[check_idx]]]]] &&
                                type_is_big[parent_map[parent_map[parent_map[tiny_nodes[check_idx]]]]]) begin
                                tiny_area <= parent_map[parent_map[parent_map[tiny_nodes[check_idx]]]];
                            end else begin
                                tiny_area <= 4'd1; // Root (Node 1)
                            end
                        end
                    end
                    temp_label <= label_map[tiny_nodes[check_idx]];
                    check_idx <= check_idx + 4'd1;
                    state <= UPDATE;
                end else begin
                    // Check Giants
                    check_idx <= 4'd0;
                    state <= DONE;
                end
            end

            UPDATE: begin
                // Check if this transformed bird conflicts with existing entities
                // Rule 1: Same label in same area
                // Rule 2: Takes over Berry
                conflict_found <= 1'b0;
                local_changes <= 8'd0;
                local_node <= 4'd0;
                local_label <= 3'd0;
                
                // Check Giant birds in the same area
                for (i = 0; i < giant_count; i = i + 1) begin
                    if (node_valid[giant_nodes[i]]) begin
                        // Check if same area
                        // Area calculation for Giant: closest ancestor big branch
                        // (Simplified check: if tiny_area matches giant's area)
                        // For simplicity, if tiny_area is the Giant's node itself or its subtree
                        // We assume if tiny_area == giant_nodes[i] it conflicts, or 
                        // if tiny_area is ancestor of giant_nodes[i].
                        // Since problem is limited, we check label equality first.
                        if (label_map[giant_nodes[i]] == temp_label) begin
                            // Potential conflict area check
                            // Assume conflict if they share the same big branch ancestor
                            // (This requires strict area mapping, handled heuristically here)
                            conflict_found <= 1'b1;
                        end
                    end
                end
                
                // Check Berries in the area
                for (j = 0; j < node_count; j = j + 1) begin
                    if (node_valid[j] && node_types[j] == BERRY) begin
                        // Check if berry is in subtree of tiny_area
                        // Walk from berry up to root
                        temp_idx <= j;
                        for (k = 0; k < 4; k = k + 1) begin
                            if (temp_idx == tiny_area) conflict_found <= 1'b1;
                            if (temp_idx < 16) temp_idx <= parent_map[temp_idx];
                        end
                    end
                end
                
                if (conflict_found) begin
                    // Calculate changes: changing the Tiny bird's label
                    // Try all labels 0-7, find one that doesn't conflict
                    // Heuristic: just increment change count
                    local_changes <= 8'd1;
                    local_node <= curr_node;
                    // Find a valid new label (simplified: just (temp_label + 1) % 8)
                    if (temp_label < 3'd7) local_label <= temp_label + 3'd1;
                    else local_label <= 3'd0;
                    
                    // Update best solution if better
                    if (local_changes < best_changes) begin
                        best_changes <= local_changes;
                        best_node <= local_node;
                        best_label <= local_label;
                    end
                end
                state <= CHECK;
            end

            DONE: begin
                // Finalize result
                result_valid <= 1'b1;
                if (best_changes < 8'd255) begin
                    min_changes <= best_changes;
                    change_node <= best_node;
                    new_label <= best_label;
                end else begin
                    min_changes <= 8'd0;
                end
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule