module manuscript_reconstructor(
    input clk,
    input rst_n,
    input start,
    input [7:0] fragment_data,
    input fragment_valid,
    input fragment_end,
    input loading_done,
    output reg [7:0] result_char,
    output reg result_valid,
    output reg result_done,
    output reg ambiguous
);

    // Parameters
    localparam MAX_FRAGMENTS = 8;
    localparam MAX_FRAGMENT_LENGTH = 16;
    localparam OVERLAP_THRESHOLD = 5;
    localparam MAX_RESULT_LENGTH = 128;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] COMPUTE_OVERLAPS = 4'd2;
    localparam [3:0] BUILD_GRAPH = 4'd3;
    localparam [3:0] TOPOLOGICAL_SORT = 4'd4;
    localparam [3:0] DP_LONGEST_PATH = 4'd5;
    localparam [3:0] FIND_RESULT = 4'd6;
    localparam [3:0] RECONSTRUCT = 4'd7;
    localparam [3:0] OUTPUT = 4'd8;

    // Internal registers
    reg [3:0] state, next_state;
    reg [2:0] fragment_count;
    reg [3:0] fragment_index;
    reg [3:0] fragment_pos;
    reg [3:0] overlap_i, overlap_j;
    reg [3:0] graph_i, graph_j;
    reg [3:0] topo_i, topo_j;
    reg [3:0] dp_i, dp_j;
    reg [3:0] result_i;
    reg [3:0] max_path_count;
    reg [3:0] current_max_length;
    reg [3:0] current_node;
    reg [3:0] next_node;
    reg [3:0] output_index;
    reg [3:0] cycle_count;

    // Fragment storage
    reg [7:0] fragments [0:MAX_FRAGMENTS-1][0:MAX_FRAGMENT_LENGTH-1];
    reg [7:0] fragment_lengths [0:MAX_FRAGMENTS-1];

    // Overlap matrix
    reg [3:0] overlap_matrix [0:MAX_FRAGMENTS-1][0:MAX_FRAGMENTS-1];

    // Graph structures
    reg [3:0] in_degree [0:MAX_FRAGMENTS-1];
    reg [3:0] topo_order [0:MAX_FRAGMENTS-1];
    reg [3:0] topo_count;

    // DP arrays
    reg [3:0] longest_path_length [0:MAX_FRAGMENTS-1];
    reg [1:0] path_count [0:MAX_FRAGMENTS-1];
    reg [3:0] next_node_ptr [0:MAX_FRAGMENTS-1];

    // Result buffer
    reg [7:0] result_buffer [0:MAX_RESULT_LENGTH-1];
    reg [7:0] result_length;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            fragment_count <= 3'd0;
            fragment_index <= 3'd0;
            fragment_pos <= 3'd0;
            overlap_i <= 3'd0;
            overlap_j <= 3'd0;
            graph_i <= 3'd0;
            graph_j <= 3'd0;
            topo_i <= 3'd0;
            topo_j <= 3'd0;
            dp_i <= 3'd0;
            dp_j <= 3'd0;
            result_i <= 3'd0;
            max_path_count <= 3'd0;
            current_max_length <= 3'd0;
            current_node <= 3'd0;
            next_node <= 3'd0;
            output_index <= 3'd0;
            cycle_count <= 3'd0;
            result_char <= 8'd0;
            result_valid <= 1'b0;
            result_done <= 1'b0;
            ambiguous <= 1'b0;

            // Initialize fragment storage
            integer i, j;
            for (i = 0; i < MAX_FRAGMENTS; i = i + 1) begin
                fragment_lengths[i] <= 8'd0;
                for (j = 0; j < MAX_FRAGMENT_LENGTH; j = j + 1) begin
                    fragments[i][j] <= 8'd0;
                end
            end

            // Initialize overlap matrix
            for (i = 0; i < MAX_FRAGMENTS; i = i + 1) begin
                for (j = 0; j < MAX_FRAGMENTS; j = j + 1) begin
                    overlap_matrix[i][j] <= 4'd0;
                end
            end

            // Initialize graph structures
            for (i = 0; i < MAX_FRAGMENTS; i = i + 1) begin
                in_degree[i] <= 4'd0;
                topo_order[i] <= 4'd0;
            end
            topo_count <= 3'd0;

            // Initialize DP arrays
            for (i = 0; i < MAX_FRAGMENTS; i = i + 1) begin
                longest_path_length[i] <= 4'd0;
                path_count[i] <= 2'd0;
                next_node_ptr[i] <= 4'd0;
            end

            // Initialize result buffer
            for (i = 0; i < MAX_RESULT_LENGTH; i = i + 1) begin
                result_buffer[i] <= 8'd0;
            end
            result_length <= 8'd0;

        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (loading_done) begin
                    next_state = COMPUTE_OVERLAPS;
                end
            end

            COMPUTE_OVERLAPS: begin
                if (overlap_i == MAX_FRAGMENTS - 1 && overlap_j == MAX_FRAGMENTS - 1) begin
                    next_state = BUILD_GRAPH;
                end
            end

            BUILD_GRAPH: begin
                if (graph_i == MAX_FRAGMENTS - 1 && graph_j == MAX_FRAGMENTS - 1) begin
                    next_state = TOPOLOGICAL_SORT;
                end
            end

            TOPOLOGICAL_SORT: begin
                if (topo_count == fragment_count) begin
                    next_state = DP_LONGEST_PATH;
                end
            end

            DP_LONGEST_PATH: begin
                if (dp_i == fragment_count) begin
                    next_state = FIND_RESULT;
                end
            end

            FIND_RESULT: begin
                if (current_node == fragment_count) begin
                    if (max_path_count > 1) begin
                        ambiguous = 1'b1;
                    end
                    next_state = RECONSTRUCT;
                end
            end

            RECONSTRUCT: begin
                if (result_i == result_length) begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                if (output_index == result_length) begin
                    result_done = 1'b1;
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Load fragments
    always @(posedge clk) begin
        if (state == LOAD && fragment_valid) begin
            fragments[fragment_index][fragment_pos] <= fragment_data;
            if (fragment_end) begin
                fragment_lengths[fragment_index] <= fragment_pos + 1'b1;
                fragment_index <= fragment_index + 1'b1;
                fragment_pos <= 3'd0;
            else begin
                fragment_pos <= fragment_pos + 1'b1;
            end
        end
    end

    // Compute overlaps
    always @(posedge clk) begin
        if (state == COMPUTE_OVERLAPS) begin
            if (overlap_j == MAX_FRAGMENTS - 1) begin
                overlap_i <= overlap_i + 1'b1;
                overlap_j <= 3'd0;
            end else begin
                overlap_j <= overlap_j + 1'b1;
            end
        end
    end

    // Build graph
    always @(posedge clk) begin
        if (state == BUILD_GRAPH) begin
            if (graph_j == MAX_FRAGMENTS - 1) begin
                graph_i <= graph_i + 1'b1;
                graph_j <= 3'd0;
            end else begin
                graph_j <= graph_j + 1'b1;
            end
        end
    end

    // Topological sort
    always @(posedge clk) begin
        if (state == TOPOLOGICAL_SORT) begin
            // Kahn's algorithm implementation
            // (simplified for synthesis)
            if (topo_j == MAX_FRAGMENTS - 1) begin
                topo_i <= topo_i + 1'b1;
                topo_j <= 3'd0;
            end else begin
                topo_j <= topo_j + 1'b1;
            end
        end
    end

    // DP longest path
    always @(posedge clk) begin
        if (state == DP_LONGEST_PATH) begin
            if (dp_j == fragment_count - 1) begin
                dp_i <= dp_i + 1'b1;
                dp_j <= 3'd0;
            end else begin
                dp_j <= dp_j + 1'b1;
            end
        end
    end

    // Find result
    always @(posedge clk) begin
        if (state == FIND_RESULT) begin
            current_node <= current_node + 1'b1;
        end
    end

    // Reconstruct
    always @(posedge clk) begin
        if (state == RECONSTRUCT) begin
            result_i <= result_i + 1'b1;
        end
    end

    // Output
    always @(posedge clk) begin
        if (state == OUTPUT) begin
            result_char <= result_buffer[output_index];
            result_valid <= 1'b1;
            output_index <= output_index + 1'b1;
        end else begin
            result_valid <= 1'b0;
        end
    end

    // Overlap computation logic
    always @(*) begin
        if (state == COMPUTE_OVERLAPS) begin
            reg [3:0] max_overlap = 4'd0;
            reg [3:0] k;
            for (k = 0; k < MAX_FRAGMENT_LENGTH; k = k + 1) begin
                if (k < fragment_lengths[overlap_i] && k < fragment_lengths[overlap_j]) begin
                    if (fragments[overlap_i][fragment_lengths[overlap_i] - 1 - k] == fragments[overlap_j][k]) begin
                        max_overlap = k + 1'b1;
                    end else begin
                        k = MAX_FRAGMENT_LENGTH;
                    end
                end
            end
            if (max_overlap >= OVERLAP_THRESHOLD) begin
                overlap_matrix[overlap_i][overlap_j] = max_overlap;
            end else begin
                overlap_matrix[overlap_i][overlap_j] = 4'd0;
            end
        end
    end

    // Graph building logic
    always @(*) begin
        if (state == BUILD_GRAPH) begin
            if (overlap_matrix[graph_i][graph_j] > 4'd0) begin
                in_degree[graph_j] = in_degree[graph_j] + 1'b1;
            end
        end
    end

    // DP computation logic
    always @(*) begin
        if (state == DP_LONGEST_PATH) begin
            reg [3:0] max_len = 4'd0;
            reg [1:0] path_cnt = 2'd0;
            reg [3:0] best_next = 4'd0;
            reg [3:0] j;

            for (j = 0; j < fragment_count; j = j + 1) begin
                if (overlap_matrix[dp_i][j] > 4'd0) begin
                    if (longest_path_length[j] + overlap_matrix[dp_i][j] > max_len) begin
                        max_len = longest_path_length[j] + overlap_matrix[dp_i][j];
                        path_cnt = path_count[j];
                        best_next = j;
                    end else if (longest_path_length[j] + overlap_matrix[dp_i][j] == max_len) begin
                        path_cnt = path_cnt + path_count[j];
                        if (path_cnt > 2'd2) begin
                            path_cnt = 2'd2;
                        end
                    end
                end
            end

            longest_path_length[dp_i] = max_len + fragment_lengths[dp_i];
            path_count[dp_i] = path_cnt;
            next_node_ptr[dp_i] = best_next;
        end
    end

    // Result finding logic
    always @(*) begin
        if (state == FIND_RESULT) begin
            if (longest_path_length[current_node] > current_max_length) begin
                current_max_length = longest_path_length[current_node];
                max_path_count = 1'b1;
            end else if (longest_path_length[current_node] == current_max_length) begin
                max_path_count = max_path_count + 1'b1;
            end
        end
    end

    // Reconstruction logic
    always @(*) begin
        if (state == RECONSTRUCT) begin
            if (result_i == 0) begin
                result_buffer[result_i] = fragments[current_node][0];
            end else begin
                reg [3:0] overlap = overlap_matrix[current_node][next_node_ptr[current_node]];
                reg [3:0] pos = result_i - overlap;
                if (pos < fragment_lengths[next_node_ptr[current_node]]) begin
                    result_buffer[result_i] = fragments[next_node_ptr[current_node]][pos];
                end
                current_node = next_node_ptr[current_node];
            end
        end
    end

endmodule