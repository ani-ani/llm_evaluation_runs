module min_magic_path #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 16,   // magic value width
    parameter RESULT_WIDTH = 64  // result width
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    start,
    input  wire [3:0]              N,               // number of nodes (1..8)
    input  wire [MAX_N*MAX_N-1:0]  adj_flat,        // flattened adjacency matrix
    input  wire [MAX_N*DATA_WIDTH-1:0] magic_flat,   // flattened magic values
    output reg  [RESULT_WIDTH-1:0] result_numer,
    output reg  [RESULT_WIDTH-1:0] result_denom,
    output reg                     done
);

    // State definitions
    localparam [3:0] IDLE              = 4'd0;
    localparam [3:0] BUILD_INIT        = 4'd1;
    localparam [3:0] BUILD_LOOP        = 4'd2;
    localparam [3:0] BUILD_FOR_V       = 4'd3;
    localparam [3:0] INIT_STATE        = 4'd4;
    localparam [3:0] LOOP_I            = 4'd5;
    localparam [3:0] LOOP_J            = 4'd6;
    localparam [3:0] COMPUTE_PATH_START = 4'd7;
    localparam [3:0] COMPUTE_PATH_LOOP1 = 4'd8;
    localparam [3:0] COMPUTE_PATH_LOOP2 = 4'd9;
    localparam [3:0] COMPUTE_PATH_LOOP3 = 4'd10;
    localparam [3:0] COMPUTE_PATH_FINAL = 4'd11;
    localparam [3:0] COMPARE           = 4'd12;
    localparam [3:0] REDUCE            = 4'd13;
    localparam [3:0] REDUCE_LOOP       = 4'd14;
    localparam [3:0] DONE              = 4'd15;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;

    // BFS registers
    reg [MAX_N-1:0] visited;
    reg [3:0] parent [0:MAX_N-1];
    reg [3:0] depth [0:MAX_N-1];
    reg [3:0] queue [0:MAX_N-1];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] current_u;
    reg [3:0] v_counter;

    // Loop counters
    reg [3:0] i_counter;
    reg [3:0] j_counter;

    // Path computation registers
    reg [3:0] u_reg, v_reg;
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
    wire [DATA_WIDTH-1:0] magic [0:MAX_N-1];
    wire [MAX_N-1:0] adj [0:MAX_N-1];

    integer i, j;
    always @(*) begin
        for (i = 0; i < MAX_N; i = i + 1) begin
            magic[i] = magic_flat[i*DATA_WIDTH +: DATA_WIDTH];
            for (j = 0; j < MAX_N; j = j + 1) begin
                adj[i][j] = adj_flat[i*MAX_N + j];
            end
        end
    end

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
            REDUCE:             next_state = (b_reg != 0) ? REDUCE_LOOP : DONE;
            REDUCE_LOOP:        next_state = (b_reg != 0) ? REDUCE_LOOP : DONE;
            DONE:               next_state = DONE;
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
            visited <= 8'd0;
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
            for (i = 0; i < MAX_N; i = i + 1) begin
                parent[i] <= 4'd0;
                depth[i] <= 4'd0;
                queue[i] <= 4'd0;
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
                    if (b_reg != 0) begin
                        temp_reg <= b_reg;
                        b_reg <= a_reg % b_reg;
                        a_reg <= temp_reg;
                    end
                end
                DONE: begin
                    result_numer <= best_product / a_reg;
                    result_denom <= best_len / a_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule