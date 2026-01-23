module secure_door (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] M,
    input [127:0] edges,
    output reg [3:0] result,
    output reg done
);

    // State definitions with explicit widths
    localparam [4:0] S_IDLE        = 5'd0;
    localparam [4:0] S_INIT        = 5'd1;
    localparam [4:0] S_FOR_EDGE    = 5'd2;
    localparam [4:0] S_BFS_INIT    = 5'd3;
    localparam [4:0] S_BFS_LOOP    = 5'd4;
    localparam [4:0] S_BFS_EDGE_LOOP = 5'd5;
    localparam [4:0] S_BFS_UPDATE  = 5'd6;
    localparam [4:0] S_COUNT       = 5'd7;
    localparam [4:0] S_UPDATE_MAX  = 5'd8;
    localparam [4:0] S_NEXT_EDGE   = 5'd9;
    localparam [4:0] S_DONE        = 5'd10;

    // Registers for sequential logic
    reg [4:0] state;
    reg [4:0] edge_idx;           // current edge being processed (0-15)
    reg [8:0] visited_reg;        // visited nodes (bit i for node i, bit 8 for outside)
    reg [3:0] max_protected;      // maximum protected rooms found
    reg [3:0] count_curr;         // count for current edge
    reg [3:0] i;                  // counter for room iteration
    reg [3:0] j;                  // counter for edge iteration
    reg [3:0] iteration_count;    // BFS iteration counter
    reg changed;                  // flag for BFS progress
    reg [8:0] visited_temp;       // temporary visited for BFS iteration
    reg changed_temp;             // temporary changed for BFS iteration

    // Combinational helpers for edge extraction (wire assignments)
    wire [7:0] current_edge;
    wire [3:0] current_u;
    wire [3:0] current_v;
    wire [7:0] edge_j;
    wire [3:0] u_j;
    wire [3:0] v_j;

    // Assign edge extraction (combinational logic)
    assign current_edge = edges[edge_idx * 8 +: 8];
    assign current_u = current_edge[7:4];
    assign current_v = current_edge[3:0];
    assign edge_j = edges[j * 8 +: 8];
    assign u_j = edge_j[7:4];
    assign v_j = edge_j[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= S_IDLE;
            done <= 1'b0;
            result <= 4'd0;
            edge_idx <= 4'd0;
            visited_reg <= 9'd0;
            max_protected <= 4'd0;
            count_curr <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            iteration_count <= 4'd0;
            changed <= 1'b0;
            visited_temp <= 9'd0;
            changed_temp <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        state <= S_INIT;
                    end
                end

                S_INIT: begin
                    max_protected <= 4'd0;
                    edge_idx <= 4'd0;
                    visited_reg <= 9'd0;
                    state <= S_FOR_EDGE;
                end

                S_FOR_EDGE: begin
                    if (edge_idx >= M) begin
                        state <= S_DONE;
                    end else begin
                        state <= S_BFS_INIT;
                    end
                end

                S_BFS_INIT: begin
                    // Set outside (node 8) as visited
                    visited_reg <= 9'b100000000;
                    iteration_count <= 4'd0;
                    state <= S_BFS_LOOP;
                end

                S_BFS_LOOP: begin
                    visited_temp <= visited_reg;
                    changed_temp <= 1'b0;
                    j <= 4'd0;
                    state <= S_BFS_EDGE_LOOP;
                end

                S_BFS_EDGE_LOOP: begin
                    if (j < M) begin
                        // Skip the edge being processed
                        if (j != edge_idx) begin
                            // Check if edge connects visited to unvisited
                            if (visited_reg[u_j] && !visited_reg[v_j]) begin
                                visited_temp[v_j] <= 1'b1;
                                changed_temp <= 1'b1;
                            end
                            if (visited_reg[v_j] && !visited_reg[u_j]) begin
                                visited_temp[u_j] <= 1'b1;
                                changed_temp <= 1'b1;
                            end
                        end
                        j <= j + 4'd1;
                        // Continue in same state (no break)
                        state <= S_BFS_EDGE_LOOP;
                    end else begin
                        state <= S_BFS_UPDATE;
                    end
                end

                S_BFS_UPDATE: begin
                    visited_reg <= visited_temp;
                    changed <= changed_temp;
                    iteration_count <= iteration_count + 4'd1;
                    // Limit iterations to prevent infinite loops
                    if (changed_temp && (iteration_count < 4'd8)) begin
                        state <= S_BFS_LOOP;
                    end else begin
                        state <= S_COUNT;
                        count_curr <= 4'd0;
                        i <= 4'd0;
                    end
                end

                S_COUNT: begin
                    if (i < N) begin
                        if (!visited_reg[i]) begin
                            count_curr <= count_curr + 4'd1;
                        end
                        i <= i + 4'd1;
                        state <= S_COUNT;
                    end else begin
                        state <= S_UPDATE_MAX;
                    end
                end

                S_UPDATE_MAX: begin
                    if (count_curr > max_protected) begin
                        max_protected <= count_curr;
                    end
                    state <= S_NEXT_EDGE;
                end

                S_NEXT_EDGE: begin
                    edge_idx <= edge_idx + 4'd1;
                    state <= S_FOR_EDGE;
                end

                S_DONE: begin
                    done <= 1'b1;
                    result <= max_protected;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule