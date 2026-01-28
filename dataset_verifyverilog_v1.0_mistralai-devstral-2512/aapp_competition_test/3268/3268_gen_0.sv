module bird_feeding_min_changes(
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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CONFIG = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Tree storage (16 nodes max)
    reg [3:0] parent_map [0:15];
    reg [2:0] label_map [0:15];
    reg is_branch_map [0:15];
    reg [1:0] type_map [0:15];
    reg is_big_branch_map [0:15];
    
    // Processing variables
    reg [3:0] current_node;
    reg [3:0] conflict_node;
    reg [2:0] conflict_label;
    reg [3:0] best_node;
    reg [2:0] best_label;
    reg [7:0] change_count;
    reg found_conflict;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            min_changes <= 8'd0;
            change_node <= 4'd0;
            new_label <= 3'd0;
            cycle_count <= 8'd0;
            
            // Initialize tree storage
            for (i = 0; i < 16; i = i + 1) begin
                parent_map[i] <= 4'd0;
                label_map[i] <= 3'd0;
                is_branch_map[i] <= 1'b0;
                type_map[i] <= 2'd0;
                is_big_branch_map[i] <= 1'b0;
            end
            
            current_node <= 4'd0;
            conflict_node <= 4'd0;
            conflict_label <= 3'd0;
            best_node <= 4'd0;
            best_label <= 3'd0;
            change_count <= 8'd0;
            found_conflict <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        state <= CONFIG;
                        current_node <= 4'd0;
                    end
                end
                
                CONFIG: begin
                    if (config_done) begin
                        state <= PROCESS;
                        current_node <= 4'd1;  // Start from node 1 (root)
                        change_count <= 8'd0;
                        found_conflict <= 1'b0;
                    end else if (node_idx != 4'd0) begin
                        // Store node configuration
                        parent_map[node_idx] <= parent;
                        label_map[node_idx] <= label;
                        is_branch_map[node_idx] <= is_branch;
                        type_map[node_idx] <= type;
                        is_big_branch_map[node_idx] <= is_big_branch;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check for timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Process current node
                        if (current_node < 4'd16) begin
                            // Check if this is a Tiny Bird (type=01)
                            if (!is_branch_map[current_node] && type_map[current_node] == 2'd1) begin
                                // Find closest ancestor Big Branch
                                reg [3:0] ancestor;
                                reg [3:0] temp_parent;
                                reg found_big;
                                
                                ancestor <= parent_map[current_node];
                                temp_parent <= parent_map[current_node];
                                found_big <= 1'b0;
                                
                                // Traverse up to find Big Branch
                                while (!found_big && temp_parent != 4'd0) begin
                                    if (is_branch_map[temp_parent] && is_big_branch_map[temp_parent]) begin
                                        ancestor <= temp_parent;
                                        found_big <= 1'b1;
                                    end
                                    temp_parent <= parent_map[temp_parent];
                                end
                                
                                // Check for conflicts with other Tiny Birds
                                reg [3:0] check_node;
                                for (check_node = 4'd1; check_node < 4'd16; check_node = check_node + 1) begin
                                    if (check_node != current_node && 
                                        !is_branch_map[check_node] && type_map[check_node] == 2'd1 &&
                                        label_map[check_node] == label_map[current_node]) begin
                                        
                                        // Find this node's closest Big Branch
                                        reg [3:0] other_ancestor;
                                        reg [3:0] other_temp;
                                        reg other_found;
                                        
                                        other_ancestor <= parent_map[check_node];
                                        other_temp <= parent_map[check_node];
                                        other_found <= 1'b0;
                                        
                                        while (!other_found && other_temp != 4'd0) begin
                                            if (is_branch_map[other_temp] && is_big_branch_map[other_temp]) begin
                                                other_ancestor <= other_temp;
                                                other_found <= 1'b1;
                                            end
                                            other_temp <= parent_map[other_temp];
                                        end
                                        
                                        // Conflict if same ancestor and same label
                                        if (ancestor == other_ancestor) begin
                                            found_conflict <= 1'b1;
                                            conflict_node <= check_node;
                                            conflict_label <= label_map[current_node];
                                        end
                                    end
                                end
                                
                                // If conflict found, propose a change
                                if (found_conflict) begin
                                    change_count <= change_count + 8'd1;
                                    best_node <= current_node;
                                    best_label <= (label_map[current_node] + 3'd1) % 3'd8;
                                end
                            end
                            
                            current_node <= current_node + 4'd1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    result_valid <= 1'b1;
                    min_changes <= change_count;
                    if (change_count > 8'd0) begin
                        change_node <= best_node;
                        new_label <= best_label;
                    end else begin
                        change_node <= 4'd0;
                        new_label <= 3'd0;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule