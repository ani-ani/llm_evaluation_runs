module ConsistencyChecker (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [19:0] word_a [0:14],
    input [19:0] word_b [0:14],
    input [14:0] is_eq,
    output reg done,
    output reg [1:0] result,
    output reg [3:0] status
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COLLECT = 4'd1;
    localparam [3:0] RHYME_CHECK = 4'd2;
    localparam [3:0] UNION_PROCESS = 4'd3;
    localparam [3:0] CHECK_CONTRADICTIONS = 4'd4;
    localparam [3:0] FINISH = 4'd5;
    localparam [3:0] ERROR = 4'd15;

    // FSM state registers
    reg [3:0] state, next_state;
    reg [3:0] counter, next_counter;
    reg [3:0] word_count, next_word_count;
    
    // Word storage (16 unique words, 20-bit each)
    reg [19:0] stored_words [0:15];
    reg word_valid [0:15];
    
    // Rhyme pairs storage (max 240 combinations for 16 words)
    reg [7:0] rhyme_pairs_a [0:239]; // Max 16*15/2 = 120 pairs, doubled for safety
    reg [7:0] rhyme_pairs_b [0:239];
    reg rhyme_valid [0:239];
    reg [7:0] rhyme_count;
    reg [7:0] rhyme_idx;
    
    // Union-Find structure
    reg [3:0] parent [0:15];
    reg [3:0] next_parent [0:15];
    
    // Statement tracking
    reg statement_eq [0:14];
    reg [3:0] stmt_word_a [0:14];
    reg [3:0] stmt_word_b [0:14];
    
    // Temporary registers for computations
    reg [19:0] temp_word_a;
    reg [19:0] temp_word_b;
    reg [7:0] search_idx;
    reg found_a, found_b;
    reg [3:0] id_a, id_b;
    
    // Cycle counter for timeout prevention
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1000;
    
    // Helper variables for loops
    integer i, j;
    
    // Find root with path compression (iterative)
    function automatic [3:0] find_root(input [3:0] node);
        reg [3:0] current;
        reg [3:0] path [0:15];
        reg [3:0] path_len;
        reg [3:0] root;
        reg [3:0] temp;
        integer k;
    begin
        current = node;
        path_len = 0;
        
        // Find root
        while (current != parent[current]) begin
            path[path_len] = current;
            path_len = path_len + 1;
            current = parent[current];
        end
        root = current;
        
        // Path compression
        for (k = 0; k < path_len; k = k + 1) begin
            parent[path[k]] = root;
        end
        
        find_root = root;
    end
    endfunction

    // Check if last 3 characters match (rhyme)
    function automatic [1:0] check_rhyme(input [19:0] word1, input [19:0] word2);
        reg [3:0] char1_0, char1_1, char1_2;
        reg [3:0] char2_0, char2_1, char2_2;
    begin
        // Extract last 3 characters (4-bit each)
        char1_0 = word1[3:0];   // Last char
        char1_1 = word1[7:4];   // Second last
        char1_2 = word1[11:8];  // Third last
        
        char2_0 = word2[3:0];
        char2_1 = word2[7:4];
        char2_2 = word2[11:8];
        
        if (char1_0 == char2_0 && char1_1 == char2_1 && char1_2 == char2_2) begin
            check_rhyme = 2'd1; // Rhyme
        end else begin
            check_rhyme = 2'd0; // Not rhyme
        end
    end
    endfunction

    // Union two nodes
    task union_nodes(input [3:0] a, input [3:0] b);
        reg [3:0] root_a, root_b;
    begin
        root_a = find_root(a);
        root_b = find_root(b);
        if (root_a != root_b) begin
            parent[root_b] = root_a;
        end
    end
    endtask

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            word_count <= 4'd0;
            done <= 1'b0;
            result <= 2'd0;
            status <= 4'd0;
            cycle_count <= 16'd0;
            rhyme_count <= 8'd0;
            rhyme_idx <= 8'd0;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                stored_words[i] <= 20'd0;
                word_valid[i] <= 1'b0;
                parent[i] <= 4'd0;
            end
            
            for (i = 0; i < 240; i = i + 1) begin
                rhyme_pairs_a[i] <= 8'd0;
                rhyme_pairs_b[i] <= 8'd0;
                rhyme_valid[i] <= 1'b0;
            end
            
            for (i = 0; i < 15; i = i + 1) begin
                statement_eq[i] <= 1'b0;
                stmt_word_a[i] <= 4'd0;
                stmt_word_b[i] <= 4'd0;
            end
            
        end else begin
            state <= next_state;
            counter <= next_counter;
            word_count <= next_word_count;
            cycle_count <= cycle_count + 16'd1;
            
            // Update arrays based on state
            case (state)
                COLLECT: begin
                    // Store word A if new
                    if (!found_a && word_count < 16) begin
                        stored_words[word_count] <= temp_word_a;
                        word_valid[word_count] <= 1'b1;
                        word_count <= word_count + 1;
                    end
                    // Store word B if new
                    if (!found_b && word_count < 16) begin
                        stored_words[word_count] <= temp_word_b;
                        word_valid[word_count] <= 1'b1;
                        word_count <= word_count + 1;
                    end
                end
                
                RHYME_CHECK: begin
                    // Store rhyme pair
                    if (counter < word_count) begin
                        for (j = counter + 1; j < word_count; j = j + 1) begin
                            if (rhyme_count < 240 && 
                                check_rhyme(stored_words[counter], stored_words[j]) == 2'd1) begin
                                rhyme_pairs_a[rhyme_count] <= {4'd0, counter};
                                rhyme_pairs_b[rhyme_count] <= {4'd0, j};
                                rhyme_valid[rhyme_count] <= 1'b1;
                                rhyme_count <= rhyme_count + 1;
                            end
                        end
                    end
                end
                
                UNION_PROCESS: begin
                    // Apply union operations
                    if (counter < 15 && counter < N) begin
                        // If words rhyme (already connected), or if statement is "is"
                        // We'll connect them in union phase
                        // Actually, statements define relationships to check
                        // Store the mapping for later checking
                        stmt_word_a[counter] <= id_a;
                        stmt_word_b[counter] <= id_b;
                        statement_eq[counter] <= is_eq[counter];
                    end
                    // Also apply rhyme unions
                    if (rhyme_idx < rhyme_count) begin
                        parent[rhyme_pairs_b[rhyme_idx]] <= rhyme_pairs_a[rhyme_idx];
                    end
                end
                
                CHECK_CONTRADICTIONS: begin
                    // Check for contradictions
                    if (counter < 15 && counter < N) begin
                        if (!statement_eq[counter]) begin
                            // "not" statement - check if same component
                            if (parent[stmt_word_a[counter]] == parent[stmt_word_b[counter]]) begin
                                result <= 2'd0; // wait what?
                            end
                        end else begin
                            // "is" statement - ensure no contradiction
                            if (result != 2'd0) begin
                                result <= 2'd1; // yes (only if no contradiction found)
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (result == 2'd0) begin
                        result <= 2'd0; // wait what?
                    end else begin
                        result <= 2'd1; // yes
                    end
                end
                
                default: begin
                    // No special array updates
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_counter = counter;
        next_word_count = word_count;
        temp_word_a = 20'd0;
        temp_word_b = 20'd0;
        found_a = 1'b0;
        found_b = 1'b0;
        id_a = 4'd0;
        id_b = 4'd0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COLLECT;
                    next_counter = 4'd0;
                    next_word_count = 4'd0;
                    // Reset result for new computation
                end
            end
            
            COLLECT: begin
                if (counter < 15 && counter < N) begin
                    // Process statement counter
                    temp_word_a = word_a[counter];
                    temp_word_b = word_b[counter];
                    
                    // Check if words already exist
                    found_a = 1'b0;
                    found_b = 1'b0;
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        if (word_valid[i]) begin
                            if (stored_words[i] == temp_word_a) begin
                                found_a = 1'b1;
                                id_a = i;
                            end
                            if (stored_words[i] == temp_word_b) begin
                                found_b = 1'b1;
                                id_b = i;
                            end
                        end
                    end
                    
                    // Continue to next statement
                    next_counter = counter + 1;
                end else begin
                    next_state = RHYME_CHECK;
                    next_counter = 4'd0;
                end
            end
            
            RHYME_CHECK: begin
                if (counter + 1 < word_count) begin
                    next_counter = counter + 1;
                end else begin
                    next_state = UNION_PROCESS;
                    next_counter = 4'd0;
                    // Initialize parent pointers (each node points to itself)
                    for (i = 0; i < 16; i = i + 1) begin
                        if (word_valid[i]) begin
                            parent[i] <= i;
                        end
                    end
                end
            end
            
            UNION_PROCESS: begin
                // Apply rhyme unions first
                if (rhyme_idx < rhyme_count) begin
                    // Union the rhyme pair
                    // (Handled in always block)
                    next_state = UNION_PROCESS; // Stay here
                    // Need to increment after processing
                    if (rhyme_idx < rhyme_count) begin
                        // Move to next rhyme after a cycle
                    end
                end else if (counter < 15 && counter < N) begin
                    // Process statements
                    // Find IDs for words in this statement
                    temp_word_a = word_a[counter];
                    temp_word_b = word_b[counter];
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        if (word_valid[i]) begin
                            if (stored_words[i] == temp_word_a) begin
                                id_a = i;
                            end
                            if (stored_words[i] == temp_word_b) begin
                                id_b = i;
                            end
                        end
                    end
                    
                    // If statement is "is", union them
                    if (is_eq[counter]) begin
                        // Union them in next state
                    end
                    
                    next_counter = counter + 1;
                end else begin
                    next_state = CHECK_CONTRADICTIONS;
                    next_counter = 4'd0;
                    // Reset result to yes initially
                    result <= 2'd1;
                end
            end
            
            CHECK_CONTRADICTIONS: begin
                if (counter < 15 && counter < N) begin
                    // Check contradiction for this statement
                    temp_word_a = word_a[counter];
                    temp_word_b = word_b[counter];
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        if (word_valid[i]) begin
                            if (stored_words[i] == temp_word_a) begin
                                id_a = i;
                            end
                            if (stored_words[i] == temp_word_b) begin
                                id_b = i;
                            end
                        end
                    end
                    
                    // Check if same component for "not" statements
                    if (!is_eq[counter]) begin
                        if (parent[id_a] == parent[id_b]) begin
                            // Contradiction found
                            next_state = FINISH;
                            next_counter = 4'd0;
                        end else begin
                            next_counter = counter + 1;
                        end
                    end else begin
                        next_counter = counter + 1;
                    end
                end else begin
                    next_state = FINISH;
                    next_counter = 4'd0;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
                next_counter = 4'd0;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Additional sequential logic for union operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            // Handle union operations that need to be in always block
            if (state == UNION_PROCESS) begin
                // Apply rhyme unions
                if (rhyme_idx < rhyme_count) begin
                    // Perform union on parent array
                    for (i = 0; i < 16; i = i + 1) begin
                        if (word_valid[i]) begin
                            if (i == rhyme_pairs_b[rhyme_idx]) begin
                                // Find root of a and b and connect
                                // This is simplified - actual union-find needs root finding
                                if (rhyme_pairs_a[rhyme_idx] < 16 && rhyme_pairs_b[rhyme_idx] < 16) begin
                                    if (parent[rhyme_pairs_a[rhyme_idx]] != parent[rhyme_pairs_b[rhyme_idx]]) begin
                                        // Connect them
                                        for (j = 0; j < 16; j = j + 1) begin
                                            if (parent[j] == parent[rhyme_pairs_b[rhyme_idx]]) begin
                                                parent[j] <= parent[rhyme_pairs_a[rhyme_idx]];
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    rhyme_idx <= rhyme_idx + 1;
                end
                
                // Apply "is" statement unions
                if (counter < 15 && counter < N && is_eq[counter]) begin
                    temp_word_a = word_a[counter];
                    temp_word_b = word_b[counter];
                    
                    // Find IDs
                    for (i = 0; i < 16; i = i + 1) begin
                        if (word_valid[i]) begin
                            if (stored_words[i] == temp_word_a) begin
                                id_a = i;
                            end
                            if (stored_words[i] == temp_word_b) begin
                                id_b = i;
                            end
                        end
                    end
                    
                    // Union them
                    if (parent[id_a] != parent[id_b]) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            if (parent[i] == parent[id_b]) begin
                                parent[i] <= parent[id_a];
                            end
                        end
                    end
                end
            end
        end
    end

    // Timeout protection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else begin
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                next_state = FINISH;
                result <= 2'd0; // timeout -> wait what?
            end
        end
    end

endmodule