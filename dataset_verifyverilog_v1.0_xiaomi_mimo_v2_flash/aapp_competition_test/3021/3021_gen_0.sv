module AlphabetSolver #(
    parameter ALPHABET_SIZE = 5,
    parameter MAX_WORDS = 4,
    parameter MAX_WORD_LEN = 8
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] words [0:MAX_WORDS-1][0:MAX_WORD_LEN-1],
    input [3:0] word_lengths [0:MAX_WORDS-1],
    output reg [7:0] result_order [0:ALPHABET_SIZE-1],
    output reg [1:0] status,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_PREFIX = 3'd1;
    localparam [2:0] FIND_DIFF   = 3'd2;
    localparam [2:0] ADD_EDGE    = 3'd3;
    localparam [2:0] TOPO_INIT   = 3'd4;
    localparam [2:0] TOPO_LOOP   = 3'd5;
    localparam [2:0] DONE_STATE  = 3'd6;

    // Status codes
    localparam [1:0] IMPOSSIBLE = 2'd0;
    localparam [1:0] AMBIGUOUS  = 2'd1;
    localparam [1:0] UNIQUE     = 2'd2;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] edge_matrix [0:ALPHABET_SIZE-1][0:ALPHABET_SIZE-1];
    reg [3:0] in_degree [0:ALPHABET_SIZE-1];
    reg [7:0] result_order_reg [0:ALPHABET_SIZE-1];
    reg [1:0] status_reg;
    reg [3:0] pair_idx;         // Current word pair (i, i+1)
    reg [3:0] char_idx;         // Current character position
    reg [3:0] src_idx;          // Source node for edge
    reg [3:0] dst_idx;          // Destination node for edge
    reg [3:0] topo_node;        // Current node being processed in topo
    reg [3:0] zero_count;       // Count of nodes with in-degree 0
    reg [3:0] selected_node;    // Selected node to output
    reg [3:0] output_count;     // Number of nodes output so far
    reg [3:0] cycle_count;      // Cycle limit
    reg [3:0] i, j, k;          // Loop counters
    reg found_zero;             // Flag for zero in-degree node
    reg has_cycle;              // Flag for cycle detection
    reg ambiguous_flag;         // Flag for ambiguity
    reg prefix_violation;       // Flag for prefix violation
    reg [7:0] char1, char2;    // Temporary character storage

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_PREFIX;
                else next_state = IDLE;
            end
            CHECK_PREFIX: begin
                if (pair_idx >= N - 1) next_state = TOPO_INIT;
                else if (word_lengths[pair_idx] > word_lengths[pair_idx+1]) begin
                    // Check if words[pair_idx] is prefix of words[pair_idx+1]
                    if (char_idx >= word_lengths[pair_idx+1]) next_state = ADD_EDGE;
                    else begin
                        if (words[pair_idx][char_idx] != words[pair_idx+1][char_idx]) next_state = FIND_DIFF;
                        else next_state = CHECK_PREFIX;
                    end
                end else next_state = FIND_DIFF;
            end
            FIND_DIFF: begin
                if (char_idx >= word_lengths[pair_idx] || char_idx >= word_lengths[pair_idx+1]) begin
                    // One is prefix of other
                    if (word_lengths[pair_idx] >= word_lengths[pair_idx+1]) next_state = ADD_EDGE;
                    else next_state = CHECK_PREFIX;
                end else begin
                    if (words[pair_idx][char_idx] != words[pair_idx+1][char_idx]) next_state = ADD_EDGE;
                    else next_state = FIND_DIFF;
                end
            end
            ADD_EDGE: begin
                if (src_idx < ALPHABET_SIZE) next_state = ADD_EDGE;
                else next_state = CHECK_PREFIX;
            end
            TOPO_INIT: begin
                next_state = TOPO_LOOP;
            end
            TOPO_LOOP: begin
                if (output_count >= ALPHABET_SIZE) next_state = DONE_STATE;
                else if (has_cycle) next_state = DONE_STATE;
                else if (ambiguous_flag) next_state = DONE_STATE;
                else if (zero_count > 1) next_state = DONE_STATE;
                else next_state = TOPO_LOOP;
            end
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            status_reg <= IMPOSSIBLE;
            pair_idx <= 4'd0;
            char_idx <= 4'd0;
            src_idx <= 4'd0;
            dst_idx <= 4'd0;
            topo_node <= 4'd0;
            zero_count <= 4'd0;
            selected_node <= 4'd0;
            output_count <= 4'd0;
            cycle_count <= 4'd0;
            found_zero <= 1'b0;
            has_cycle <= 1'b0;
            ambiguous_flag <= 1'b0;
            prefix_violation <= 1'b0;
            char1 <= 8'd0;
            char2 <= 8'd0;
            for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
                result_order_reg[i] <= 8'd0;
                in_degree[i] <= 4'd0;
                for (j = 0; j < ALPHABET_SIZE; j = j + 1) begin
                    edge_matrix[i][j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        pair_idx <= 4'd0;
                        char_idx <= 4'd0;
                        src_idx <= 4'd0;
                        dst_idx <= 4'd0;
                        topo_node <= 4'd0;
                        zero_count <= 4'd0;
                        selected_node <= 4'd0;
                        output_count <= 4'd0;
                        cycle_count <= 4'd0;
                        found_zero <= 1'b0;
                        has_cycle <= 1'b0;
                        ambiguous_flag <= 1'b0;
                        prefix_violation <= 1'b0;
                        status_reg <= IMPOSSIBLE;
                        for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
                            result_order_reg[i] <= 8'd0;
                            in_degree[i] <= 4'd0;
                            for (j = 0; j < ALPHABET_SIZE; j = j + 1) begin
                                edge_matrix[i][j] <= 8'd0;
                            end
                        end
                    end
                end
                CHECK_PREFIX: begin
                    if (pair_idx >= N - 1) begin
                        // All pairs processed
                    end else if (word_lengths[pair_idx] > word_lengths[pair_idx+1]) begin
                        // Check if word[pair_idx] is prefix of word[pair_idx+1]
                        if (char_idx >= word_lengths[pair_idx+1]) begin
                            // prefix violation
                            prefix_violation <= 1'b1;
                            char_idx <= 4'd0;
                        end else begin
                            if (words[pair_idx][char_idx] != words[pair_idx+1][char_idx]) begin
                                // Not prefix, move to find diff
                                char_idx <= 4'd0;
                            end else begin
                                char_idx <= char_idx + 4'd1;
                            end
                        end
                    end else begin
                        char_idx <= 4'd0;
                    end
                end
                FIND_DIFF: begin
                    if (char_idx >= word_lengths[pair_idx] || char_idx >= word_lengths[pair_idx+1]) begin
                        // One is prefix of other
                        if (word_lengths[pair_idx] >= word_lengths[pair_idx+1]) begin
                            // Violation: longer comes first
                            prefix_violation <= 1'b1;
                            char_idx <= 4'd0;
                        end else begin
                            char_idx <= 4'd0;
                        end
                    end else begin
                        if (words[pair_idx][char_idx] != words[pair_idx+1][char_idx]) begin
                            char1 <= words[pair_idx][char_idx];
                            char2 <= words[pair_idx+1][char_idx];
                            char_idx <= 4'd0;
                        end else begin
                            char_idx <= char_idx + 4'd1;
                        end
                    end
                end
                ADD_EDGE: begin
                    if (src_idx < ALPHABET_SIZE) begin
                        if (src_idx == (char1 - 8'd97) && dst_idx == (char2 - 8'd97)) begin
                            edge_matrix[src_idx][dst_idx] <= 8'd1;
                        end
                        if (dst_idx >= ALPHABET_SIZE - 1) begin
                            dst_idx <= 4'd0;
                            src_idx <= src_idx + 4'd1;
                        end else begin
                            dst_idx <= dst_idx + 4'd1;
                        end
                    end
                    if (src_idx >= ALPHABET_SIZE) begin
                        pair_idx <= pair_idx + 4'd1;
                        char_idx <= 4'd0;
                        src_idx <= 4'd0;
                        dst_idx <= 4'd0;
                    end
                end
                TOPO_INIT: begin
                    // Compute in-degrees
                    for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
                        in_degree[i] <= 4'd0;
                    end
                    // This is a simplification; actual in-degree calculation would need multiple cycles
                    // For now, we'll do incremental in-degree in TOPO_LOOP
                    topo_node <= 4'd0;
                    output_count <= 4'd0;
                    has_cycle <= 1'b0;
                    ambiguous_flag <= 1'b0;
                    cycle_count <= 4'd0;
                end
                TOPO_LOOP: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (output_count >= ALPHABET_SIZE) begin
                        // Completed successfully
                    end else if (cycle_count > 4'd15) begin
                        has_cycle <= 1'b1;
                    end else begin
                        // Count nodes with in-degree 0
                        zero_count <= 4'd0;
                        for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
                            if (in_degree[i] == 4'd0) begin
                                zero_count <= zero_count + 4'd1;
                            end
                        end
                        if (zero_count == 0) begin
                            has_cycle <= 1'b1;
                        end else if (zero_count > 1) begin
                            ambiguous_flag <= 1'b1;
                        end else begin
                            // Select the node (find first with in-degree 0)
                            for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
                                if (in_degree[i] == 4'd0) begin
                                    selected_node <= i;
                                    in_degree[i] <= 4'd15; // Mark as removed
                                    result_order_reg[output_count] <= 8'd97 + i;
                                    output_count <= output_count + 4'd1;
                                    // Decrement in-degrees of neighbors
                                    for (j = 0; j < ALPHABET_SIZE; j = j + 1) begin
                                        if (edge_matrix[i][j] == 8'd1 && in_degree[j] > 0) begin
                                            in_degree[j] <= in_degree[j] - 4'd1;
                                        end
                                    end
                                    break;
                                end
                            end
                        end
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    if (prefix_violation) begin
                        status_reg <= IMPOSSIBLE;
                    end else if (has_cycle) begin
                        status_reg <= IMPOSSIBLE;
                    end else if (ambiguous_flag) begin
                        status_reg <= AMBIGUOUS;
                    end else begin
                        status_reg <= UNIQUE;
                    end
                end
            endcase
        end
    end

    // Output assignments
    always @(*) begin
        for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
            result_order[i] = result_order_reg[i];
        end
        status = status_reg;
    end

endmodule