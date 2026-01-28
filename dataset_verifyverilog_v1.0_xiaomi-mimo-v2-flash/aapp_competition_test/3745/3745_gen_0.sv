module GraphStringReconstructor (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [6:0] m,
    input [3:0] u_arr [0:15],
    input [3:0] v_arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] BUILD_MATRIX = 3'd1;
    localparam [2:0] SEARCH       = 3'd2;
    localparam [2:0] VALIDATE     = 3'd3;
    localparam [2:0] FINISH       = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // Control signals
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;

    // Adjacency matrix: 16x16 bit matrix
    // Flattened for Icarus compatibility: index = i * 16 + j
    reg [255:0] adj_matrix;

    // Search registers
    reg [3:0] current_vertex;
    reg [3:0] attempt;
    reg [3:0] best_idx;
    reg solution_found;
    reg [31:0] temp_assignment;

    // Helper wires for validation
    wire [3:0] edge_u;
    wire [3:0] edge_v;
    wire [1:0] char_u;
    wire [1:0] char_v;
    wire edge_exists;
    wire chars_match;
    wire [1:0] diff;

    // Adjacency lookup helper
    wire [15:0] row_start;
    wire [15:0] matrix_idx;

    // Assignments for helper wires
    assign edge_u = u_arr[best_idx];
    assign edge_v = v_arr[best_idx];
    assign char_u = temp_assignment[edge_u*2 +: 2];
    assign char_v = temp_assignment[edge_v*2 +: 2];
    assign diff = (char_u > char_v) ? (char_u - char_v) : (char_v - char_u);
    assign chars_match = (diff == 2'd0) || (diff == 2'd1);
    assign row_start = edge_u << 4; // Multiply by 16
    assign matrix_idx = row_start + edge_v;
    assign edge_exists = adj_matrix[matrix_idx];

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 7'd0;
            adj_matrix <= 256'd0;
            current_vertex <= 4'd0;
            attempt <= 4'd0;
            best_idx <= 4'd0;
            solution_found <= 1'b0;
            temp_assignment <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                    adj_matrix <= 256'd0;
                    solution_found <= 1'b0;
                    current_vertex <= 4'd0;
                    attempt <= 4'd0;
                    best_idx <= 4'd0;
                    temp_assignment <= 32'd0;
                    if (start) begin
                        state <= BUILD_MATRIX;
                    end
                end

                BUILD_MATRIX: begin
                    if (best_idx < m) begin
                        // Set matrix[ u ][ v ] and matrix[ v ][ u ]
                        // u_arr and v_arr contain vertex indices
                        // row = u * 16 + v
                        // row2 = v * 16 + u
                        adj_matrix[(u_arr[best_idx] << 4) + v_arr[best_idx]] <= 1'b1;
                        adj_matrix[(v_arr[best_idx] << 4) + u_arr[best_idx]] <= 1'b1;
                        best_idx <= best_idx + 4'd1;
                    end else begin
                        best_idx <= 4'd0;
                        current_vertex <= 4'd0;
                        // Initialize assignment with 'a' (0) for all vertices
                        temp_assignment <= 32'd0;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (current_vertex < n) begin
                        // Try assigning a value to current_vertex
                        if (attempt < 3'd3) begin
                            // Check constraint with all previous vertices (0 to current_vertex - 1)
                            if (best_idx < current_vertex) begin
                                // Check vertex best_idx against current_vertex
                                // Use temp wires for readability
                                if (adj_matrix[(best_idx << 4) + current_vertex]) begin
                                    // Edge exists, check char match
                                    if (attempt == temp_assignment[best_idx*2 +: 2]) begin
                                        // Same char -> Valid
                                        best_idx <= best_idx + 4'd1;
                                    end else begin
                                        // Different char, check adjacency
                                        if (attempt > temp_assignment[best_idx*2 +: 2]) begin
                                            if (attempt - temp_assignment[best_idx*2 +: 2] > 2'd1) begin
                                                // Invalid: difference > 1
                                                attempt <= attempt + 4'd1;
                                                best_idx <= 4'd0;
                                            end else begin
                                                // Valid: difference is 1
                                                best_idx <= best_idx + 4'd1;
                                            end
                                        end else begin
                                            if (temp_assignment[best_idx*2 +: 2] - attempt > 2'd1) begin
                                                // Invalid: difference > 1
                                                attempt <= attempt + 4'd1;
                                                best_idx <= 4'd0;
                                            end else begin
                                                // Valid: difference is 1
                                                best_idx <= best_idx + 4'd1;
                                            end
                                        end
                                    end
                                end else begin
                                    // No edge exists, chars must be different
                                    if (attempt == temp_assignment[best_idx*2 +: 2]) begin
                                        // Invalid: chars must be different if no edge
                                        attempt <= attempt + 4'd1;
                                        best_idx <= 4'd0;
                                    end else begin
                                        // Valid so far
                                        best_idx <= best_idx + 4'd1;
                                    end
                                end
                            end else begin
                                // All previous vertices satisfied, commit assignment
                                temp_assignment[current_vertex*2 +: 2] <= attempt;
                                current_vertex <= current_vertex + 4'd1;
                                attempt <= 4'd0;
                                best_idx <= 4'd0;
                            end
                        end else begin
                            // Backtrack: current vertex has no valid assignment
                            if (current_vertex > 4'd0) begin
                                current_vertex <= current_vertex - 4'd1;
                                attempt <= temp_assignment[current_vertex*2 +: 2] + 4'd1;
                                temp_assignment[current_vertex*2 +: 2] <= 4'd0; // Clear for clarity, overwritten later
                                best_idx <= 4'd0;
                            end else begin
                                // No solution found
                                solution_found <= 1'b0;
                                state <= FINISH;
                            end
                        end
                    end else begin
                        // All vertices assigned successfully
                        solution_found <= 1'b1;
                        state <= FINISH;
                    end
                    
                    // Cycle counter
                    cycle_count <= cycle_count + 7'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                         state <= FINISH;
                         solution_found <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (solution_found) begin
                        result[31] <= 1'b1;
                        result[30:2*N] <= 14'd0; // Zero out unused upper bits
                        result[2*N-1:0] <= temp_assignment[2*N-1:0];
                    end else begin
                        result <= 32'd0;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule