module graph_validator #(parameter N=8, parameter MAX_EDGES=28) (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_edges,
    input [MAX_EDGES-1:0][3:0] edge_u,
    input [MAX_EDGES-1:0][3:0] edge_v,
    output reg valid,
    output reg [N-1:0][7:0] result_string
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        BUILD_ADJ,
        FIND_AC,
        ASSIGN_LETTERS,
        VERIFY,
        DONE
    } state_t;

    state_t state, next_state;

    // Adjacency matrix
    reg [N-1:0][N-1:0] adj;

    // Vertex assignments
    reg [N-1:0][1:0] vertex_letter; // 00: 'a', 01: 'b', 10: 'c', 11: unassigned

    // Counters
    reg [7:0] edge_counter;
    reg [7:0] vertex_counter;
    reg [7:0] verify_counter;

    // Temporary variables
    reg [7:0] i, j, k;
    reg found_ac;
    reg [1:0] char_u, char_v;

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            for (int idx = 0; idx < N; idx++) begin
                result_string[idx] <= 8'h00;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            edge_counter <= 0;
            vertex_counter <= 0;
            verify_counter <= 0;
            found_ac <= 0;
            for (int idx = 0; idx < N; idx++) begin
                for (int jdx = 0; jdx < N; jdx++) begin
                    adj[idx][jdx] <= 0;
                end
                vertex_letter[idx] <= 2'b11; // Unassigned
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= BUILD_ADJ;
                        edge_counter <= 0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                BUILD_ADJ: begin
                    if (edge_counter < num_edges) begin
                        adj[edge_u[edge_counter]][edge_v[edge_counter]] <= 1;
                        adj[edge_v[edge_counter]][edge_u[edge_counter]] <= 1;
                        edge_counter <= edge_counter + 1;
                    end else begin
                        next_state <= FIND_AC;
                        i <= 0;
                        j <= 0;
                        found_ac <= 0;
                    end
                end

                FIND_AC: begin
                    if (!found_ac) begin
                        if (i < N) begin
                            if (j < N) begin
                                if (i != j && !adj[i][j]) begin
                                    found_ac <= 1;
                                    vertex_letter[i] <= 2'b00; // 'a'
                                    vertex_letter[j] <= 2'b10; // 'c'
                                end
                                j <= j + 1;
                            end else begin
                                i <= i + 1;
                                j <= 0;
                            end
                        end else begin
                            // No non-connected pair found, all 'a'
                            for (int idx = 0; idx < N; idx++) begin
                                vertex_letter[idx] <= 2'b00; // 'a'
                            end
                            found_ac <= 1;
                        end
                    end else begin
                        next_state <= ASSIGN_LETTERS;
                        vertex_counter <= 0;
                    end
                end

                ASSIGN_LETTERS: begin
                    if (vertex_counter < N) begin
                        if (vertex_letter[vertex_counter] == 2'b11) begin
                            // Unassigned vertex
                            if (adj[vertex_counter][i] && !adj[vertex_counter][j]) begin
                                vertex_letter[vertex_counter] <= 2'b00; // 'a'
                            end else if (!adj[vertex_counter][i] && adj[vertex_counter][j]) begin
                                vertex_letter[vertex_counter] <= 2'b10; // 'c'
                            end else if (adj[vertex_counter][i] && adj[vertex_counter][j]) begin
                                vertex_letter[vertex_counter] <= 2'b01; // 'b'
                            end else begin
                                // Impossible case
                                valid <= 0;
                                next_state <= IDLE;
                            end
                        end
                        vertex_counter <= vertex_counter + 1;
                    end else begin
                        next_state <= VERIFY;
                        verify_counter <= 0;
                    end
                end

                VERIFY: begin
                    if (verify_counter < num_edges) begin
                        char_u = vertex_letter[edge_u[verify_counter]];
                        char_v = vertex_letter[edge_v[verify_counter]];
                        if ((char_u == 2'b00 && char_v == 2'b10) || (char_u == 2'b10 && char_v == 2'b00)) begin
                            // 'a' and 'c' are not adjacent
                            valid <= 0;
                            next_state <= IDLE;
                        end else if (char_u == 2'b11 || char_v == 2'b11) begin
                            // Unassigned vertex
                            valid <= 0;
                            next_state <= IDLE;
                        end else begin
                            verify_counter <= verify_counter + 1;
                        end
                    end else begin
                        // Check non-edges
                        for (int idx = 0; idx < N; idx++) begin
                            for (int jdx = idx + 1; jdx < N; jdx++) begin
                                if (!adj[idx][jdx]) begin
                                    char_u = vertex_letter[idx];
                                    char_v = vertex_letter[jdx];
                                    if ((char_u == 2'b00 && char_v == 2'b00) || 
                                        (char_u == 2'b01 && char_v == 2'b01) || 
                                        (char_u == 2'b10 && char_v == 2'b10) || 
                                        (char_u == 2'b00 && char_v == 2'b01) || 
                                        (char_u == 2'b01 && char_v == 2'b00) || 
                                        (char_u == 2'b01 && char_v == 2'b10) || 
                                        (char_u == 2'b10 && char_v == 2'b01)) begin
                                        valid <= 0;
                                        next_state <= IDLE;
                                    end
                                end
                            end
                        end
                        valid <= 1;
                        next_state <= DONE;
                    end
                end

                DONE: begin
                    // Convert vertex_letter to result_string
                    for (int idx = 0; idx < N; idx++) begin
                        case (vertex_letter[idx])
                            2'b00: result_string[idx] <= 8'h61; // 'a'
                            2'b01: result_string[idx] <= 8'h62; // 'b'
                            2'b10: result_string[idx] <= 8'h63; // 'c'
                            default: result_string[idx] <= 8'h00;
                        endcase
                    end
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule