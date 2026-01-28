module tree_distance_mark(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] parent_idx,
    input wire [3:0] parent_val,
    input wire load_mode,
    input wire [2:0] D_in,
    output reg [4:0] result,
    output reg done,
    output wire busy
);

    // State declarations
    localparam [2:0] STATE_IDLE   = 3'd0;
    localparam [2:0] STATE_LOAD   = 3'd1;
    localparam [2:0] STATE_BUILD  = 3'd2;
    localparam [2:0] STATE_COMPUTE = 3'd3;
    localparam [2:0] STATE_DONE   = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Parent array (16 nodes, 4-bit parent values)
    reg [3:0] parent [0:15];
    reg [3:0] load_idx;

    // Distance matrix (16x16, 4-bit distances)
    reg [3:0] dist_matrix [0:15][0:15];
    reg [3:0] build_i, build_j, build_k;

    // DP computation
    reg [15:0] marked_mask;
    reg [3:0] node_idx;
    reg [3:0] check_idx;
    reg [4:0] temp_result;

    // Busy signal
    assign busy = (state != STATE_IDLE) && (state != STATE_DONE);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            load_idx <= 4'd0;
            build_i <= 4'd0;
            build_j <= 4'd0;
            build_k <= 4'd0;
            node_idx <= 4'd0;
            check_idx <= 4'd0;
            temp_result <= 5'd0;
            marked_mask <= 16'd0;

            // Initialize parent array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= 4'd0;
            end

            // Initialize distance matrix
            integer j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    dist_matrix[i][j] <= 4'd0;
                end
            end
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (load_mode) begin
                            state <= STATE_LOAD;
                        end else begin
                            state <= STATE_BUILD;
                        end
                    end
                end

                STATE_LOAD: begin
                    if (load_idx == parent_idx) begin
                        parent[load_idx] <= parent_val;
                        load_idx <= load_idx + 5'd1;
                        if (load_idx == 5'd16) begin
                            load_idx <= 5'd0;
                            state <= STATE_BUILD;
                        end
                    end
                end

                STATE_BUILD: begin
                    // Floyd-Warshall algorithm
                    if (build_k == 4'd16) begin
                        build_k <= 4'd0;
                        build_i <= build_i + 4'd1;
                        if (build_i == 4'd16) begin
                            build_i <= 4'd0;
                            build_j <= build_j + 4'd1;
                            if (build_j == 4'd16) begin
                                build_j <= 4'd0;
                                state <= STATE_COMPUTE;
                            end
                        end
                    end else begin
                        // Update distance matrix
                        if (dist_matrix[build_i][build_k] + dist_matrix[build_k][build_j] < dist_matrix[build_i][build_j]) begin
                            dist_matrix[build_i][build_j] <= dist_matrix[build_i][build_k] + dist_matrix[build_k][build_j];
                        end
                        build_k <= build_k + 4'd1;
                    end
                end

                STATE_COMPUTE: begin
                    if (node_idx == 4'd16) begin
                        result <= temp_result;
                        state <= STATE_DONE;
                    end else begin
                        // Check if current node can be marked
                        reg can_mark;
                        can_mark = 1'b1;

                        if (check_idx == 4'd16) begin
                            if (can_mark) begin
                                marked_mask[node_idx] <= 1'b1;
                                temp_result <= temp_result + 5'd1;
                            end
                            node_idx <= node_idx + 4'd1;
                            check_idx <= 4'd0;
                        end else begin
                            if (marked_mask[check_idx] && dist_matrix[node_idx][check_idx] <= D_in) begin
                                can_mark = 1'b0;
                            end
                            check_idx <= check_idx + 4'd1;
                        end
                    end
                end

                STATE_DONE: begin
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase

            // Cycle counter for timeout
            if (state != STATE_IDLE && state != STATE_DONE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= STATE_DONE;
                end
            end
        end
    end

    // Initialize distance matrix based on parent array
    always @(posedge clk) begin
        if (state == STATE_BUILD && build_i == 4'd0 && build_j == 4'd0 && build_k == 4'd0) begin
            // Initialize direct parent distances
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                if (parent[i] != 4'd15) begin  // 15 represents -1 (root)
                    dist_matrix[i][parent[i]] <= 4'd1;
                    dist_matrix[parent[i]][i] <= 4'd1;
                end
            end
        end
    end

endmodule