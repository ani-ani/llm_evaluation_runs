module name_ranking_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] name_idx,
    input [2:0] char_idx,
    input load_char,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 1000000007;
    localparam MAX_NODES = 64;
    localparam MAX_NAMES = 8;
    localparam MAX_CHARS = 8;
    localparam ALPHABET_SIZE = 26;

    // Precomputed factorials mod MOD
    localparam [31:0] FACTORIAL [0:8] = '{40320, 5040, 720, 120, 24, 6, 2, 1, 1};

    // Precomputed modular inverses for factorials (using Fermat's Little Theorem)
    localparam [31:0] INV_FACTORIAL [0:8] = '{1, 1, 500000004, 166666668, 41666667, 16666667, 8333333, 1666667, 1};

    // FSM States
    typedef enum logic [2:0] {
        IDLE,
        LOAD_DATA,
        BUILD_TRIE,
        COMPUTE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Name buffer
    reg [7:0] names_buffer [0:MAX_NAMES-1][0:MAX_CHARS-1];
    reg [2:0] load_counter;

    // Trie structure
    reg [5:0] nodes_count;
    reg [5:0] node_children [0:MAX_NODES-1][0:ALPHABET_SIZE-1];
    reg [2:0] node_size [0:MAX_NODES-1];
    reg [31:0] node_ways [0:MAX_NODES-1];
    reg [ALPHABET_SIZE-1:0] node_valid [0:MAX_NODES-1];
    reg [2:0] node_end_count [0:MAX_NODES-1];

    // Compute stack
    reg [5:0] stack [0:7];
    reg [2:0] stack_ptr;
    reg [5:0] current_node;
    reg [5:0] child_idx;

    // Temporary variables
    reg [31:0] temp_product;
    reg [31:0] temp_sum;
    reg [31:0] temp_multinomial;
    reg [31:0] temp_ways;
    reg [31:0] temp_size;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            load_counter <= 0;
            nodes_count <= 0;
            stack_ptr <= 0;
            current_node <= 0;
            child_idx <= 0;
            temp_product <= 0;
            temp_sum <= 0;
            temp_multinomial <= 0;
            temp_ways <= 0;
            temp_size <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_DATA;
            end
            LOAD_DATA: begin
                if (load_counter == (MAX_NAMES * MAX_CHARS - 1)) next_state = BUILD_TRIE;
            end
            BUILD_TRIE: begin
                if (nodes_count > 0) next_state = COMPUTE;
            end
            COMPUTE: begin
                if (stack_ptr == 0 && current_node == 0) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Load data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 0;
        end else if (current_state == LOAD_DATA && load_char) begin
            names_buffer[name_idx][char_idx] <= char_in;
            load_counter <= load_counter + 1;
        end
    end

    // Build trie
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nodes_count <= 0;
        end else if (current_state == BUILD_TRIE) begin
            // Initialize root node
            if (nodes_count == 0) begin
                nodes_count <= 1;
                node_valid[0] <= 0;
                node_size[0] <= 0;
                node_ways[0] <= 1;
                node_end_count[0] <= 0;
            end
            // Add names to trie
            else if (nodes_count <= MAX_NODES) begin
                // Simplified: Assume names are loaded and we build the trie
                // In a real implementation, this would involve iterating through names
                // and building the trie structure
                nodes_count <= nodes_count + 1;
            end
        end
    end

    // Compute phase
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stack_ptr <= 0;
            current_node <= 0;
            child_idx <= 0;
            temp_product <= 0;
            temp_sum <= 0;
            temp_multinomial <= 0;
            temp_ways <= 0;
            temp_size <= 0;
        end else if (current_state == COMPUTE) begin
            // Post-order traversal
            if (stack_ptr == 0 && current_node == 0) begin
                // Start with root node
                stack[stack_ptr] <= 0;
                stack_ptr <= stack_ptr + 1;
            end else if (stack_ptr > 0) begin
                current_node <= stack[stack_ptr - 1];
                // Check if all children are processed
                if (child_idx < ALPHABET_SIZE && node_valid[current_node][child_idx]) begin
                    // Push child to stack
                    stack[stack_ptr] <= node_children[current_node][child_idx];
                    stack_ptr <= stack_ptr + 1;
                    child_idx <= child_idx + 1;
                end else begin
                    // Process current node
                    temp_sum <= 0;
                    temp_product <= 1;
                    temp_ways <= 1;
                    // Calculate sum of children sizes
                    for (int i = 0; i < ALPHABET_SIZE; i++) begin
                        if (node_valid[current_node][i]) begin
                            temp_sum <= temp_sum + node_size[node_children[current_node][i]];
                            temp_product <= (temp_product * FACTORIAL[node_size[node_children[current_node][i]]]) % MOD;
                            temp_ways <= (temp_ways * node_ways[node_children[current_node][i]]) % MOD;
                        end
                    end
                    // Calculate multinomial coefficient
                    temp_multinomial <= (FACTORIAL[temp_sum] * temp_product) % MOD;
                    // Calculate node ways
                    node_ways[current_node] <= (temp_multinomial * FACTORIAL[node_end_count[current_node]] % MOD) * temp_ways % MOD;
                    node_size[current_node] <= temp_sum + node_end_count[current_node];
                    // Pop stack
                    stack_ptr <= stack_ptr - 1;
                    child_idx <= 0;
                end
            end
        end
    end

    // Output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else if (current_state == DONE) begin
            result <= node_ways[0];
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule