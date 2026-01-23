module bomb_disarm #(
    parameter R = 4,
    parameter C = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [R*C-1:0] grid,
    output reg [7:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] PROCESS = 3'd1;
localparam [2:0] UNION = 3'd2;
localparam [2:0] COUNT = 3'd3;
localparam [2:0] DONE_STATE = 3'd4;

reg [2:0] state;
reg [2:0] row, col;
reg [7:0] total_bombs;
reg [7:0] comp_count;
reg [2:0] parent [0:R+C-1];
reg has_bomb [0:R+C-1];
reg [2:0] root_list [0:R+C-1];
reg [2:0] root_count;
reg [2:0] node_iter;
reg [2:0] root_u, root_v;
reg [2:0] u, v;
reg start_counting;

integer i;

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 8'd0;
        total_bombs <= 8'd0;
        comp_count <= 8'd0;
        row <= 3'd0;
        col <= 3'd0;
        root_count <= 3'd0;
        node_iter <= 3'd0;
        start_counting <= 1'b0;
        
        // Initialize arrays
        for (i = 0; i < (R+C); i = i + 1) begin
            parent[i] <= 3'd0;
            has_bomb[i] <= 1'b0;
            root_list[i] <= 3'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    total_bombs <= 8'd0;
                    comp_count <= 8'd0;
                    row <= 3'd0;
                    col <= 3'd0;
                    root_count <= 3'd0;
                    node_iter <= 3'd0;
                    
                    // Initialize DSU
                    for (i = 0; i < (R+C); i = i + 1) begin
                        parent[i] <= i[2:0];
                        has_bomb[i] <= 1'b0;
                    end
                    
                    state <= PROCESS;
                end
            end

            PROCESS: begin
                if (row < R) begin
                    if (grid[row*C + col]) begin
                        total_bombs <= total_bombs + 8'd1;
                        
                        has_bomb[row] <= 1'b1;
                        has_bomb[R + col] <= 1'b1;
                        
                        // Find roots
                        u <= row;
                        v <= R + col;
                        state <= UNION;
                    end else begin
                        if (col == C-1) begin
                            col <= 3'd0;
                            row <= row + 3'd1;
                        end else begin
                            col <= col + 3'd1;
                        end
                    end
                end else begin
                    state <= COUNT;
                    node_iter <= 3'd0;
                    root_count <= 3'd0;
                    comp_count <= 8'd0;
                end
            end

            UNION: begin
                // Path compression - bounded loop
                while ((u != parent[u]) && (u != parent[parent[u]])) begin
                    parent[u] <= parent[parent[u]];
                    u <= parent[u];
                end
                root_u <= parent[u];
                
                while ((v != parent[v]) && (v != parent[parent[v]])) begin
                    parent[v] <= parent[parent[v]];
                    v <= parent[v];
                end
                root_v <= parent[v];
                
                // Union if different roots
                if (root_u != root_v) begin
                    parent[root_v] <= root_u;
                end
                
                // Move to next cell
                if (col == C-1) begin
                    col <= 3'd0;
                    row <= row + 3'd1;
                end else begin
                    col <= col + 3'd1;
                end
                
                state <= PROCESS;
            end

            COUNT: begin
                if (node_iter < (R+C)) begin
                    if (has_bomb[node_iter]) begin
                        reg [2:0] current = node_iter;
                        // Find root
                        repeat (R+C) begin
                            if (parent[current] != current) begin
                                current = parent[current];
                            end
                        end
                        
                        reg found = 1'b0;
                        for (i = 0; i < root_count; i = i + 1) begin
                            if (root_list[i] == current) found = 1'b1;
                        end
                        
                        if (!found) begin
                            root_list[root_count] <= current;
                            root_count <= root_count + 3'd1;
                            comp_count <= comp_count + 8'd1;
                        end
                    end
                    node_iter <= node_iter + 3'd1;
                end else begin
                    result <= total_bombs - comp_count;
                    state <= DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule