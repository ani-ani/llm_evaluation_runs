module k_coloring_counter (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_edges,
    input [2:0] edge_u [0:5],
    input [2:0] edge_v [0:5],
    input [31:0] P,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    parameter N = 6;
    parameter K = 4;
    parameter MAX_EDGES = 6;

    typedef enum logic [2:0] {
        IDLE,
        INIT,
        COLORING,
        CHECK,
        UPDATE,
        DONE
    } state_t;

    state_t state, next_state;
    reg [2:0] color [0:N-1];
    reg [5:0] iter;
    reg [5:0] edge_idx;
    reg valid_coloring;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            valid <= 0;
            iter <= 0;
            edge_idx <= 0;
            for (int i = 0; i < N; i = i + 1) begin
                color[i] <= 0;
            end
        else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        result <= 0;
                        done <= 0;
                        valid <= 0;
                        iter <= 0;
                        edge_idx <= 0;
                        for (int i = 0; i < N; i = i + 1) begin
                            color[i] <= 0;
                        end
                    end
                end
                INIT: begin
                    iter <= 0;
                    edge_idx <= 0;
                    for (int i = 0; i < N; i = i + 1) begin
                        color[i] <= 0;
                    end
                end
                COLORING: begin
                    if (iter < (K**N - 1)) begin
                        iter <= iter + 1;
                        for (int i = 0; i < N; i = i + 1) begin
                            color[i] <= (iter >> (i * 2)) & 3;
                        end
                    end
                end
                CHECK: begin
                    if (edge_idx < num_edges) begin
                        edge_idx <= edge_idx + 1;
                    end else begin
                        edge_idx <= 0;
                    end
                end
                UPDATE: begin
                    if (valid_coloring) begin
                        if (result + 1 >= P) begin
                            result <= 0;
                        end else begin
                            result <= result + 1;
                        end
                    end
                end
                DONE: begin
                    done <= 1;
                    valid <= 1;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        valid_coloring = 1'b1;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                next_state = COLORING;
            end
            COLORING: begin
                if (iter < (K**N - 1)) begin
                    next_state = CHECK;
                end else begin
                    next_state = DONE;
                end
            end
            CHECK: begin
                if (edge_idx < num_edges) begin
                    if (color[edge_u[edge_idx]] == color[edge_v[edge_idx]]) begin
                        valid_coloring = 1'b0;
                    end
                end else begin
                    next_state = UPDATE;
                end
            end
            UPDATE: begin
                next_state = COLORING;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule