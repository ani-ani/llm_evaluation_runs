module orienteering_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [15:0] L,
    input [2:0] src_addr,
    input [2:0] dst_addr,
    input [7:0] dist_in,
    input wr_en,
    output reg result,
    output reg done
);

    // Parameters
    localparam MAX_N = 7;
    localparam MAX_L = 65535;
    localparam MAX_DIST = 255;

    // States
    typedef enum logic [2:0] {
        IDLE,
        LOAD_MATRIX,
        PERMUTING,
        CALCULATING,
        CHECKING,
        DONE
    } state_t;

    // State registers
    state_t current_state, next_state;

    // Distance matrix (8x8)
    reg [7:0] dist_matrix [0:7][0:7];

    // Permutation generation
    reg [2:0] perm [0:MAX_N-2];
    reg [2:0] perm_index;
    reg [2:0] perm_count;
    reg [2:0] c [0:MAX_N-1];
    reg [2:0] i;
    reg [2:0] swap_temp;

    // Path calculation
    reg [15:0] total_dist;
    reg [2:0] path_index;

    // Control signals
    reg match_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            match_found <= 0;
            perm_index <= 0;
            perm_count <= 0;
            path_index <= 0;
            total_dist <= 0;
            for (int j = 0; j < MAX_N; j = j + 1) begin
                for (int k = 0; k < MAX_N; k = k + 1) begin
                    dist_matrix[j][k] <= 0;
                end
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_MATRIX;
                end
            end
            LOAD_MATRIX: begin
                if (wr_en) begin
                    next_state = LOAD_MATRIX;
                end else begin
                    next_state = PERMUTING;
                end
            end
            PERMUTING: begin
                if (perm_count == (n-1)'d1) begin
                    next_state = CALCULATING;
                end else begin
                    next_state = PERMUTING;
                end
            end
            CALCULATING: begin
                if (path_index == n-1) begin
                    next_state = CHECKING;
                end else begin
                    next_state = CALCULATING;
                end
            end
            CHECKING: begin
                if (match_found) begin
                    next_state = DONE;
                end else if (perm_count == (n-1)! - 1) begin
                    next_state = DONE;
                end else begin
                    next_state = PERMUTING;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load distance matrix
    always @(posedge clk) begin
        if (current_state == LOAD_MATRIX && wr_en) begin
            dist_matrix[src_addr][dst_addr] <= dist_in;
            dist_matrix[dst_addr][src_addr] <= dist_in; // Symmetric
        end
    end

    // Permutation generation (Heap's algorithm)
    always @(posedge clk) begin
        if (current_state == PERMUTING) begin
            if (perm_index == 0) begin
                // Initialize permutation
                for (int j = 0; j < n-1; j = j + 1) begin
                    perm[j] <= j + 1;
                end
                for (int j = 0; j < MAX_N; j = j + 1) begin
                    c[j] <= 0;
                end
                perm_count <= 0;
            end

            if (perm_count < (n-1)! - 1) begin
                i <= c[perm_index];
                if (i < perm_index) begin
                    if ((perm_index % 2) == 0) begin
                        swap_temp <= perm[0];
                        perm[0] <= perm[perm_index];
                        perm[perm_index] <= swap_temp;
                    end else begin
                        swap_temp <= perm[i];
                        perm[i] <= perm[perm_index];
                        perm[perm_index] <= swap_temp;
                    end
                    c[perm_index] <= c[perm_index] + 1;
                    perm_index <= 0;
                    perm_count <= perm_count + 1;
                end else begin
                    c[perm_index] <= 0;
                    perm_index <= perm_index + 1;
                end
            end else begin
                perm_index <= 0;
            end
        end
    end

    // Calculate total distance
    always @(posedge clk) begin
        if (current_state == CALCULATING) begin
            if (path_index == 0) begin
                total_dist <= dist_matrix[0][perm[0]];
            end else if (path_index < n-1) begin
                total_dist <= total_dist + dist_matrix[perm[path_index-1]][perm[path_index]];
            end else begin
                total_dist <= total_dist + dist_matrix[perm[path_index-1]][0];
            end
            path_index <= path_index + 1;
        end else if (current_state == CHECKING) begin
            if (total_dist == L) begin
                match_found <= 1;
                result <= 1;
            end else begin
                match_found <= 0;
            end
            path_index <= 0;
        end else if (current_state == DONE) begin
            if (!match_found) begin
                result <= 0;
            end
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule