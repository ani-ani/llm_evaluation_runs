module random_walk_meeting (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] s,
    input [2:0] t,
    input [63:0] adj_flat,
    output reg [31:0] result,
    output reg valid,
    output reg never_meet
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        INIT_EDGES,
        PREP_ITER,
        CALC_DEG,
        CHECK_NEVER,
        SUM_NEIGHBORS,
        UPDATE_E,
        NEXT_PAIR,
        NEXT_ITER,
        DONE,
        NEVER
    } state_t;

    state_t state, next_state;

    // E values: 64 pairs (i,j) in Q16.16
    reg [31:0] E [0:63];

    // Loop counters
    reg [5:0] iter_count;
    reg [2:0] i, j;

    // Degrees
    reg [2:0] deg_i, deg_j;

    // Sum accumulator
    reg [31:0] sum;

    // Neighbor counters
    reg [2:0] u, v;

    // Adjacency matrix access
    function logic [63:0] get_adj_row(input [2:0] row);
        integer k;
        logic [63:0] row_data;
        for (k = 0; k < 8; k = k + 1) begin
            row_data[k] = adj_flat[row * 8 + k];
        end
        return row_data;
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            never_meet <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_EDGES;
            end
            INIT_EDGES: begin
                next_state = PREP_ITER;
            end
            PREP_ITER: begin
                next_state = CALC_DEG;
            end
            CALC_DEG: begin
                next_state = CHECK_NEVER;
            end
            CHECK_NEVER: begin
                if ((deg_i == 0 || deg_j == 0) && (i != j)) begin
                    next_state = NEVER;
                end else begin
                    next_state = SUM_NEIGHBORS;
                end
            end
            SUM_NEIGHBORS: begin
                next_state = UPDATE_E;
            end
            UPDATE_E: begin
                next_state = NEXT_PAIR;
            end
            NEXT_PAIR: begin
                if (j == 7) begin
                    if (i == 7) begin
                        next_state = NEXT_ITER;
                    end else begin
                        next_state = CALC_DEG;
                    end
                end else begin
                    next_state = CALC_DEG;
                end
            end
            NEXT_ITER: begin
                if (iter_count == 19) begin
                    next_state = DONE;
                end else begin
                    next_state = PREP_ITER;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            NEVER: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iter_count <= 0;
            i <= 0;
            j <= 0;
            deg_i <= 0;
            deg_j <= 0;
            sum <= 0;
            u <= 0;
            v <= 0;
            for (integer k = 0; k < 64; k = k + 1) begin
                E[k] <= 0;
            end
        end else begin
            case (state)
                INIT_EDGES: begin
                    for (integer k = 0; k < 64; k = k + 1) begin
                        if (k[2:0] == k[5:3]) begin
                            E[k] <= 0; // Q16.16 zero
                        end else begin
                            E[k] <= 0; // Initial guess
                        end
                    end
                end
                PREP_ITER: begin
                    iter_count <= 0;
                    i <= 0;
                    j <= 0;
                end
                CALC_DEG: begin
                    deg_i = 0;
                    deg_j = 0;
                    for (integer k = 0; k < 8; k = k + 1) begin
                        if (adj_flat[i * 8 + k]) deg_i = deg_i + 1;
                        if (adj_flat[j * 8 + k]) deg_j = deg_j + 1;
                    end
                end
                SUM_NEIGHBORS: begin
                    sum = 0;
                    u = 0;
                    v = 0;
                end
                UPDATE_E: begin
                    if (i != j) begin
                        if (deg_i != 0 && deg_j != 0) begin
                            // E_new = 1 + (sum / (deg_i * deg_j))
                            // In Q16.16: (1 << 16) + (sum << 16) / (deg_i * deg_j)
                            E[i * 8 + j] = (1 << 16) + (sum << 16) / (deg_i * deg_j);
                        end
                    end
                end
                NEXT_PAIR: begin
                    if (j == 7) begin
                        if (i == 7) begin
                            iter_count = iter_count + 1;
                        end else begin
                            i = i + 1;
                            j = 0;
                        end
                    end else begin
                        j = j + 1;
                    end
                end
                NEXT_ITER: begin
                    iter_count = iter_count + 1;
                end
                DONE: begin
                    valid = 1;
                    result = E[s * 8 + t];
                end
                NEVER: begin
                    never_meet = 1;
                    result = 32'hFFFFFFFF;
                    valid = 1;
                end
            endcase
        end
    end

    // Sum neighbors logic
    always @(posedge clk) begin
        if (state == SUM_NEIGHBORS) begin
            if (u < 8 && v < 8) begin
                if (adj_flat[i * 8 + u] && adj_flat[j * 8 + v]) begin
                    sum = sum + E[u * 8 + v];
                end
                if (v == 7) begin
                    u = u + 1;
                    v = 0;
                end else begin
                    v = v + 1;
                end
            end
        end
    end

endmodule