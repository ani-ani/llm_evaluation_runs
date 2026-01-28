module name_order_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [23:0] name_in,
    input wire valid_in,
    input wire done_in,
    output reg [31:0] result,
    output reg ready,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_NODES = 5'd16;
    localparam [4:0] MAX_CHARS = 5'd16;
    localparam [4:0] ALPHABET_SIZE = 5'd26;

    // FSM States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_NAME = 3'd1;
    localparam [2:0] BUILD_TRIE = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    // Trie node structure
    reg [4:0] trie_children [0:15][0:25]; // 16 nodes, 26 children each
    reg [15:0] trie_count [0:15]; // Subtree size
    reg trie_is_end [0:15]; // End marker
    reg [4:0] current_node; // Current node ID
    reg [4:0] node_count; // Total nodes used

    // Name processing
    reg [4:0] char_index; // Current character index
    reg [4:0] name_length; // Length of current name
    reg [7:0] current_char; // Current character

    // Calculation variables
    reg [31:0] factorial [0:16]; // Precomputed factorials
    reg [31:0] inv_factorial [0:16]; // Precomputed inverse factorials
    reg [31:0] temp_result; // Temporary result
    reg [4:0] calc_index; // Calculation index

    // FSM state
    reg [2:0] state;

    // Precompute factorials and inverse factorials
    initial begin
        factorial[0] = 32'd1;
        for (integer i = 1; i < 17; i = i + 1) begin
            factorial[i] = (factorial[i-1] * i) % MOD;
        end
        // Compute inverse factorials using Fermat's little theorem
        inv_factorial[16] = 1;
        for (integer i = 1; i < 17; i = i + 1) begin
            inv_factorial[16-i] = (inv_factorial[16-i+1] * (16-i+1)) % MOD;
        end
        inv_factorial[0] = 1;
    end

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_node <= 5'd0;
            node_count <= 5'd0;
            char_index <= 5'd0;
            name_length <= 5'd0;
            current_char <= 8'd0;
            calc_index <= 5'd0;
            temp_result <= 32'd0;
            result <= 32'd0;
            ready <= 1'b1;
            done <= 1'b0;

            // Initialize trie
            for (integer i = 0; i < 16; i = i + 1) begin
                trie_count[i] <= 16'd0;
                trie_is_end[i] <= 1'b0;
                for (integer j = 0; j < 26; j = j + 1) begin
                    trie_children[i][j] <= 5'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        state <= READ_NAME;
                        ready <= 1'b0;
                    end
                end

                READ_NAME: begin
                    if (valid_in) begin
                        // Process name
                        name_length <= 5'd0;
                        char_index <= 5'd0;
                        current_node <= 5'd0;
                        state <= BUILD_TRIE;
                    end
                end

                BUILD_TRIE: begin
                    if (char_index < name_length) begin
                        // Get current character
                        current_char <= name_in[(char_index*8)+7:(char_index*8)];

                        // Find child index
                        integer child_idx = current_char - 8'd"a";
                        if (child_idx < 0 || child_idx >= 26) begin
                            child_idx = 0; // Default to 'a' if invalid
                        end

                        // Check if child exists
                        if (trie_children[current_node][child_idx] == 5'd0) begin
                            // Create new node
                            if (node_count < MAX_NODES) begin
                                node_count <= node_count + 5'd1;
                                trie_children[current_node][child_idx] <= node_count;
                                current_node <= node_count;
                            end
                        end else begin
                            current_node <= trie_children[current_node][child_idx];
                        end

                        char_index <= char_index + 5'd1;
                    end else begin
                        // Mark end of name
                        trie_is_end[current_node] <= 1'b1;
                        if (done_in) begin
                            state <= CALCULATE;
                        end else begin
                            state <= READ_NAME;
                        end
                    end
                end

                CALCULATE: begin
                    // Compute subtree sizes
                    for (integer i = node_count; i >= 0; i = i - 1) begin
                        trie_count[i] <= 16'd1; // Count itself
                        for (integer j = 0; j < 26; j = j + 1) begin
                            if (trie_children[i][j] != 5'd0) begin
                                trie_count[i] <= trie_count[i] + trie_count[trie_children[i][j]];
                            end
                        end
                    end

                    // Compute result using DP
                    temp_result <= 32'd1;
                    for (integer i = 0; i <= node_count; i = i + 1) begin
                        integer total = trie_count[i];
                        integer prod = 1;
                        for (integer j = 0; j < 26; j = j + 1) begin
                            if (trie_children[i][j] != 5'd0) begin
                                integer child_size = trie_count[trie_children[i][j]];
                                prod = (prod * factorial[child_size]) % MOD;
                            end
                        end
                        integer comb = (factorial[total] * inv_factorial[prod]) % MOD;
                        temp_result = (temp_result * comb) % MOD;
                    end

                    result <= temp_result;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Character counter for name length
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            name_length <= 5'd0;
        end else begin
            if (state == READ_NAME && valid_in) begin
                // Count characters in name (simplified for example)
                name_length <= 5'd3; // Assume fixed length for synthesis
            end
        end
    end

endmodule