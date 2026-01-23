module graph_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] row0,
    input [7:0] row1,
    input [7:0] row2,
    input [7:0] row3,
    input [7:0] row4,
    input [7:0] row5,
    input [7:0] row6,
    input [7:0] row7,
    output reg done,
    output reg valid,
    output reg [15:0] result
);

    // State declarations
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] LATCH_INPUTS   = 4'd1;
    localparam [3:0] CHECK_COMPLETE = 4'd2;
    localparam [3:0] FIND_NONEDGE   = 4'd3;
    localparam [3:0] ASSIGN_LETTERS = 4'd4;
    localparam [3:0] VERIFY         = 4'd5;
    localparam [3:0] VERIFY_LOOP    = 4'd6;
    localparam [3:0] VERIFY_CHECK   = 4'd7;
    localparam [3:0] DONE_STATE     = 4'd8;

    // Vertex letter encoding
    localparam [1:0] LETTER_A = 2'b00;
    localparam [1:0] LETTER_B = 2'b01;
    localparam [1:0] LETTER_C = 2'b10;

    reg [3:0] state, next_state;
    reg [2:0] n_reg;
    reg [7:0] adj_matrix [0:7];
    reg [1:0] assignment [0:7];
    reg [2:0] i, j, k;
    reg [2:0] u, v;
    reg is_complete;
    reg found_nonedge;
    reg verify_fail;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 16'd0;
            n_reg <= 3'd0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                adj_matrix[idx] <= 8'd0;
                assignment[idx] <= 2'b00;
            end
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            u <= 3'd0;
            v <= 3'd0;
            is_complete <= 1'b0;
            found_nonedge <= 1'b0;
            verify_fail <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    result <= 16'd0;
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 3'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LATCH_INPUTS;
                    end
                end

                LATCH_INPUTS: begin
                    n_reg <= n;
                    adj_matrix[0] <= row0;
                    adj_matrix[1] <= row1;
                    adj_matrix[2] <= row2;
                    adj_matrix[3] <= row3;
                    adj_matrix[4] <= row4;
                    adj_matrix[5] <= row5;
                    adj_matrix[6] <= row6;
                    adj_matrix[7] <= row7;
                    i <= 3'd0;
                    j <= 3'd0;
                    is_complete <= 1'b1;
                    state <= CHECK_COMPLETE;
                end

                CHECK_COMPLETE: begin
                    if (i < n_reg) begin
                        if (j < n_reg) begin
                            if (i == j) begin
                                // Skip diagonal
                                j <= j + 3'd1;
                            end else begin
                                if (!adj_matrix[i][j]) begin
                                    is_complete <= 1'b0;
                                end
                                j <= j + 3'd1;
                            end
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        if (is_complete) begin
                            // Complete graph: all vertices can be 'a'
                            for (idx = 0; idx < 8; idx = idx + 1) begin
                                assignment[idx] <= LETTER_A;
                            end
                            state <= DONE_STATE;
                            valid <= 1'b1;
                        end else begin
                            i <= 3'd0;
                            j <= 3'd1;
                            found_nonedge <= 1'b0;
                            state <= FIND_NONEDGE;
                        end
                    end
                end

                FIND_NONEDGE: begin
                    if (i < n_reg) begin
                        if (j < n_reg) begin
                            if (i == j) begin
                                j <= j + 3'd1;
                            end else begin
                                if (!adj_matrix[i][j]) begin
                                    u <= i;
                                    v <= j;
                                    found_nonedge <= 1'b1;
                                    i <= n_reg; // Break loop
                                end else begin
                                    j <= j + 3'd1;
                                end
                            end
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        if (!found_nonedge) begin
                            // Should not happen for !is_complete
                            valid <= 1'b0;
                            state <= DONE_STATE;
                        end else begin
                            // Initialize all to 'b'
                            for (idx = 0; idx < 8; idx = idx + 1) begin
                                assignment[idx] <= LETTER_B;
                            end
                            // Assign u='a', v='c'
                            assignment[u] <= LETTER_A;
                            assignment[v] <= LETTER_C;
                            i <= 3'd0;
                            state <= ASSIGN_LETTERS;
                        end
                    end
                end

                ASSIGN_LETTERS: begin
                    if (i < n_reg) begin
                        if (i != u && i != v) begin
                            if (adj_matrix[i][u]) begin
                                assignment[i] <= LETTER_A;
                            end else if (adj_matrix[i][v]) begin
                                assignment[i] <= LETTER_C;
                            end
                            // Keep 'b' if adjacent to neither (or both)
                        end
                        i <= i + 3'd1;
                    end else begin
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd1;
                        verify_fail <= 1'b0;
                        state <= VERIFY;
                    end
                end

                VERIFY: begin
                    if (i < n_reg) begin
                        if (k < n_reg) begin
                            if (i == k) begin
                                k <= k + 3'd1;
                            end else begin
                                // Check edge existence vs required letter pair
                                if (adj_matrix[i][k]) begin
                                    // Edge exists, must be (A,B) or (B,C)
                                    if (!((assignment[i] == LETTER_A && assignment[k] == LETTER_B) ||
                                          (assignment[i] == LETTER_B && assignment[k] == LETTER_A) ||
                                          (assignment[i] == LETTER_B && assignment[k] == LETTER_C) ||
                                          (assignment[i] == LETTER_C && assignment[k] == LETTER_B))) begin
                                        verify_fail <= 1'b1;
                                    end
                                end else begin
                                    // No edge, must be (A,C)
                                    if (!((assignment[i] == LETTER_A && assignment[k] == LETTER_C) ||
                                          (assignment[i] == LETTER_C && assignment[k] == LETTER_A))) begin
                                        verify_fail <= 1'b1;
                                    end
                                end
                                k <= k + 3'd1;
                            end
                        end else begin
                            k <= 3'd1;
                            i <= i + 3'd1;
                        end
                    end else begin
                        if (verify_fail) begin
                            valid <= 1'b0;
                        end else begin
                            valid <= 1'b1;
                            // Pack result
                            result <= {
                                assignment[7], assignment[6],
                                assignment[5], assignment[4],
                                assignment[3], assignment[2],
                                assignment[1], assignment[0]
                            };
                        end
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