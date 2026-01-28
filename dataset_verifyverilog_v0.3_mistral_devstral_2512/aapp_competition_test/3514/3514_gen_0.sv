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
localparam [2:0] DONE = 3'd4;

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

// Helper task to initialize DSU
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < R+C; i = i + 1) begin
            parent[i] <= i[2:0];
            has_bomb[i] <= 0;
        end
    end
end

// Function to find root (combinational, with bounded loop)
function automatic [2:0] find_root(input [2:0] node);
    reg [2:0] current;
    begin
        current = node;
        for (i = 0; i < R+C; i = i + 1) begin
            if (parent[current] != current)
                current = parent[current];
        end
        find_root = current;
    end
endfunction

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 8'd0;
        total_bombs <= 8'd0;
        comp_count <= 8'd0;
        row <= 2'd0;
        col <= 2'd0;
        root_count <= 2'd0;
        node_iter <= 2'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    total_bombs <= 8'd0;
                    comp_count <= 8'd0;
                    row <= 2'd0;
                    col <= 2'd0;
                    root_count <= 2'd0;
                    node_iter <= 2'd0;
                    state <= PROCESS;
                end
            end

            PROCESS: begin
                if (row < R) begin
                    // Check current cell
                    if (grid[row*C + col]) begin
                        total_bombs <= total_bombs + 8'd1;
                        u <= row;
                        v <= R + col;
                        has_bomb[row] <= 1'b1;
                        has_bomb[R+col] <= 1'b1;
                        root_u <= find_root(row);
                        root_v <= find_root(R+col);
                        if (root_u != root_v) begin
                            state <= UNION;
                        end else begin
                            // Move to next cell
                            if (col == C-1) begin
                                col <= 2'd0;
                                row <= row + 2'd1;
                            end else begin
                                col <= col + 2'd1;
                            end
                        end
                    end else begin
                        // No bomb, move to next cell
                        if (col == C-1) begin
                            col <= 2'd0;
                            row <= row + 2'd1;
                        end else begin
                            col <= col + 2'd1;
                        end
                    end
                end else begin
                    // Finished all cells
                    state <= COUNT;
                    node_iter <= 2'd0;
                    root_count <= 2'd0;
                    comp_count <= 8'd0;
                end
            end

            UNION: begin
                parent[root_v] <= root_u;
                if (col == C-1) begin
                    col <= 2'd0;
                    row <= row + 2'd1;
                end else begin
                    col <= col + 2'd1;
                end
                state <= PROCESS;
            end

            COUNT: begin
                if (node_iter < R+C) begin
                    if (has_bomb[node_iter]) begin
                        reg [2:0] root = find_root(node_iter);
                        reg found = 1'b0;
                        for (i = 0; i < root_count; i = i + 1) begin
                            if (root_list[i] == root) found = 1'b1;
                        end
                        if (!found) begin
                            root_list[root_count] <= root;
                            root_count <= root_count + 2'd1;
                            comp_count <= comp_count + 8'd1;
                        end
                    end
                    node_iter <= node_iter + 2'd1;
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