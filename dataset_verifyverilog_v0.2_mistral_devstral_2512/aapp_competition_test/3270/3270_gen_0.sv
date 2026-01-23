module word_ladder_optimizer (
    input clk,
    input reset,
    input start,
    input [31:0] dict [0:7],
    output reg [31:0] result_word,
    output reg [7:0] result_steps,
    output reg done
);

    // Parameters
    localparam MAX_WORDS = 8;
    localparam WORD_LEN = 4;
    localparam ALPHABET = 26;

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        BUILD_GRAPH,
        SEARCH_PATHS,
        FIND_OPTIMAL,
        DONE
    } state_t;

    // Internal signals
    state_t state;
    logic [7:0] cycle_count;
    logic [63:0] adjacency_matrix;
    logic [7:0] baseline_steps;
    logic [31:0] optimal_word;
    logic [7:0] optimal_steps;
    logic [31:0] candidate_word;
    logic [7:0] candidate_steps;
    logic [3:0] candidate_index;
    logic [3:0] word_index;
    logic [3:0] compare_index;
    logic [31:0] temp_word;
    logic [7:0] temp_steps;

    // Submodule instantiations
    difference_counter diff_counter (
        .word1(dict[word_index]),
        .word2(dict[compare_index]),
        .diff_count(temp_steps[0])
    );

    bfs_path_finder bfs_finder (
        .adjacency_matrix(adjacency_matrix),
        .start_node(0),
        .end_node(1),
        .path_length(temp_steps)
    );

    candidate_generator cand_gen (
        .dict(dict),
        .candidate_word(candidate_word),
        .candidate_index(candidate_index)
    );

    lexicographic_comparator lex_comp (
        .word1(candidate_word),
        .word2(optimal_word),
        .is_less(temp_steps[0])
    );

    // State machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            cycle_count <= 0;
            result_word <= 32'h30303030;
            result_steps <= 8'hFF;
            done <= 0;
            adjacency_matrix <= 0;
            baseline_steps <= 0;
            optimal_word <= 0;
            optimal_steps <= 0;
            candidate_word <= 0;
            candidate_steps <= 0;
            candidate_index <= 0;
            word_index <= 0;
            compare_index <= 0;
        end else if (start && state == IDLE) begin
            state <= BUILD_GRAPH;
            cycle_count <= 0;
            adjacency_matrix <= 0;
            word_index <= 0;
            compare_index <= 0;
        end else begin
            case (state)
                BUILD_GRAPH: begin
                    if (cycle_count < 16) begin
                        // Build adjacency matrix
                        if (word_index < MAX_WORDS && compare_index < MAX_WORDS) begin
                            if (word_index != compare_index) begin
                                // Check if words differ by exactly one character
                                if (temp_steps[0] == 1) begin
                                    adjacency_matrix[word_index * 8 + compare_index] <= 1;
                                end
                            end
                            compare_index <= compare_index + 1;
                            if (compare_index == MAX_WORDS) begin
                                compare_index <= 0;
                                word_index <= word_index + 1;
                            end
                        end
                        cycle_count <= cycle_count + 1;
                    end else begin
                        state <= SEARCH_PATHS;
                        cycle_count <= 0;
                        word_index <= 0;
                        compare_index <= 0;
                    end
                end

                SEARCH_PATHS: begin
                    if (cycle_count < 16) begin
                        // Compute baseline path length
                        if (cycle_count == 0) begin
                            bfs_finder.start_node <= 0;
                            bfs_finder.end_node <= 1;
                        end
                        if (cycle_count == 15) begin
                            baseline_steps <= temp_steps;
                        end
                        cycle_count <= cycle_count + 1;
                    end else begin
                        state <= FIND_OPTIMAL;
                        cycle_count <= 0;
                        candidate_index <= 0;
                        optimal_steps <= baseline_steps;
                        optimal_word <= 32'h30303030;
                    end
                end

                FIND_OPTIMAL: begin
                    if (cycle_count < 68) begin
                        // Try adding each possible word
                        if (cycle_count == 0) begin
                            cand_gen.candidate_index <= candidate_index;
                        end
                        if (cycle_count == 1) begin
                            // Update adjacency matrix with candidate word
                            temp_word <= candidate_word;
                            for (int i = 0; i < MAX_WORDS; i++) begin
                                if (i != 8) begin
                                    // Check if candidate differs by one character from existing words
                                    if (diff_counter.word1 == temp_word && diff_counter.word2 == dict[i] && diff_counter.diff_count == 1) begin
                                        adjacency_matrix[8 * 8 + i] <= 1;
                                        adjacency_matrix[i * 8 + 8] <= 1;
                                    end
                                end
                            end
                        end
                        if (cycle_count == 2) begin
                            // Run BFS with candidate word
                            bfs_finder.start_node <= 0;
                            bfs_finder.end_node <= 1;
                        end
                        if (cycle_count == 17) begin
                            candidate_steps <= temp_steps;
                            // Compare with optimal solution
                            if (candidate_steps < optimal_steps || (candidate_steps == optimal_steps && lex_comp.is_less)) begin
                                optimal_steps <= candidate_steps;
                                optimal_word <= candidate_word;
                            end
                            // Restore original adjacency matrix
                            adjacency_matrix <= adjacency_matrix & ~((1 << 8) - 1);
                            candidate_index <= candidate_index + 1;
                        end
                        cycle_count <= cycle_count + 1;
                    end else begin
                        state <= DONE;
                        cycle_count <= 0;
                    end
                end

                DONE: begin
                    if (optimal_steps < baseline_steps) begin
                        result_word <= optimal_word;
                        result_steps <= optimal_steps;
                    end else if (baseline_steps == 8'hFF) begin
                        result_word <= 32'h30303030;
                        result_steps <= 8'hFF;
                    end else begin
                        result_word <= 32'h30303030;
                        result_steps <= baseline_steps;
                    end
                    done <= 1;
                end

                default: begin
                    state <= IDLE;
                    done <= 0;
                end
            endcase
        end
    end

    // Submodule: difference_counter
    module difference_counter (
        input [31:0] word1,
        input [31:0] word2,
        output [7:0] diff_count
    );
        logic [31:0] xor_result;
        assign xor_result = word1 ^ word2;
        assign diff_count = ^xor_result ? 1 : 0;
    endmodule

    // Submodule: bfs_path_finder
    module bfs_path_finder (
        input [63:0] adjacency_matrix,
        input [3:0] start_node,
        input [3:0] end_node,
        output [7:0] path_length
    );
        logic [7:0] queue [0:7];
        logic [7:0] queue_ptr;
        logic [7:0] visited [0:7];
        logic [7:0] distance [0:7];
        logic [7:0] current_node;
        logic [7:0] neighbor;
        logic [7:0] i;

        always @(*) begin
            // Initialize
            for (i = 0; i < 8; i++) begin
                visited[i] <= 0;
                distance[i] <= 8'hFF;
            end
            queue_ptr <= 0;
            queue[0] <= start_node;
            visited[start_node] <= 1;
            distance[start_node] <= 0;

            // BFS
            for (i = 0; i < 8; i++) begin
                current_node <= queue[i];
                if (current_node == end_node) begin
                    path_length <= distance[current_node];
                    return;
                end
                for (neighbor = 0; neighbor < 8; neighbor++) begin
                    if (adjacency_matrix[current_node * 8 + neighbor] && !visited[neighbor]) begin
                        visited[neighbor] <= 1;
                        distance[neighbor] <= distance[current_node] + 1;
                        queue[queue_ptr] <= neighbor;
                        queue_ptr <= queue_ptr + 1;
                    end
                end
            end
            path_length <= 8'hFF;
        end
    endmodule

    // Submodule: candidate_generator
    module candidate_generator (
        input [31:0] dict [0:7],
        output [31:0] candidate_word,
        input [3:0] candidate_index
    );
        logic [31:0] temp_word;
        logic [7:0] char_pos;
        logic [7:0] char_val;
        logic [7:0] i;

        always @(*) begin
            temp_word <= dict[candidate_index / 26];
            char_pos <= candidate_index % 26;
            char_val <= 'A' + char_pos;
            // Modify one character
            for (i = 0; i < 4; i++) begin
                if (i == char_pos) begin
                    temp_word[i * 8 +: 8] <= char_val;
                end
            end
            candidate_word <= temp_word;
        end
    endmodule

    // Submodule: lexicographic_comparator
    module lexicographic_comparator (
        input [31:0] word1,
        input [31:0] word2,
        output is_less
    );
        assign is_less = (word1 < word2);
    endmodule

endmodule