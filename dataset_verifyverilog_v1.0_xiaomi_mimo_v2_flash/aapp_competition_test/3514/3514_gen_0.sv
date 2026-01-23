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
localparam [2:0] IDLE    = 3'd0;
localparam [2:0] PROCESS = 3'd1;
localparam [2:0] UNION   = 3'd2;
localparam [2:0] COUNT   = 3'd3;
localparam [2:0] DONE    = 3'd4;

reg [2:0] state;
reg [2:0] next_state;
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
reg [2:0] i_index;
reg found_root;
reg [2:0] current_root;
reg [2:0] find_temp;
reg [2:0] find_result;
reg find_done;

// Combinational logic for finding root
always @(*) begin
    find_temp = 0;
    find_result = 0;
    find_done = 0;
    current_root = 0;
    // Note: We need find_root for specific node
    // This will be a blocking assignment in sequential block
end

// Main state machine - synchronous
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
        // Initialize arrays
        for (i_index = 0; i_index < R+C; i_index = i_index + 1) begin
            parent[i_index] <= i_index;
            has_bomb[i_index] <= 1'b0;
            root_list[i_index] <= 3'd0;
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
                    // Initialize arrays
                    for (i_index = 0; i_index < R+C; i_index = i_index + 1) begin
                        parent[i_index] <= i_index;
                        has_bomb[i_index] <= 1'b0;
                        root_list[i_index] <= 3'd0;
                    end
                    state <= PROCESS;
                end
            end

            PROCESS: begin
                if (row < R) begin
                    if (grid[row*C + col]) begin
                        total_bombs <= total_bombs + 8'd1;
                        u <= row;
                        v <= R + col;
                        has_bomb[row] <= 1'b1;
                        has_bomb[R+col] <= 1'b1;
                        // Find root for row
                        find_temp = row;
                        repeat (R+C) begin
                            if (parent[find_temp] != find_temp)
                                find_temp = parent[find_temp];
                        end
                        root_u <= find_temp;
                        // Find root for R+col
                        find_temp = R + col;
                        repeat (R+C) begin
                            if (parent[find_temp] != find_temp)
                                find_temp = parent[find_temp];
                        end
                        root_v <= find_temp;
                        if (root_u != root_v) begin
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
                parent[root_v] <= root_u;
                if (col == C-1) begin
                    col <= 3'd0;
                    row <= row + 3'd1;
                end else begin
                    col <= col + 3'd1;
                end
                state <= PROCESS;
            end

            COUNT: begin
                if (node_iter < R+C) begin
                    if (has_bomb[node_iter]) begin
                        // Find root for node_iter
                        find_temp = node_iter;
                        repeat (R+C) begin
                            if (parent[find_temp] != find_temp)
                                find_temp = parent[find_temp];
                        end
                        current_root <= find_temp;
                        found_root <= 1'b0;
                        // Search in root_list
                        for (i_index = 0; i_index < root_count; i_index = i_index + 1) begin
                            if (root_list[i_index] == current_root) begin
                                found_root <= 1'b1;
                            end
                        end
                        if (!found_root) begin
                            root_list[root_count] <= current_root;
                            root_count <= root_count + 3'd1;
                            comp_count <= comp_count + 8'd1;
                        end
                    end
                    node_iter <= node_iter + 3'd1;
                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                result <= total_bombs - comp_count;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule