module min_magic_path #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 16,
    parameter RESULT_WIDTH = 64
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    start,
    input  wire [3:0]              N,
    input  wire [MAX_N*MAX_N-1:0]  adj_flat,
    input  wire [MAX_N*DATA_WIDTH-1:0] magic_flat,
    output reg  [RESULT_WIDTH-1:0] result_numer,
    output reg  [RESULT_WIDTH-1:0] result_denom,
    output reg                     done
);

    // State definitions
    localparam [4:0] IDLE              = 5'd0;
    localparam [4:0] BUILD_INIT        = 5'd1;
    localparam [4:0] BUILD_LOOP        = 5'd2;
    localparam [4:0] BUILD_FOR_V       = 5'd3;
    localparam [4:0] INIT_STATE        = 5'd4;
    localparam [4:0] LOOP_I            = 5'd5;
    localparam [4:0] LOOP_J            = 5'd6;
    localparam [4:0] COMPUTE_PATH_START = 5'd7;
    localparam [4:0] COMPUTE_PATH_LOOP1 = 5'd8;
    localparam [4:0] COMPUTE_PATH_LOOP2 = 5'd9;
    localparam [4:0] COMPUTE_PATH_LOOP3 = 5'd10;
    localparam [4:0] COMPUTE_PATH_FINAL = 5'd11;
    localparam [4:0] COMPARE           = 5'd12;
    localparam [4:0] REDUCE            = 5'd13;
    localparam [4:0] REDUCE_LOOP       = 5'd14;
    localparam [4:0] DONE_STATE        = 5'd15;

    // Internal registers
    reg [4:0] state;
    reg [4:0] next_state;

    // BFS registers
    reg [MAX_N-1:0] visited;
    reg [3:0] parent [MAX_N-1:0];
    reg [3:0] depth [MAX_N-1:0];
    reg [3:0] queue [MAX_N-1:0];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] current_u;
    reg [3:0] v_counter;

    // Loop counters
    reg [3:0] i_counter;
    reg [3:0] j_counter;

    // Path computation registers
    reg [3:0] u_reg;
    reg [3:0] v_reg;
    reg [RESULT_WIDTH-1:0] prod;
    reg [RESULT_WIDTH-1:0] len;

    // Best registers
    reg [RESULT_WIDTH-1:0] best_product;
    reg [RESULT_WIDTH-1:0] best_len;

    // Reduce registers
    reg [RESULT_WIDTH-1:0] a_reg;
    reg [RESULT_WIDTH-1:0] b_reg;
    reg [RESULT_WIDTH-1:0] temp_reg;

    // Combinational arrays from flat inputs
    wire [DATA_WIDTH-1:0] magic [MAX_N-1:0];
    wire [MAX_N-1:0] adj [MAX_N-1:0];

    genvar i_gen, j_gen;
    generate
        for (i_gen = 0; i_gen < MAX_N; i_gen = i_gen + 1) begin : gen_magic
            assign magic[i_gen] = magic_flat[i_gen*DATA_WIDTH +: DATA_WIDTH];
        end
        for (i_gen = 0; i_gen < MAX_N; i_gen = i_gen + 1) begin : gen_adj_row
            for (j_gen = 0; j_gen < MAX_N; j_gen = j_gen + 1) begin : gen_adj_col
                assign adj[i_gen][j_gen] = adj_flat[i_gen*MAX_N + j_gen];
            end
        end
    endgenerate

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:               if (start) next_state = BUILD_INIT;
            BUILD_INIT:         next_state = BUILD_LOOP;
            BUILD_LOOP:         next_state = (queue_head != queue_tail) ? BUILD_FOR_V : INIT_STATE;
            BUILD_FOR_V:        next_state = (v_counter < N) ? BUILD_FOR_V : BUILD_LOOP;
            INIT_STATE:         next_state = LOOP_I;
            LOOP_I:             next_state = (i_counter < N) ? LOOP_J : REDUCE;
            LOOP_J:             next_state = (j_counter < N) ? COMPUTE_PATH_START : LOOP_I;
            COMPUTE_PATH_START: next_state = COMPUTE_PATH_LOOP1;
            COMPUTE_PATH_LOOP1: next_state = (depth[u_reg] > depth[v_reg]) ? COMPUTE_PATH_LOOP1 : COMPUTE_PATH_LOOP2;
            COMPUTE_PATH_LOOP2: next_state = (depth[v_reg] > depth[u_reg]) ? COMPUTE_PATH_LOOP2 : COMPUTE_PATH_LOOP3;
            COMPUTE_PATH_LOOP3: next_state = (u_reg != v_reg) ? COMPUTE_PATH_LOOP3 : COMPUTE_PATH_FINAL;
            COMPUTE_PATH_FINAL: next_state = COMPARE;
            COMPARE:            next_state = LOOP_J;
            REDUCE:             next_state = (b_reg != 0) ? REDUCE_LOOP : DONE_STATE;
            REDUCE_LOOP:        next_state = (b_reg != 0) ? REDUCE_LOOP : DONE_STATE;
            DONE_STATE:         next_state = DONE_STATE;
            default:            next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_numer <= 64'd0;
            result_denom <= 64'd0;
            visited <= {MAX_N{1'b0}};
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            current_u <= 4'd0;
            v_counter <= 4'd0;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            u_reg <= 4'd0;
            v_reg <= 4'd0;
            prod <= 64'd0;
            len <= 64'd0;
            best_product <= 64'd0;
            best_len <= 64'd0;
            a_reg <= 64'd0;
            b_reg <= 64'd0;
            temp_reg <= 64'd0;
            // Reset parent and depth arrays
            for (integer k = 0; k < MAX_N; k = k + 1) begin
                parent[k] <= 4'd0;
                depth[k] <= 4'd0;
                queue[k] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                BUILD_INIT: begin
                    visited <= 1 << 0;
                    parent[0] <= 4'd0;
                    depth[0] <= 4'd0;
                    queue[0] <= 4'd0;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd1;
                    current_u <= 4'd0;
                    v_counter <= 4'd0;
                end
                BUILD_LOOP: begin
                    if (queue_head != queue_tail) begin
                        current_u <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        v_counter <= 4'd0;
                    end
                end
                BUILD_FOR_V: begin
                    if (v_counter < N) begin
                        if (adj[current_u][v_counter] && !visited[v_counter]) begin
                            visited[v_counter] <= 1'b1;
                            parent[v_counter] <= current_u;
                            depth[v_counter] <= depth[current_u] + 4'd1;
                            queue[queue_tail] <= v_counter;
                            queue_tail <= queue_tail + 4'd1;
                        end
                        v_counter <= v_counter + 4'd1;
                    end
                end
                INIT_STATE: begin
                    best_product <= magic[0];
                    best_len <= 64'd1;
                    i_counter <= 4'd0;
                    j_counter <= 4'd0;
                end
                LOOP_I: begin
                    if (i_counter < N) begin
                        j_counter <= i_counter;
                    end
                end
                LOOP_J: begin
                    // No action here; handled in next_state logic
                end
                COMPUTE_PATH_START: begin
                    u_reg <= i_counter;
                    v_reg <= j_counter;
                    prod <= 64'd1;
                    len <= 64'd0;
                end
                COMPUTE_PATH_LOOP1: begin
                    if (depth[u_reg] > depth[v_reg]) begin
                        prod <= prod * magic[u_reg];
                        len <= len + 64'd1;
                        u_reg <= parent[u_reg];
                    end
                end
                COMPUTE_PATH_LOOP2: begin
                    if (depth[v_reg] > depth[u_reg]) begin
                        prod <= prod * magic[v_reg];
                        len <= len + 64'd1;
                        v_reg <= parent[v_reg];
                    end
                end
                COMPUTE_PATH_LOOP3: begin
                    if (u_reg != v_reg) begin
                        prod <= prod * magic[u_reg] * magic[v_reg];
                        len <= len + 64'd2;
                        u_reg <= parent[u_reg];
                        v_reg <= parent[v_reg];
                    end
                end
                COMPUTE_PATH_FINAL: begin
                    prod <= prod * magic[u_reg];
                    len <= len + 64'd1;
                end
                COMPARE: begin
                    if (prod * best_len < best_product * len) begin
                        best_product <= prod;
                        best_len <= len;
                    end
                    j_counter <= j_counter + 4'd1;
                end
                REDUCE: begin
                    a_reg <= best_product;
                    b_reg <= best_len;
                end
                REDUCE_LOOP: begin
                    if (b_reg != 64'd0) begin
                        temp_reg <= b_reg;
                        b_reg <= a_reg % b_reg;
                        a_reg <= temp_reg;
                    end
                end
                DONE_STATE: begin
                    result_numer <= best_product / a_reg;
                    result_denom <= best_len / a_reg;
                    done <= 1'b1;
                end
                default: begin
                    // No action for IDLE and others
                end
            endcase
        end
    end
endmodule