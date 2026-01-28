module MinMagicPathFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] node_magic [0:7],
    input wire [7:0] edges [0:7],
    input wire [3:0] num_nodes,
    output reg [63:0] result_numer,
    output reg [63:0] result_denom,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] GENERATE_PATHS = 3'd2;
    localparam [2:0] COMPUTE_BEST = 3'd3;
    localparam [2:0] REDUCE_FRACTION = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;

    // Path generation variables
    reg [2:0] current_node;
    reg [7:0] path [0:7];
    reg [3:0] path_length;
    reg [7:0] path_index;
    reg [7:0] node_index;
    reg [7:0] visited [0:7];

    // Best path tracking
    reg [63:0] best_product;
    reg [3:0] best_length;
    reg [63:0] current_product;
    reg [3:0] current_length;

    // Fraction reduction
    reg [63:0] gcd_result;
    reg [63:0] a_temp, b_temp;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_node <= 3'd0;
            path_length <= 4'd0;
            path_index <= 8'd0;
            node_index <= 8'd0;
            best_product <= 64'd0;
            best_length <= 4'd0;
            current_product <= 64'd0;
            current_length <= 4'd0;
            gcd_result <= 64'd0;
            a_temp <= 64'd0;
            b_temp <= 64'd0;
            result_numer <= 64'd0;
            result_denom <= 64'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize path and visited arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                path[i] <= 8'd0;
                visited[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize path generation
                    path_length <= 4'd0;
                    path_index <= 8'd0;
                    node_index <= 8'd0;
                    best_product <= 64'd0;
                    best_length <= 4'd0;
                    current_product <= 64'd0;
                    current_length <= 4'd0;

                    // Reset visited and path arrays
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        visited[i] <= 8'd0;
                        path[i] <= 8'd0;
                    end

                    next_state <= GENERATE_PATHS;
                end

                GENERATE_PATHS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Generate all possible paths using BFS-like approach
                    if (path_length == 4'd0) begin
                        // Start new path from node 0 to num_nodes-1
                        if (node_index < num_nodes) begin
                            path[0] <= node_index;
                            visited[node_index] <= 8'd1;
                            current_product <= {32'd0, node_magic[node_index]};
                            current_length <= 4'd1;
                            node_index <= node_index + 8'd1;
                            path_length <= 4'd1;
                            path_index <= 8'd1;
                        end else begin
                            // All paths generated
                            next_state <= COMPUTE_BEST;
                        end
                    end else begin
                        // Extend current path
                        reg found;
                        integer i;
                        found = 1'b0;
                        for (i = 0; i < num_nodes; i = i + 1) begin
                            if (!found && !visited[i] && edges[path[path_length-4'd1]][i]) begin
                                // Found next node
                                path[path_length] <= i;
                                visited[i] <= 8'd1;
                                current_product <= current_product * {32'd0, node_magic[i]};
                                current_length <= current_length + 4'd1;
                                path_length <= path_length + 4'd1;
                                path_index <= path_index + 8'd1;
                                found = 1'b1;
                            end
                        end

                        if (!found) begin
                            // Backtrack
                            if (path_length > 4'd1) begin
                                path_length <= path_length - 4'd1;
                                visited[path[path_length]] <= 8'd0;
                                current_length <= current_length - 4'd1;
                                current_product <= current_product / {32'd0, node_magic[path[path_length]]};
                            end else begin
                                // Reset for next path
                                path_length <= 4'd0;
                                visited[path[0]] <= 8'd0;
                            end
                        end

                        // Check if we should move to next state
                        if (path_index >= (1 << num_nodes) || cycle_count >= MAX_CYCLES) begin
                            next_state <= COMPUTE_BEST;
                        end
                    end
                end

                COMPUTE_BEST: begin
                    // Compare all paths to find the one with minimal magic
                    // Magic = product / length, compare as product * best_length vs best_product * length
                    if (best_length == 4'd0 || 
                        (current_product * best_length) < (best_product * current_length)) begin
                        best_product <= current_product;
                        best_length <= current_length;
                    end

                    // Check if we've processed all paths
                    if (path_index >= (1 << num_nodes) || cycle_count >= MAX_CYCLES) begin
                        next_state <= REDUCE_FRACTION;
                    end else begin
                        next_state <= GENERATE_PATHS;
                    end
                end

                REDUCE_FRACTION: begin
                    // Compute GCD of best_product and best_length
                    a_temp <= best_product;
                    b_temp <= best_length;

                    // Euclidean algorithm
                    while (b_temp != 64'd0) begin
                        if (a_temp > b_temp) begin
                            a_temp <= a_temp - b_temp;
                        end else begin
                            b_temp <= b_temp - a_temp;
                        end
                    end

                    gcd_result <= a_temp;

                    // Reduce fraction
                    if (gcd_result != 64'd0) begin
                        result_numer <= best_product / gcd_result;
                        result_denom <= best_length / gcd_result;
                    end else begin
                        result_numer <= best_product;
                        result_denom <= best_length;
                    end

                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule