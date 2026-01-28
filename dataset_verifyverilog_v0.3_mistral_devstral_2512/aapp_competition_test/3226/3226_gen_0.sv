module escape_speed(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [2:0] m,
    input wire [2:0] e,
    input wire [2:0] b,
    input wire [2:0] p,
    input wire [2:0] exit0,
    input wire [2:0] exit1,
    input wire [2:0] exit2,
    input wire [2:0] exit3,
    input wire [2:0] exit4,
    input wire [2:0] exit5,
    input wire [2:0] exit6,
    input wire [2:0] exit7,
    input wire [2:0] edge_a0,
    input wire [2:0] edge_a1,
    input wire [2:0] edge_a2,
    input wire [2:0] edge_a3,
    input wire [2:0] edge_a4,
    input wire [2:0] edge_a5,
    input wire [2:0] edge_a6,
    input wire [2:0] edge_a7,
    input wire [2:0] edge_b0,
    input wire [2:0] edge_b1,
    input wire [2:0] edge_b2,
    input wire [2:0] edge_b3,
    input wire [2:0] edge_b4,
    input wire [2:0] edge_b5,
    input wire [2:0] edge_b6,
    input wire [2:0] edge_b7,
    input wire [7:0] edge_l0,
    input wire [7:0] edge_l1,
    input wire [7:0] edge_l2,
    input wire [7:0] edge_l3,
    input wire [7:0] edge_l4,
    input wire [7:0] edge_l5,
    input wire [7:0] edge_l6,
    input wire [7:0] edge_l7,
    input wire edge_valid0,
    input wire edge_valid1,
    input wire edge_valid2,
    input wire edge_valid3,
    input wire edge_valid4,
    input wire edge_valid5,
    input wire edge_valid6,
    input wire edge_valid7,
    output reg [31:0] speed_q16,
    output reg impossible,
    output reg done
);

    // State declarations
    localparam [4:0] IDLE = 5'd0;
    localparam [4:0] RESET_DIST = 5'd1;
    localparam [4:0] FLOYD_K_LOOP = 5'd2;
    localparam [4:0] FLOYD_I_LOOP = 5'd3;
    localparam [4:0] FLOYD_J_LOOP = 5'd4;
    localparam [4:0] FLOYD_UPDATE = 5'd5;
    localparam [4:0] COMPUTE_W = 5'd6;
    localparam [4:0] DIJKSTRA_INIT = 5'd7;
    localparam [4:0] DIJKSTRA_SELECT = 5'd8;
    localparam [4:0] DIJKSTRA_RELAX = 5'd9;
    localparam [4:0] DIJKSTRA_UPDATE = 5'd10;
    localparam [4:0] FIND_MIN_EXIT = 5'd11;
    localparam [4:0] COMPUTE_SPEED = 5'd12;
    localparam [4:0] DIVIDE = 5'd13;
    localparam [4:0] DONE = 5'd14;

    reg [4:0] state, next_state;

    // Distance matrix (8x8, 16-bit)
    reg [15:0] dist [0:7];
    integer i, j, k;

    // W values (numerator and denominator)
    reg [31:0] w_num [0:7];
    reg [15:0] w_den [0:7];

    // Dijkstra variables
    reg [31:0] best_num [0:7];
    reg [15:0] best_den [0:7];
    reg [7:0] visited;
    reg [2:0] current_node;
    reg [2:0] min_node;

    // Min exit fraction
    reg [31:0] M_num;
    reg [15:0] M_den;

    // Divider variables
    reg [31:0] dividend;
    reg [31:0] divisor;
    reg [31:0] quotient;
    reg [4:0] div_cycle;

    // Counters
    reg [2:0] k_counter;
    reg [2:0] i_counter;
    reg [2:0] j_counter;
    reg [2:0] exit_counter;
    reg [2:0] relax_counter;

    // Constants
    localparam [15:0] INF = 16'hFFFF;
    localparam [31:0] INF_NUM = 32'hFFFFFFFF;
    localparam [15:0] INF_DEN = 16'hFFFF;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            speed_q16 <= 32'd0;
            impossible <= 1'b0;
            done <= 1'b0;
            
            // Initialize distance matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (i == j) begin
                        dist[i][j] <= 16'd0;
                    end else begin
                        dist[i][j] <= INF;
                    end
                end
            end
            
            // Initialize other registers
            for (i = 0; i < 8; i = i + 1) begin
                w_num[i] <= 32'd0;
                w_den[i] <= 16'd0;
                best_num[i] <= INF_NUM;
                best_den[i] <= INF_DEN;
            end
            visited <= 8'd0;
            current_node <= 3'd0;
            min_node <= 3'd0;
            M_num <= INF_NUM;
            M_den <= INF_DEN;
            dividend <= 32'd0;
            divisor <= 32'd0;
            quotient <= 32'd0;
            div_cycle <= 5'd0;
            k_counter <= 3'd0;
            i_counter <= 3'd0;
            j_counter <= 3'd0;
            exit_counter <= 3'd0;
            relax_counter <= 3'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = RESET_DIST;
                end
            end

            RESET_DIST: begin
                // Apply edge lengths to distance matrix
                if (edge_valid0 && edge_a0 < n && edge_b0 < n) begin
                    dist[edge_a0][edge_b0] <= edge_l0;
                    dist[edge_b0][edge_a0] <= edge_l0;
                end
                if (edge_valid1 && edge_a1 < n && edge_b1 < n) begin
                    dist[edge_a1][edge_b1] <= edge_l1;
                    dist[edge_b1][edge_a1] <= edge_l1;
                end
                if (edge_valid2 && edge_a2 < n && edge_b2 < n) begin
                    dist[edge_a2][edge_b2] <= edge_l2;
                    dist[edge_b2][edge_a2] <= edge_l2;
                end
                if (edge_valid3 && edge_a3 < n && edge_b3 < n) begin
                    dist[edge_a3][edge_b3] <= edge_l3;
                    dist[edge_b3][edge_a3] <= edge_l3;
                end
                if (edge_valid4 && edge_a4 < n && edge_b4 < n) begin
                    dist[edge_a4][edge_b4] <= edge_l4;
                    dist[edge_b4][edge_a4] <= edge_l4;
                end
                if (edge_valid5 && edge_a5 < n && edge_b5 < n) begin
                    dist[edge_a5][edge_b5] <= edge_l5;
                    dist[edge_b5][edge_a5] <= edge_l5;
                end
                if (edge_valid6 && edge_a6 < n && edge_b6 < n) begin
                    dist[edge_a6][edge_b6] <= edge_l6;
                    dist[edge_b6][edge_a6] <= edge_l6;
                end
                if (edge_valid7 && edge_a7 < n && edge_b7 < n) begin
                    dist[edge_a7][edge_b7] <= edge_l7;
                    dist[edge_b7][edge_a7] <= edge_l7;
                end
                next_state = FLOYD_K_LOOP;
            end

            FLOYD_K_LOOP: begin
                if (k_counter < n) begin
                    i_counter <= 3'd0;
                    next_state = FLOYD_I_LOOP;
                end else begin
                    next_state = COMPUTE_W;
                end
            end

            FLOYD_I_LOOP: begin
                if (i_counter < n) begin
                    j_counter <= 3'd0;
                    next_state = FLOYD_J_LOOP;
                end else begin
                    k_counter <= k_counter + 3'd1;
                    next_state = FLOYD_K_LOOP;
                end
            end

            FLOYD_J_LOOP: begin
                if (j_counter < n) begin
                    next_state = FLOYD_UPDATE;
                end else begin
                    i_counter <= i_counter + 3'd1;
                    next_state = FLOYD_I_LOOP;
                end
            end

            FLOYD_UPDATE: begin
                if (dist[i_counter][k_counter] != INF && dist[k_counter][j_counter] != INF) begin
                    if (dist[i_counter][j_counter] > dist[i_counter][k_counter] + dist[k_counter][j_counter]) begin
                        dist[i_counter][j_counter] <= dist[i_counter][k_counter] + dist[k_counter][j_counter];
                    end
                end
                j_counter <= j_counter + 3'd1;
                next_state = FLOYD_J_LOOP;
            end

            COMPUTE_W: begin
                for (i = 0; i < n; i = i + 1) begin
                    if (dist[p][i] == 0) begin
                        w_num[i] <= 32'h7FFFFFFF;
                        w_den[i] <= 16'd1;
                    end else begin
                        w_num[i] <= 160 * dist[b][i];
                        w_den[i] <= dist[p][i];
                    end
                end
                next_state = DIJKSTRA_INIT;
            end

            DIJKSTRA_INIT: begin
                for (i = 0; i < n; i = i + 1) begin
                    best_num[i] <= INF_NUM;
                    best_den[i] <= INF_DEN;
                end
                visited <= 8'd0;
                best_num[b] <= 32'd0;
                best_den[b] <= 16'd1;
                next_state = DIJKSTRA_SELECT;
            end

            DIJKSTRA_SELECT: begin
                min_node <= 3'd0;
                for (i = 0; i < n; i = i + 1) begin
                    if (!visited[i] && (best_num[i] < INF_NUM) && 
                        (best_num[i] * best_den[min_node] < best_num[min_node] * best_den[i])) begin
                        min_node <= i;
                    end
                end
                if (best_num[min_node] == INF_NUM) begin
                    next_state = FIND_MIN_EXIT;
                end else begin
                    current_node <= min_node;
                    visited[min_node] <= 1'b1;
                    relax_counter <= 3'd0;
                    next_state = DIJKSTRA_RELAX;
                end
            end

            DIJKSTRA_RELAX: begin
                if (relax_counter < n) begin
                    if (dist[current_node][relax_counter] != INF) begin
                        // Compute candidate = max(best[current_node], w[relax_counter])
                        reg [31:0] candidate_num;
                        reg [15:0] candidate_den;
                        
                        if (best_num[current_node] * w_den[relax_counter] >= w_num[relax_counter] * best_den[current_node]) begin
                            candidate_num = best_num[current_node];
                            candidate_den = best_den[current_node];
                        end else begin
                            candidate_num = w_num[relax_counter];
                            candidate_den = w_den[relax_counter];
                        end
                        
                        // candidate = max(candidate, dist[current_node][relax_counter])
                        reg [31:0] dist_num = dist[current_node][relax_counter];
                        reg [15:0] dist_den = 16'd1;
                        
                        if (candidate_num * dist_den >= dist_num * candidate_den) begin
                            // candidate is larger
                        end else begin
                            candidate_num = dist_num;
                            candidate_den = dist_den;
                        end
                        
                        // Compare with best[relax_counter]
                        if (candidate_num * best_den[relax_counter] < best_num[relax_counter] * candidate_den) begin
                            best_num[relax_counter] <= candidate_num;
                            best_den[relax_counter] <= candidate_den;
                        end
                    end
                    relax_counter <= relax_counter + 3'd1;
                end else begin
                    next_state = DIJKSTRA_SELECT;
                end
            end

            DIJKSTRA_UPDATE: begin
                next_state = DIJKSTRA_SELECT;
            end

            FIND_MIN_EXIT: begin
                M_num <= INF_NUM;
                M_den <= INF_DEN;
                exit_counter <= 3'd0;
                for (i = 0; i < e; i = i + 1) begin
                    if (i == 0) begin
                        M_num <= best_num[exit0];
                        M_den <= best_den[exit0];
                    end else if (i == 1) begin
                        if (best_num[exit1] * M_den < M_num * best_den[exit1]) begin
                            M_num <= best_num[exit1];
                            M_den <= best_den[exit1];
                        end
                    end else if (i == 2) begin
                        if (best_num[exit2] * M_den < M_num * best_den[exit2]) begin
                            M_num <= best_num[exit2];
                            M_den <= best_den[exit2];
                        end
                    end else if (i == 3) begin
                        if (best_num[exit3] * M_den < M_num * best_den[exit3]) begin
                            M_num <= best_num[exit3];
                            M_den <= best_den[exit3];
                        end
                    end else if (i == 4) begin
                        if (best_num[exit4] * M_den < M_num * best_den[exit4]) begin
                            M_num <= best_num[exit4];
                            M_den <= best_den[exit4];
                        end
                    end else if (i == 5) begin
                        if (best_num[exit5] * M_den < M_num * best_den[exit5]) begin
                            M_num <= best_num[exit5];
                            M_den <= best_den[exit5];
                        end
                    end else if (i == 6) begin
                        if (best_num[exit6] * M_den < M_num * best_den[exit6]) begin
                            M_num <= best_num[exit6];
                            M_den <= best_den[exit6];
                        end
                    end else if (i == 7) begin
                        if (best_num[exit7] * M_den < M_num * best_den[exit7]) begin
                            M_num <= best_num[exit7];
                            M_den <= best_den[exit7];
                        end
                    end
                end
                next_state = COMPUTE_SPEED;
            end

            COMPUTE_SPEED: begin
                if (M_num == INF_NUM) begin
                    impossible <= 1'b1;
                    speed_q16 <= 32'd0;
                    next_state = DONE;
                end else begin
                    impossible <= 1'b0;
                    // Compute speed = (160 * M_den * 65536) / M_num
                    dividend <= 160 * M_den * 65536;
                    divisor <= M_num;
                    quotient <= 32'd0;
                    div_cycle <= 5'd0;
                    next_state = DIVIDE;
                end
            end

            DIVIDE: begin
                if (div_cycle < 32) begin
                    quotient <= quotient << 1;
                    if (dividend[31]) begin
                        quotient[0] <= 1'b1;
                        dividend <= dividend - divisor;
                    end
                    dividend <= dividend << 1;
                    div_cycle <= div_cycle + 5'd1;
                end else begin
                    speed_q16 <= quotient;
                    next_state = DONE;
                end
            end

            DONE: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule