module RhymeChecker(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [19:0] word_a [0:14],
    input [19:0] word_b [0:14],
    input is_eq [0:14],
    output reg done,
    output reg [1:0] result,
    output reg [3:0] status
);

    // State definitions
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] COLLECT = 4'd1;
    localparam [3:0] RHYME   = 4'd2;
    localparam [3:0] UNION   = 4'd3;
    localparam [3:0] CHECK   = 4'd4;
    localparam [3:0] DONE    = 4'd5;

    // Word storage (16 words max)
    reg [19:0] words [0:15];
    reg [3:0] word_count;
    reg [3:0] unique_count;

    // Union-Find structure
    reg [3:0] parent [0:15];
    reg [3:0] rank [0:15];

    // Statement processing
    reg [3:0] stmt_idx;
    reg [3:0] word_idx;
    reg [3:0] rhyme_i;
    reg [3:0] rhyme_j;

    // Rhyme check
    reg [3:0] rhyme_check_i;
    reg [3:0] rhyme_check_j;

    // Contradiction check
    reg contradiction;

    // State register
    reg [3:0] state;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 2'd0;
            status <= 4'd0;
            word_count <= 4'd0;
            unique_count <= 4'd0;
            stmt_idx <= 4'd0;
            word_idx <= 4'd0;
            rhyme_i <= 4'd0;
            rhyme_j <= 4'd0;
            rhyme_check_i <= 4'd0;
            rhyme_check_j <= 4'd0;
            contradiction <= 1'b0;
            
            // Initialize words array
            for (i = 0; i < 16; i = i + 1) begin
                words[i] <= 20'd0;
            end
            
            // Initialize Union-Find
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    status <= IDLE;
                    if (start) begin
                        state <= COLLECT;
                        word_count <= 4'd0;
                        unique_count <= 4'd0;
                        stmt_idx <= 4'd0;
                        word_idx <= 4'd0;
                        contradiction <= 1'b0;
                    end
                end

                COLLECT: begin
                    status <= COLLECT;
                    // Collect unique words
                    if (word_idx < N) begin
                        // Check if word_a is already in words
                        reg found_a;
                        reg [3:0] id_a;
                        found_a = 1'b0;
                        id_a = 4'd0;
                        for (i = 0; i < unique_count; i = i + 1) begin
                            if (words[i] == word_a[word_idx]) begin
                                found_a = 1'b1;
                                id_a = i;
                            end
                        end
                        
                        // Check if word_b is already in words
                        reg found_b;
                        reg [3:0] id_b;
                        found_b = 1'b0;
                        id_b = 4'd0;
                        for (i = 0; i < unique_count; i = i + 1) begin
                            if (words[i] == word_b[word_idx]) begin
                                found_b = 1'b1;
                                id_b = i;
                            end
                        end
                        
                        // Add new words if not found
                        if (!found_a && unique_count < 16) begin
                            words[unique_count] <= word_a[word_idx];
                            id_a = unique_count;
                            unique_count <= unique_count + 4'd1;
                        end
                        
                        if (!found_b && unique_count < 16) begin
                            words[unique_count] <= word_b[word_idx];
                            id_b = unique_count;
                            unique_count <= unique_count + 4'd1;
                        end
                        
                        word_idx <= word_idx + 4'd1;
                    end else begin
                        state <= RHYME;
                        rhyme_i <= 4'd0;
                        rhyme_j <= 4'd1;
                    end
                end

                RHYME: begin
                    status <= RHYME;
                    // Check if words[rhyme_i] and words[rhyme_j] rhyme
                    if (rhyme_j < unique_count) begin
                        reg rhyme;
                        rhyme = 1'b1;
                        
                        // Compare last 3 characters (bits 3:0, 7:4, 11:8)
                        if (words[rhyme_i][3:0] != words[rhyme_j][3:0]) rhyme = 1'b0;
                        if (words[rhyme_i][7:4] != words[rhyme_j][7:4]) rhyme = 1'b0;
                        if (words[rhyme_i][11:8] != words[rhyme_j][11:8]) rhyme = 1'b0;
                        
                        // If they rhyme, union them
                        if (rhyme) begin
                            // Find roots
                            reg [3:0] root_i;
                            reg [3:0] root_j;
                            root_i = find_root(rhyme_i);
                            root_j = find_root(rhyme_j);
                            
                            // Union if different
                            if (root_i != root_j) begin
                                if (rank[root_i] < rank[root_j]) begin
                                    parent[root_i] <= root_j;
                                end else if (rank[root_i] > rank[root_j]) begin
                                    parent[root_j] <= root_i;
                                end else begin
                                    parent[root_j] <= root_i;
                                    rank[root_i] <= rank[root_i] + 4'd1;
                                end
                            end
                        end
                        
                        rhyme_j <= rhyme_j + 4'd1;
                    end else begin
                        rhyme_i <= rhyme_i + 4'd1;
                        if (rhyme_i >= unique_count - 4'd1) begin
                            rhyme_j <= rhyme_i + 4'd1;
                        end
                        
                        if (rhyme_i >= unique_count - 4'd2) begin
                            state <= UNION;
                            stmt_idx <= 4'd0;
                        end
                    end
                end

                UNION: begin
                    status <= UNION;
                    if (stmt_idx < N) begin
                        // Find word IDs
                        reg [3:0] id_a;
                        reg [3:0] id_b;
                        id_a = 4'd0;
                        id_b = 4'd0;
                        
                        for (i = 0; i < unique_count; i = i + 1) begin
                            if (words[i] == word_a[stmt_idx]) id_a = i;
                            if (words[i] == word_b[stmt_idx]) id_b = i;
                        end
                        
                        // Find roots
                        reg [3:0] root_a;
                        reg [3:0] root_b;
                        root_a = find_root(id_a);
                        root_b = find_root(id_b);
                        
                        // Check for contradiction
                        if (root_a == root_b && !is_eq[stmt_idx]) begin
                            contradiction <= 1'b1;
                        end
                        
                        // Union if 'is' statement
                        if (is_eq[stmt_idx] && root_a != root_b) begin
                            if (rank[root_a] < rank[root_b]) begin
                                parent[root_a] <= root_b;
                            end else if (rank[root_a] > rank[root_b]) begin
                                parent[root_b] <= root_a;
                            end else begin
                                parent[root_b] <= root_a;
                                rank[root_a] <= rank[root_a] + 4'd1;
                            end
                        end
                        
                        stmt_idx <= stmt_idx + 4'd1;
                    end else begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    status <= CHECK;
                    // Check for contradictions
                    if (contradiction) begin
                        result <= 2'd0; // "wait what?"
                    end else begin
                        result <= 2'd1; // "yes"
                    end
                    state <= DONE;
                end

                DONE: begin
                    status <= DONE;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Find root with path compression
    function [3:0] find_root(input [3:0] x);
        reg [3:0] root;
        reg [3:0] current;
        reg [3:0] next;
        
        current = x;
        while (parent[current] != current) begin
            current = parent[current];
        end
        root = current;
        
        // Path compression
        current = x;
        while (parent[current] != root) begin
            next = parent[current];
            parent[current] = root;
            current = next;
        end
        
        find_root = root;
    endfunction

endmodule