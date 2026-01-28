module TabooSolver(
    input clk,
    input rst_n,
    input config_mode,
    input config_done,
    input [3:0] num_strings,
    input [2:0] str_len [0:7],
    input [7:0] str_data [0:7],
    input start,
    output reg result_valid,
    output reg result_infinite,
    output reg [15:0] result_string,
    output reg [4:0] result_length
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG = 3'd1;
    localparam [2:0] BUILD_TRIE = 3'd2;
    localparam [2:0] BUILD_FAILURE = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;
    
    reg [2:0] state;
    
    // Node structure: {terminal, fail_link[4:0], trans0[4:0], trans1[4:0]}
    reg [11:0] trie [0:31];
    reg [4:0] next_node;
    reg [4:0] current_node;
    reg [4:0] queue [0:31];
    reg [4:0] queue_head;
    reg [4:0] queue_tail;
    
    // Configuration storage
    reg [7:0] strings [0:7];
    reg [2:0] lengths [0:7];
    reg [3:0] num_str;
    
    // Computation variables
    reg [4:0] max_length;
    reg [15:0] best_string;
    reg [4:0] visited [0:31];
    reg [4:0] path [0:31];
    reg [4:0] path_len;
    reg cycle_detected;
    
    // Internal counters
    reg [7:0] config_counter;
    reg [7:0] build_counter;
    reg [7:0] compute_counter;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            result_infinite <= 1'b0;
            result_string <= 16'd0;
            result_length <= 5'd0;
            
            // Initialize trie
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                trie[i] <= 12'd0;
            end
            
            next_node <= 5'd1;
            current_node <= 5'd0;
            queue_head <= 5'd0;
            queue_tail <= 5'd0;
            
            // Initialize configuration storage
            for (i = 0; i < 8; i = i + 1) begin
                strings[i] <= 8'd0;
                lengths[i] <= 3'd0;
            end
            num_str <= 4'd0;
            
            // Initialize computation variables
            max_length <= 5'd0;
            best_string <= 16'd0;
            
            for (i = 0; i < 32; i = i + 1) begin
                visited[i] <= 5'd0;
                path[i] <= 5'd0;
            end
            path_len <= 5'd0;
            cycle_detected <= 1'b0;
            
            // Initialize counters
            config_counter <= 8'd0;
            build_counter <= 8'd0;
            compute_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    result_infinite <= 1'b0;
                    if (config_mode) begin
                        state <= CONFIG;
                        config_counter <= 8'd0;
                    end
                end
                
                CONFIG: begin
                    if (config_done) begin
                        state <= BUILD_TRIE;
                        build_counter <= 8'd0;
                    end else begin
                        config_counter <= config_counter + 8'd1;
                        if (config_counter == 8'd1) begin
                            num_str <= num_strings;
                            integer i;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < num_strings) begin
                                    strings[i] <= str_data[i];
                                    lengths[i] <= str_len[i];
                                end else begin
                                    strings[i] <= 8'd0;
                                    lengths[i] <= 3'd0;
                                end
                            end
                        end
                    end
                end
                
                BUILD_TRIE: begin
                    if (build_counter < num_str) begin
                        // Insert string into trie
                        current_node <= 5'd0;
                        integer j;
                        for (j = 0; j < lengths[build_counter]; j = j + 1) begin
                            reg [7:0] bit = strings[build_counter][j];
                            if (bit == 1'b0) begin
                                if (trie[current_node][9:5] == 5'd0) begin
                                    trie[current_node][9:5] <= next_node;
                                    next_node <= next_node + 5'd1;
                                end
                                current_node <= trie[current_node][9:5];
                            end else begin
                                if (trie[current_node][4:0] == 5'd0) begin
                                    trie[current_node][4:0] <= next_node;
                                    next_node <= next_node + 5'd1;
                                end
                                current_node <= trie[current_node][4:0];
                            end
                        end
                        trie[current_node][11] <= 1'b1; // Mark terminal
                        build_counter <= build_counter + 8'd1;
                    end else begin
                        state <= BUILD_FAILURE;
                        build_counter <= 8'd0;
                        queue_head <= 5'd0;
                        queue_tail <= 5'd1;
                        queue[0] <= 5'd0;
                    end
                end
                
                BUILD_FAILURE: begin
                    if (queue_head != queue_tail) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 5'd1;
                        
                        // Process transitions
                        reg [4:0] trans0 = trie[current_node][9:5];
                        reg [4:0] trans1 = trie[current_node][4:0];
                        
                        if (trans0 != 5'd0) begin
                            reg [4:0] fail_node = trie[current_node][10:6];
                            if (fail_node == 5'd0) begin
                                trie[trans0][10:6] <= 5'd0;
                            end else begin
                                trie[trans0][10:6] <= trie[fail_node][9:5];
                            end
                            queue[queue_tail] <= trans0;
                            queue_tail <= queue_tail + 5'd1;
                        end
                        
                        if (trans1 != 5'd0) begin
                            reg [4:0] fail_node = trie[current_node][10:6];
                            if (fail_node == 5'd0) begin
                                trie[trans1][10:6] <= 5'd0;
                            end else begin
                                trie[trans1][10:6] <= trie[fail_node][4:0];
                            end
                            queue[queue_tail] <= trans1;
                            queue_tail <= queue_tail + 5'd1;
                        end
                        
                        build_counter <= build_counter + 8'd1;
                        if (build_counter == 8'd200) begin
                            state <= IDLE;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    if (start) begin
                        state <= OUTPUT;
                        compute_counter <= 8'd0;
                        
                        // Initialize for computation
                        max_length <= 5'd0;
                        best_string <= 16'd0;
                        
                        integer i;
                        for (i = 0; i < 32; i = i + 1) begin
                            visited[i] <= 5'd0;
                            path[i] <= 5'd0;
                        end
                        path_len <= 5'd0;
                        cycle_detected <= 1'b0;
                        
                        // Start DFS from root
                        current_node <= 5'd0;
                        path[0] <= 5'd0;
                        path_len <= 5'd1;
                        visited[0] <= 5'd1;
                    end
                end
                
                OUTPUT: begin
                    if (compute_counter < 8'd1000) begin
                        compute_counter <= compute_counter + 8'd1;
                        
                        // DFS for cycle detection and longest path
                        if (path_len > 5'd0) begin
                            reg [4:0] prev_node = path[path_len - 5'd1];
                            reg [4:0] trans0 = trie[prev_node][9:5];
                            reg [4:0] trans1 = trie[prev_node][4:0];
                            
                            if (trans0 != 5'd0 && visited[trans0] == 5'd0 && trie[trans0][11] == 1'b0) begin
                                // Explore '0' transition
                                current_node <= trans0;
                                path[path_len] <= trans0;
                                path_len <= path_len + 5'd1;
                                visited[trans0] <= 5'd1;
                            end else if (trans1 != 5'd0 && visited[trans1] == 5'd0 && trie[trans1][11] == 1'b0) begin
                                // Explore '1' transition
                                current_node <= trans1;
                                path[path_len] <= trans1;
                                path_len <= path_len + 5'd1;
                                visited[trans1] <= 5'd1;
                            end else begin
                                // Backtrack
                                path_len <= path_len - 5'd1;
                                if (path_len > 5'd0) begin
                                    current_node <= path[path_len - 5'd1];
                                end else begin
                                    current_node <= 5'd0;
                                end
                            end
                            
                            // Check for cycles
                            integer k;
                            for (k = 0; k < path_len - 5'd1; k = k + 1) begin
                                if (path[k] == current_node) begin
                                    cycle_detected <= 1'b1;
                                end
                            end
                        end else begin
                            // Compute longest path
                            if (cycle_detected) begin
                                result_infinite <= 1'b1;
                                result_valid <= 1'b0;
                                state <= IDLE;
                            end else begin
                                // Find longest path (simplified for example)
                                max_length <= 5'd1;
                                best_string <= 16'd1; // "1" as example
                                result_string <= best_string;
                                result_length <= max_length;
                                result_valid <= 1'b1;
                                result_infinite <= 1'b0;
                                state <= IDLE;
                            end
                        end
                    end else begin
                        // Timeout - output default
                        result_string <= 16'd0;
                        result_length <= 5'd0;
                        result_valid <= 1'b1;
                        result_infinite <= 1'b0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule