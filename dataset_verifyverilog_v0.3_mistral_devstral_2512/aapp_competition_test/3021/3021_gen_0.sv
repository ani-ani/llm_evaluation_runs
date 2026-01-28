module AlphabetSolver(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] words [0:3][0:7],
    input [3:0] word_lengths [0:3],
    output reg [7:0] result_order [0:4],
    output reg [1:0] status,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_PREFIX = 3'd1;
    localparam [2:0] FIND_DIFF = 3'd2;
    localparam [2:0] ADD_EDGE = 3'd3;
    localparam [2:0] TOPO_INIT = 3'd4;
    localparam [2:0] TOPO_LOOP = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    reg [1:0] word_pair_idx;
    reg [2:0] char_pos;
    reg [1:0] current_word;
    reg [1:0] next_word;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg [1:0] src_char_idx;
    reg [1:0] dst_char_idx;
    reg [1:0] topo_node;
    reg [1:0] topo_count;
    reg [1:0] topo_idx;
    reg [1:0] zero_degree_count;
    reg [1:0] zero_degree_node;
    reg [1:0] i;
    reg [1:0] j;

    reg [4:0] edge_matrix [0:4][0:4];
    reg [3:0] in_degree [0:4];
    reg [3:0] topo_order [0:4];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 10'd0;
            word_pair_idx <= 2'd0;
            char_pos <= 3'd0;
            current_word <= 2'd0;
            next_word <= 2'd0;
            current_char <= 8'd0;
            next_char <= 8'd0;
            src_char_idx <= 2'd0;
            dst_char_idx <= 2'd0;
            topo_node <= 2'd0;
            topo_count <= 2'd0;
            topo_idx <= 2'd0;
            zero_degree_count <= 2'd0;
            zero_degree_node <= 2'd0;
            i <= 2'd0;
            j <= 2'd0;
            done <= 1'b0;
            status <= 2'd0;

            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    edge_matrix[i][j] <= 5'd0;
                end
                in_degree[i] <= 4'd0;
                topo_order[i] <= 4'd0;
                result_order[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    status <= 2'd0;
                    cycle_count <= 10'd0;
                    word_pair_idx <= 2'd0;
                    if (start) begin
                        state <= CHECK_PREFIX;
                    end
                end

                CHECK_PREFIX: begin
                    cycle_count <= cycle_count + 10'd1;
                    current_word <= word_pair_idx;
                    next_word <= word_pair_idx + 2'd1;

                    if (word_lengths[current_word] < word_lengths[next_word]) begin
                        if (words[current_word][char_pos] == words[next_word][char_pos]) begin
                            char_pos <= char_pos + 3'd1;
                            if (char_pos == word_lengths[current_word]) begin
                                state <= ADD_EDGE;
                            end
                        end else begin
                            state <= FIND_DIFF;
                        end
                    end else if (word_lengths[current_word] > word_lengths[next_word]) begin
                        if (words[current_word][char_pos] == words[next_word][char_pos]) begin
                            char_pos <= char_pos + 3'd1;
                            if (char_pos == word_lengths[next_word]) begin
                                status <= 2'd0;
                                state <= DONE_STATE;
                            end
                        end else begin
                            state <= FIND_DIFF;
                        end
                    end else begin
                        state <= FIND_DIFF;
                    end
                end

                FIND_DIFF: begin
                    cycle_count <= cycle_count + 10'd1;
                    current_char <= words[current_word][char_pos];
                    next_char <= words[next_word][char_pos];

                    if (current_char != next_char) begin
                        src_char_idx <= current_char - 8'd"a";
                        dst_char_idx <= next_char - 8'd"a";
                        state <= ADD_EDGE;
                    end else begin
                        char_pos <= char_pos + 3'd1;
                    end
                end

                ADD_EDGE: begin
                    cycle_count <= cycle_count + 10'd1;
                    edge_matrix[src_char_idx][dst_char_idx] <= 5'd1;
                    char_pos <= 3'd0;
                    word_pair_idx <= word_pair_idx + 2'd1;

                    if (word_pair_idx == N - 4'd1) begin
                        state <= TOPO_INIT;
                    end else begin
                        state <= CHECK_PREFIX;
                    end
                end

                TOPO_INIT: begin
                    cycle_count <= cycle_count + 10'd1;
                    for (i = 0; i < 5; i = i + 1) begin
                        in_degree[i] <= 4'd0;
                        for (j = 0; j < 5; j = j + 1) begin
                            if (edge_matrix[j][i] == 5'd1) begin
                                in_degree[i] <= in_degree[i] + 4'd1;
                            end
                        end
                    end
                    topo_count <= 2'd0;
                    topo_idx <= 2'd0;
                    state <= TOPO_LOOP;
                end

                TOPO_LOOP: begin
                    cycle_count <= cycle_count + 10'd1;
                    zero_degree_count <= 2'd0;
                    zero_degree_node <= 2'd0;

                    for (i = 0; i < 5; i = i + 1) begin
                        if (in_degree[i] == 4'd0) begin
                            zero_degree_count <= zero_degree_count + 2'd1;
                            if (zero_degree_count == 2'd1 || i < zero_degree_node) begin
                                zero_degree_node <= i;
                            end
                        end
                    end

                    if (zero_degree_count == 2'd0) begin
                        if (topo_count == 5'd5) begin
                            status <= 2'd2;
                            for (i = 0; i < 5; i = i + 1) begin
                                result_order[i] <= topo_order[i] + 8'd"a";
                            end
                            state <= DONE_STATE;
                        end else begin
                            status <= 2'd0;
                            state <= DONE_STATE;
                        end
                    end else if (zero_degree_count > 2'd1) begin
                        status <= 2'd1;
                        state <= DONE_STATE;
                    end else begin
                        topo_node <= zero_degree_node;
                        topo_order[topo_idx] <= topo_node;
                        topo_idx <= topo_idx + 2'd1;
                        topo_count <= topo_count + 2'd1;

                        for (i = 0; i < 5; i = i + 1) begin
                            if (edge_matrix[topo_node][i] == 5'd1) begin
                                in_degree[i] <= in_degree[i] - 4'd1;
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule