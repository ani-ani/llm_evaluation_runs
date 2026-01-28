module max_operations(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [31:0] arr [0:15],
    input wire [3:0] pairs_i [0:15],
    input wire [3:0] pairs_j [0:15],
    output reg [15:0] result,
    output reg done
);

    // States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FACTORING = 4'd1;
    localparam [3:0] BUILD_GRAPH = 4'd2;
    localparam [3:0] MATCHING = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;

    // Internal registers
    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Prime factorization
    reg [5:0] current_num_idx;
    reg [31:0] current_num;
    reg [5:0] prime_idx;
    reg [15:0] prime;
    reg [5:0] factor_count;
    reg [5:0] factors [0:63];
    reg [5:0] factor_prime [0:63];
    reg [5:0] factor_node [0:63];

    // Graph construction
    reg [5:0] left_node_count;
    reg [5:0] right_node_count;
    reg [5:0] left_nodes [0:31];
    reg [5:0] right_nodes [0:31];
    reg [5:0] left_node_prime [0:31];
    reg [5:0] right_node_prime [0:31];
    reg [5:0] left_node_arr_idx [0:31];
    reg [5:0] right_node_arr_idx [0:31];
    reg [5:0] edge_count;
    reg [5:0] edges_i [0:255];
    reg [5:0] edges_j [0:255];

    // Matching
    reg [5:0] left_match [0:31];
    reg [5:0] right_match [0:31];
    reg [63:0] visited;
    reg [5:0] current_left;
    reg [5:0] current_right;
    reg found_augmenting;

    // Predefined primes (first 64 primes)
    localparam [15:0] primes [0:63] = '{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311};

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_num_idx <= 6'd0;
            current_num <= 32'd0;
            prime_idx <= 6'd0;
            prime <= 16'd0;
            factor_count <= 6'd0;
            left_node_count <= 6'd0;
            right_node_count <= 6'd0;
            edge_count <= 6'd0;
            current_left <= 6'd0;
            current_right <= 6'd0;
            found_augmenting <= 1'b0;
            visited <= 64'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                factors[i] <= 6'd0;
                factor_prime[i] <= 6'd0;
                factor_node[i] <= 6'd0;
            end
            for (i = 0; i < 32; i = i + 1) begin
                left_nodes[i] <= 6'd0;
                right_nodes[i] <= 6'd0;
                left_node_prime[i] <= 6'd0;
                right_node_prime[i] <= 6'd0;
                left_node_arr_idx[i] <= 6'd0;
                right_node_arr_idx[i] <= 6'd0;
                left_match[i] <= 6'd0;
                right_match[i] <= 6'd0;
            end
            for (i = 0; i < 256; i = i + 1) begin
                edges_i[i] <= 6'd0;
                edges_j[i] <= 6'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= FACTORING;
                        current_num_idx <= 6'd0;
                        current_num <= arr[0];
                        prime_idx <= 6'd0;
                        prime <= primes[0];
                        factor_count <= 6'd0;
                    end
                end

                FACTORING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Factorize current number
                    if (current_num == 32'd0) begin
                        // Move to next number
                        current_num_idx <= current_num_idx + 6'd1;
                        if (current_num_idx < n) begin
                            current_num <= arr[current_num_idx];
                            prime_idx <= 6'd0;
                            prime <= primes[0];
                        end else begin
                            state <= BUILD_GRAPH;
                            left_node_count <= 6'd0;
                            right_node_count <= 6'd0;
                            edge_count <= 6'd0;
                        end
                    end else if (prime * prime > current_num) begin
                        // Remaining is prime
                        if (factor_count < 64) begin
                            factors[factor_count] <= current_num_idx;
                            factor_prime[factor_count] <= current_num;
                            factor_count <= factor_count + 6'd1;
                        end
                        current_num <= 32'd0;
                    end else if (current_num % prime == 32'd0) begin
                        // Found factor
                        if (factor_count < 64) begin
                            factors[factor_count] <= current_num_idx;
                            factor_prime[factor_count] <= prime;
                            factor_count <= factor_count + 6'd1;
                        end
                        current_num <= current_num / prime;
                    end else begin
                        // Try next prime
                        prime_idx <= prime_idx + 6'd1;
                        if (prime_idx < 64) begin
                            prime <= primes[prime_idx];
                        end else begin
                            current_num <= 32'd0;
                        end
                    end
                end

                BUILD_GRAPH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Build left and right nodes
                    if (left_node_count < 32 && right_node_count < 32) begin
                        integer i;
                        for (i = 0; i < factor_count; i = i + 1) begin
                            if (factors[i][0] == 1'b1) begin
                                // Odd index - left node
                                if (left_node_count < 32) begin
                                    left_nodes[left_node_count] <= factor_count;
                                    left_node_prime[left_node_count] <= factor_prime[i];
                                    left_node_arr_idx[left_node_count] <= factors[i];
                                    factor_node[i] <= left_node_count;
                                    left_node_count <= left_node_count + 6'd1;
                                end
                            end else begin
                                // Even index - right node
                                if (right_node_count < 32) begin
                                    right_nodes[right_node_count] <= factor_count;
                                    right_node_prime[right_node_count] <= factor_prime[i];
                                    right_node_arr_idx[right_node_count] <= factors[i];
                                    factor_node[i] <= right_node_count + 6'd32;
                                    right_node_count <= right_node_count + 6'd1;
                                end
                            end
                        end
                        
                        // Build edges
                        for (i = 0; i < left_node_count; i = i + 1) begin
                            integer j;
                            for (j = 0; j < right_node_count; j = j + 1) begin
                                if (left_node_prime[i] == right_node_prime[j]) begin
                                    // Check if pair is good
                                    integer k;
                                    reg is_good;
                                    is_good = 1'b0;
                                    for (k = 0; k < m; k = k + 1) begin
                                        if ((pairs_i[k] == left_node_arr_idx[i] && pairs_j[k] == right_node_arr_idx[j]) ||
                                            (pairs_i[k] == right_node_arr_idx[j] && pairs_j[k] == left_node_arr_idx[i])) begin
                                            is_good = 1'b1;
                                        end
                                    end
                                    
                                    if (is_good && edge_count < 256) begin
                                        edges_i[edge_count] <= i;
                                        edges_j[edge_count] <= j;
                                        edge_count <= edge_count + 6'd1;
                                    end
                                end
                            end
                        end
                        
                        state <= MATCHING;
                        current_left <= 6'd0;
                        found_augmenting <= 1'b0;
                        visited <= 64'd0;
                    end
                end

                MATCHING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Hopcroft-Karp algorithm
                    if (current_left < left_node_count) begin
                        if (!visited[current_left]) begin
                            visited[current_left] <= 1'b1;
                            
                            integer i;
                            for (i = 0; i < edge_count; i = i + 1) begin
                                if (edges_i[i] == current_left) begin
                                    current_right <= edges_j[i];
                                    
                                    if (right_match[current_right] == 6'd0 || found_augmenting) begin
                                        left_match[current_left] <= current_right;
                                        right_match[current_right] <= current_left;
                                        found_augmenting <= 1'b1;
                                    end else begin
                                        current_left <= right_match[current_right];
                                    end
                                end
                            end
                            
                            if (!found_augmenting) begin
                                current_left <= current_left + 6'd1;
                            end
                        end else begin
                            current_left <= current_left + 6'd1;
                        end
                    end else begin
                        // Count matches
                        integer count;
                        count = 16'd0;
                        for (i = 0; i < left_node_count; i = i + 1) begin
                            if (left_match[i] != 6'd0) begin
                                count = count + 16'd1;
                            end
                        end
                        result <= count;
                        state <= DONE_STATE;
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