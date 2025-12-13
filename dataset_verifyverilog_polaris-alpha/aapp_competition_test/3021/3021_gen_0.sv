module lex_order_solver(
    input  clk,
    input  rst_n,
    input  start,
    input  [2:0] L,
    input  [2:0] N,
    input  [191:0] words,
    output reg done,
    output reg [1:0] status,
    output reg [23:0] order
);

    // Parameters
    localparam MAX_CHARS = 8; // alphabet size max
    localparam MAX_WORDS = 8;
    localparam WORD_BITS = 8 * 3; // 8 chars * 3 bits

    // Internal registers
    reg [2:0] L_q;              // latched L
    reg [2:0] N_q;              // latched N
    reg [191:0] words_q;        // latched words

    // adjacency matrix: edge i->j
    reg [7:0] adj [7:0];
    reg [7:0] next_adj [7:0];

    // indegree per node
    reg [3:0] indeg     [7:0];
    reg [3:0] next_indeg[7:0];

    // topological order result (3 bits * 8)
    reg [2:0] topo_order [7:0];
    reg [2:0] next_topo_order [7:0];

    // queue / zero in-degree tracking
    reg [7:0] used;         // 1 if char index is within 0..L_q
    reg [7:0] next_used;
    reg [7:0] zero_mask;    // current zero in-degree mask
    reg [7:0] next_zero_mask;

    // count of processed nodes
    reg [3:0] processed_cnt;
    reg [3:0] next_processed_cnt;

    // cycle/ambiguity flags
    reg impossible;
    reg next_impossible;
    reg ambiguous;
    reg next_ambiguous;

    // FSM states
    localparam S_IDLE  = 2'd0;
    localparam S_EDGE  = 2'd1;
    localparam S_SORT  = 2'd2;
    localparam S_DONE  = 2'd3;

    reg [1:0] state, next_state;

    // Helper: extract character from packed words_q
    function [2:0] get_char;
        input [191:0] w;
        input [2:0] word_idx;  // 0..7
        input [2:0] char_idx;  // 0..7
        integer base;
    begin
        // words: word0 at LSB, each word 24 bits, each char 3 bits, char0 LSB
        base = (word_idx * WORD_BITS) + (char_idx * 3);
        get_char = w[base +: 3];
    end
    endfunction

    integer i, j;

    // Combinational next-state logic
    always @* begin
        // Defaults
        next_state          = state;
        next_impossible     = impossible;
        next_ambiguous      = ambiguous;
        next_processed_cnt  = processed_cnt;
        next_zero_mask      = zero_mask;
        next_used           = used;

        for (i = 0; i < MAX_CHARS; i = i + 1) begin
            next_indeg[i]      = indeg[i];
            next_topo_order[i] = topo_order[i];
            for (j = 0; j < MAX_CHARS; j = j + 1) begin
                next_adj[i][j] = adj[i][j];
            end
        end

        case (state)
            S_IDLE: begin
                if (start) begin
                    // Move to edge-detection stage next cycle
                    next_state      = S_EDGE;
                end
            end

            S_EDGE: begin
                // Build adjacency and indegree based on latched inputs
                // Initialize structures
                for (i = 0; i < MAX_CHARS; i = i + 1) begin
                    next_used[i]      = (i <= L_q) ? 1'b1 : 1'b0;
                    next_indeg[i]     = 4'd0;
                    next_topo_order[i]= 3'd0;
                    for (j = 0; j < MAX_CHARS; j = j + 1) begin
                        next_adj[i][j] = 1'b0;
                    end
                end
                next_impossible    = 1'b0;
                next_ambiguous     = 1'b0;
                next_processed_cnt = 4'd0;

                // Compare adjacent words in parallel style (unrolled loops)
                // For each pair (k, k+1)
                for (i = 0; i < MAX_WORDS-1; i = i + 1) begin : PAIR_LOOP
                    reg [2:0] c1;
                    reg [2:0] c2;
                    reg diff_found;
                    integer p;
                    diff_found = 1'b0;

                    if (i < N_q-1) begin
                        // scan up to 8 characters
                        for (p = 0; p < 8; p = p + 1) begin
                            if (!diff_found) begin
                                c1 = get_char(words_q, i[2:0], p[2:0]);
                                c2 = get_char(words_q, (i+1)[2:0], p[2:0]);
                                if (c1 != c2) begin
                                    diff_found = 1'b1;
                                    // add edge c1 -> c2 if not exists
                                    if (!next_adj[c1][c2]) begin
                                        next_adj[c1][c2]  = 1'b1;
                                        next_indeg[c2]    = next_indeg[c2] + 1'b1;
                                    end
                                end
                            end
                        end
                        // If no diff found, no extra rule; prefix case allowed as per problem
                    end
                end

                // Initialize zero in-degree mask for nodes in alphabet
                next_zero_mask = 8'd0;
                for (i = 0; i <= 7; i = i + 1) begin
                    if (next_used[i] && (next_indeg[i] == 4'd0)) begin
                        next_zero_mask[i] = 1'b1;
                    end
                end

                next_state = S_SORT;
            end

            S_SORT: begin
                // One iteration of Kahn's algorithm per cycle
                reg [7:0] candidates;
                integer pick_idx;
                integer out_pos;
                reg found_any;
                reg multiple;

                candidates = zero_mask & used;

                // Check if any candidate exists
                found_any = |candidates;
                // Check if multiple candidates -> ambiguous path
                multiple  = (candidates != 0) && (candidates & (candidates - 1)) != 0;

                if (!found_any) begin
                    // No zero-indegree nodes
                    if (processed_cnt != (L_q + 1)) begin
                        // cycle detected
                        next_impossible = 1'b1;
                    end
                    next_state = S_DONE;
                end else begin
                    // Select lowest-index candidate deterministically
                    pick_idx = 0;
                    for (i = 0; i < MAX_CHARS; i = i + 1) begin
                        if (candidates[i] && (pick_idx == 0) && (i == 0)) begin
                            pick_idx = i;
                        end else if (candidates[i] && (pick_idx == 0) && (i != 0)) begin
                            pick_idx = i;
                        end
                    end

                    // If there are multiple candidates (besides chosen one), mark ambiguous
                    if (multiple)
                        next_ambiguous = 1'b1;

                    // Append pick_idx to topo_order at processed_cnt position
                    out_pos = processed_cnt;
                    if (out_pos < 8)
                        next_topo_order[out_pos] = pick_idx[2:0];

                    // Remove node from zero_mask/used
                    next_zero_mask[pick_idx] = 1'b0;
                    next_used[pick_idx]      = 1'b0;

                    // Decrement indegree of neighbors
                    for (j = 0; j < MAX_CHARS; j = j + 1) begin
                        if (adj[pick_idx][j]) begin
                            if (next_indeg[j] > 0)
                                next_indeg[j] = next_indeg[j] - 1'b1;
                            // If becomes zero and still considered in alphabet, add to zero_mask
                            if (next_indeg[j] == 0 && next_used[j]) begin
                                next_zero_mask[j] = 1'b1;
                            end
                        end
                    end

                    // Increment processed count
                    next_processed_cnt = processed_cnt + 1'b1;

                    // If all alphabet nodes processed, go done next
                    if (next_processed_cnt == (L_q + 1)) begin
                        next_state = S_DONE;
                    end
                end
            end

            S_DONE: begin
                // Wait one cycle with done high in sequential block, then go idle
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            L_q             <= 3'd0;
            N_q             <= 3'd0;
            words_q         <= {192{1'b0}};
            done            <= 1'b0;
            status          <= 2'b00;
            order           <= 24'd0;
            impossible      <= 1'b0;
            ambiguous       <= 1'b0;
            processed_cnt   <= 4'd0;
            zero_mask       <= 8'd0;
            used            <= 8'd0;
            for (i = 0; i < MAX_CHARS; i = i + 1) begin
                indeg[i]       <= 4'd0;
                topo_order[i]  <= 3'd0;
                for (j = 0; j < MAX_CHARS; j = j + 1) begin
                    adj[i][j]  <= 1'b0;
                end
            end
        end else begin
            state         <= next_state;
            impossible    <= next_impossible;
            ambiguous     <= next_ambiguous;
            processed_cnt <= next_processed_cnt;
            zero_mask     <= next_zero_mask;
            used          <= next_used;

            for (i = 0; i < MAX_CHARS; i = i + 1) begin
                indeg[i]      <= next_indeg[i];
                topo_order[i] <= next_topo_order[i];
                for (j = 0; j < MAX_CHARS; j = j + 1) begin
                    adj[i][j] <= next_adj[i][j];
                end
            end

            done <= 1'b0; // default, may be set in S_DONE below

            case (state)
                S_IDLE: begin
                    if (start) begin
                        // Latch inputs at start
                        L_q     <= L;
                        N_q     <= N;
                        words_q <= words;
                    end
                end

                S_EDGE: begin
                    // adjacency/indeg/zero_mask computed in combinational
                end

                S_SORT: begin
                    // iterative topological sort
                end

                S_DONE: begin
                    // Generate outputs based on computation
                    done <= 1'b1;

                    // Determine status
                    if (impossible) begin
                        status <= 2'b01; // IMPOSSIBLE
                    end else if (ambiguous) begin
                        status <= 2'b10; // AMBIGUOUS
                    end else begin
                        status <= 2'b00; // UNIQUE
                    end

                    // Build order output (8 chars * 3 bits)
                    // Left-pad when alphabet < 8: place determined letters at LSB side
                    // Here: topo_order[0..L_q] in found order, pad leading zeros if needed
                    reg [23:0] tmp_order;
                    integer k;
                    tmp_order = 24'd0;

                    // Place characters from index 0..L_q into least-significant slots
                    for (k = 0; k < 8; k = k + 1) begin
                        if (k <= L_q) begin
                            tmp_order[(k*3) +: 3] = topo_order[k];
                        end else begin
                            tmp_order[(k*3) +: 3] = 3'd0; // pad with 'a'
                        end
                    end

                    order <= tmp_order;
                end

                default: begin
                end
            endcase
        end
    end

endmodule