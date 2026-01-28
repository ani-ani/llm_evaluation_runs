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

    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_INIT = 4'd1;
    localparam [3:0] S_FOR_EDGE = 4'd2;
    localparam [3:0] S_BFS_INIT = 4'd3;
    localparam [3:0] S_BFS_LOOP = 4'd4;
    localparam [3:0] S_BFS_EDGE_LOOP = 4'd5;
    localparam [3:0] S_BFS_UPDATE = 4'd6;
    localparam [3:0] S_COUNT = 4'd7;
    localparam [3:0] S_UPDATE_MAX = 4'd8;
    localparam [3:0] S_NEXT_EDGE = 4'd9;
    localparam [3:0] S_DONE = 4'd10;

    reg [3:0] state;
    reg [3:0] edge_idx;
    reg [8:0] visited_reg;
    reg [3:0] max_protected;
    reg [3:0] count_curr;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] iteration_count;
    reg changed;
    reg [8:0] visited_temp;
    reg changed_temp;

    wire [7:0] current_edge = edges[edge_idx*8 +: 8];
    wire [3:0] current_u = current_edge[7:4];
    wire [3:0] current_v = current_edge[3:0];

    wire [7:0] edge_j = edges[j*8 +: 8];
    wire [3:0] u_j = edge_j[7:4];
    wire [3:0] v_j = edge_j[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
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
                    visited_reg <= 9'b0_0000_1000;
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
                    visited_reg <= 9'b0_0000_1000;
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
                        if (j != edge_idx) begin
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
                        if (j < M) begin
                            state <= S_BFS_EDGE_LOOP;
                        end else begin
                            state <= S_BFS_UPDATE;
                        end
                    end else begin
                        state <= S_BFS_UPDATE;
                    end
                end

                S_BFS_UPDATE: begin
                    visited_reg <= visited_temp;
                    changed <= changed_temp;
                    iteration_count <= iteration_count + 4'd1;
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
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule