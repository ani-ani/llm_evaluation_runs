module color_code_finder(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] palette_valid,
    input [3:0] palette_count,
    output reg done,
    output reg result_valid,
    output reg [15:0] result_data,
    output reg [3:0] result_index,
    output reg impossible
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SEARCH    = 2'd1;
    localparam [1:0] FOUND     = 2'd2;
    localparam [1:0] IMPOSSIBLE = 2'd3;

    reg [1:0] state, next_state;

    // Internal registers
    reg [15:0] visited [0:15];
    reg [15:0] path [0:15];
    reg [3:0] depth;
    reg [3:0] backtrack_count;
    reg [3:0] current_index;
    reg [15:0] current_value;
    reg [3:0] hamming_dist;
    reg [3:0] i;
    reg [3:0] j;
    reg [15:0] xor_result;
    reg [3:0] pop_count;

    // Hamming distance computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hamming_dist <= 4'd0;
            pop_count <= 4'd0;
            xor_result <= 16'd0;
        end else begin
            // Compute Hamming distance between path[depth] and current_value
            xor_result <= path[depth] ^ current_value;
            pop_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (xor_result[i])
                    pop_count <= pop_count + 4'd1;
            end
            hamming_dist <= pop_count;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            result_data <= 16'd0;
            result_index <= 4'd0;
            impossible <= 1'b0;
            depth <= 4'd0;
            backtrack_count <= 4'd0;
            current_index <= 4'd0;
            current_value <= 16'd0;
            
            // Initialize path and visited arrays
            for (i = 0; i < 16; i = i + 1) begin
                path[i] <= 16'd0;
                visited[i] <= 16'd0;
            end
            
            // Set initial path[0] to 0
            path[0] <= 16'd0;
            visited[0] <= 16'd1;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    impossible <= 1'b0;
                    depth <= 4'd0;
                    backtrack_count <= 4'd0;
                    current_index <= 4'd0;
                    current_value <= 16'd0;
                    
                    // Reset path and visited
                    for (i = 0; i < 16; i = i + 1) begin
                        path[i] <= 16'd0;
                        visited[i] <= 16'd0;
                    end
                    
                    // Set initial path[0] to 0
                    path[0] <= 16'd0;
                    visited[0] <= 16'd1;
                    
                    if (start) begin
                        next_state <= SEARCH;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SEARCH: begin
                    result_valid <= 1'b0;
                    
                    // Check if we've found a complete sequence
                    if (depth == (1 << n) - 1) begin
                        next_state <= FOUND;
                    end else begin
                        // Try to find next value
                        current_index <= 4'd0;
                        current_value <= 16'd0;
                        
                        // Search for next value
                        for (i = 0; i < 16; i = i + 1) begin
                            if (!visited[i] && current_value == 16'd0) begin
                                current_value <= i;
                                current_index <= i;
                            end
                        end
                        
                        // Check if current_value is valid
                        if (current_value != 16'd0) begin
                            // Wait for hamming distance computation
                            if (hamming_dist != 4'd0 && palette_valid[hamming_dist]) begin
                                // Valid move
                                visited[current_index] <= 16'd1;
                                path[depth + 1] <= current_value;
                                depth <= depth + 4'd1;
                            end else begin
                                // Try next value
                                current_value <= 16'd0;
                                for (i = current_index + 1; i < 16; i = i + 1) begin
                                    if (!visited[i] && current_value == 16'd0) begin
                                        current_value <= i;
                                        current_index <= i;
                                    end
                                end
                                
                                // If no valid value found, backtrack
                                if (current_value == 16'd0) begin
                                    backtrack_count <= backtrack_count + 4'd1;
                                    
                                    // Check if we've backtracked too much
                                    if (backtrack_count > 16) begin
                                        next_state <= IMPOSSIBLE;
                                    end else begin
                                        // Backtrack
                                        if (depth > 4'd0) begin
                                            visited[path[depth]] <= 16'd0;
                                            depth <= depth - 4'd1;
                                        end else begin
                                            next_state <= IMPOSSIBLE;
                                        end
                                    end
                                end
                            end
                        end else begin
                            // No valid moves, backtrack
                            backtrack_count <= backtrack_count + 4'd1;
                            
                            if (backtrack_count > 16) begin
                                next_state <= IMPOSSIBLE;
                            end else begin
                                if (depth > 4'd0) begin
                                    visited[path[depth]] <= 16'd0;
                                    depth <= depth - 4'd1;
                                end else begin
                                    next_state <= IMPOSSIBLE;
                                end
                            end
                        end
                    end
                end

                FOUND: begin
                    done <= 1'b1;
                    result_valid <= 1'b1;
                    result_data <= path[result_index];
                    result_index <= result_index + 4'd1;
                    
                    if (result_index == (1 << n) - 1) begin
                        next_state <= IDLE;
                        result_index <= 4'd0;
                    end else begin
                        next_state <= FOUND;
                    end
                end

                IMPOSSIBLE: begin
                    done <= 1'b1;
                    impossible <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule