module CycleBreaker #(
    parameter N_MAX = 8,
    parameter M_MAX = 16
)(
    input clk, rst_n, start,
    input [3:0] n,
    input [4:0] m,
    input [3:0] src [M_MAX-1:0],
    input [3:0] dst [M_MAX-1:0],
    output reg [4:0] r,
    output reg [3:0] remove_list [M_MAX/2-1:0],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] FIND_MAX = 4'd2;
    localparam [3:0] APPEND = 4'd3;
    localparam [3:0] UPDATE = 4'd4;
    localparam [3:0] CHECK_DONE = 4'd5;
    localparam [3:0] COMPUTE_REMOVAL = 4'd6;
    localparam [3:0] OUTPUT = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    reg [3:0] state, next_state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd100;

    // Adjacency matrix and outdegree
    reg [7:0] adj_matrix [N_MAX-1:0];
    reg [3:0] outdegree [N_MAX-1:0];
    reg [3:0] position [N_MAX-1:0];
    reg [3:0] active_vertices;
    reg [3:0] max_vertex;
    reg [3:0] max_degree;
    reg [3:0] current_vertex;
    reg [3:0] edge_index;
    reg [3:0] removal_index;
    reg [3:0] i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 4'd0;
            done <= 1'b0;
            r <= 5'd0;
            for (i = 0; i < M_MAX/2; i = i + 1) begin
                remove_list[i] <= 4'd0;
            end
            for (i = 0; i < N_MAX; i = i + 1) begin
                adj_matrix[i] <= 8'd0;
                outdegree[i] <= 4'd0;
                position[i] <= 4'd0;
            end
            active_vertices <= 4'd0;
            max_vertex <= 4'd0;
            max_degree <= 4'd0;
            current_vertex <= 4'd0;
            edge_index <= 4'd0;
            removal_index <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize adjacency matrix and outdegree
                    for (i = 0; i < N_MAX; i = i + 1) begin
                        adj_matrix[i] <= 8'd0;
                        outdegree[i] <= 4'd0;
                        position[i] <= 4'd0;
                    end
                    active_vertices <= n;
                    for (i = 0; i < m; i = i + 1) begin
                        adj_matrix[src[i]][dst[i]] <= 1'b1;
                        outdegree[src[i]] <= outdegree[src[i]] + 4'd1;
                    end
                    next_state <= FIND_MAX;
                end

                FIND_MAX: begin
                    max_degree <= 4'd0;
                    max_vertex <= 4'd0;
                    for (i = 0; i < N_MAX; i = i + 1) begin
                        if (position[i] == 4'd0 && outdegree[i] > max_degree) begin
                            max_degree <= outdegree[i];
                            max_vertex <= i;
                        end
                    end
                    next_state <= APPEND;
                end

                APPEND: begin
                    position[max_vertex] <= r + 4'd1;
                    r <= r + 4'd1;
                    active_vertices <= active_vertices - 4'd1;
                    current_vertex <= max_vertex;
                    next_state <= UPDATE;
                end

                UPDATE: begin
                    for (i = 0; i < N_MAX; i = i + 1) begin
                        if (position[i] == 4'd0 && adj_matrix[i][current_vertex]) begin
                            outdegree[i] <= outdegree[i] - 4'd1;
                        end
                    end
                    if (active_vertices == 4'd0) begin
                        next_state <= CHECK_DONE;
                    end else begin
                        next_state <= FIND_MAX;
                    end
                end

                CHECK_DONE: begin
                    next_state <= COMPUTE_REMOVAL;
                end

                COMPUTE_REMOVAL: begin
                    removal_index <= 4'd0;
                    for (i = 0; i < m; i = i + 1) begin
                        if (position[src[i]] > position[dst[i]]) begin
                            remove_list[removal_index] <= i + 4'd1;
                            removal_index <= removal_index + 4'd1;
                        end
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
            cycle_count <= cycle_count + 4'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
            end
        end
    end
endmodule