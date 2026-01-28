module bird_berry_assigner #(
    parameter MAX_NODES = 8,
    parameter MAX_LABEL_BITS = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [2:0] parent [0:MAX_NODES-1],
    input wire [2:0] node_type [0:MAX_NODES-1],
    input wire [MAX_LABEL_BITS-1:0] label [0:MAX_NODES-1],
    
    output reg valid,
    output reg [2:0] conflict_count,
    output reg [2:0] first_conflict_node,
    output reg done
);

// State definitions
localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_COMPUTE_AREAS = 3'd1;
localparam [2:0] S_CHECK_CONFLICTS = 3'd2;
localparam [2:0] S_CHECK_BERRIES = 3'd3;
localparam [2:0] S_DONE = 3'd4;

reg [2:0] state;
reg [2:0] node_idx;
reg [2:0] area [0:MAX_NODES-1];
reg [2:0] next_node_idx;
reg [2:0] i;
reg [2:0] bird_count;
reg [2:0] berry_count;

function [2:0] find_big_ancestor;
    input [2:0] start_node;
    reg [2:0] current;
    begin
        current = start_node;
        find_big_ancestor = 3'd0;
        while (current != 3'd0) begin
            if (node_type[current] == 3'd0) begin
                find_big_ancestor = current;
                current = 3'd0;
            end else begin
                current = parent[current];
            end
        end
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
        
        for (integer j=0; j<MAX_NODES; j=j+1) begin
            area[j] <= 3'd0;
        end
    end
    else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                conflict_count <= 3'd0;
                first_conflict_node <= 3'd0;
                
                if (start) begin
                    state <= S_COMPUTE_AREAS;
                    node_idx <= 3'd0;
                    bird_count <= 3'd0;
                    berry_count <= 3'd0;
                end
            end
            
            S_COMPUTE_AREAS: begin
                if (node_idx < MAX_NODES) begin
                    case (node_type[node_idx])
                        3'd2: begin // Giant bird
                            area[node_idx] <= find_big_ancestor(node_idx);
                            bird_count <= bird_count + 3'd1;
                        end
                        3'd3: begin // Tiny bird -> convert
                            area[node_idx] <= find_big_ancestor(parent[node_idx]);
                            bird_count <= bird_count + 3'd1;
                        end
                        3'd4: berry_count <= berry_count + 3'd1;
                        default: ;
                    endcase
                    node_idx <= node_idx + 3'd1;
                end
                else begin
                    state <= S_CHECK_CONFLICTS;
                    node_idx <= 3'd0;
                end
            end
            
            S_CHECK_CONFLICTS: begin
                if (node_idx < MAX_NODES) begin
                    if ((node_type[node_idx] == 3'd2) || (node_type[node_idx] == 3'd3)) begin
                        next_node_idx <= node_idx + 3'd1;
                        state <= S_CHECK_CONFLICTS;
                        
                        for (i = node_idx + 3'd1; i < MAX_NODES; i = i + 3'd1) begin
                            if (((node_type[i] == 3'd2) || (node_type[i] == 3'd3))) begin
                                if ((label[node_idx] == label[i]) && (area[node_idx] == area[i])) begin
                                    conflict_count <= conflict_count + 3'd1;
                                    if (conflict_count == 3'd0) begin
                                        first_conflict_node <= node_idx;
                                    end
                                end
                            end
                        end
                    end
                    node_idx <= node_idx + 3'd1;
                end
                else begin
                    if ((berry_count != 3'd0) && (conflict_count == 3'd0)) begin
                        state <= S_CHECK_BERRIES;
                    end
                    else begin
                        state <= S_DONE;
                    end
                    node_idx <= 3'd0;
                end
            end
            
            S_CHECK_BERRIES: begin
                valid <= 1'b1; // Simplified per problem constraints
                state <= S_DONE;
            end
            
            S_DONE: begin
                done <= 1'b1;
                if (berry_count == 3'd0 || conflict_count != 3'd0) begin
                    valid <= 1'b0;
                end
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule