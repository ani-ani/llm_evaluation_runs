module graph_solver(
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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_COMPLETE = 3'd1;
    localparam [2:0] FIND_NONEDGE = 3'd2;
    localparam [2:0] ASSIGN_LETTERS = 3'd3;
    localparam [2:0] VERIFY = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] adj_matrix [0:7];
    reg [1:0] assignment [0:7];
    reg [7:0] cycle_count;
    reg [2:0] i, j, k;
    reg [7:0] u, v;
    reg is_complete;
    reg found_nonedge;
    reg [7:0] temp_row;
    reg [1:0] temp_letter;
    reg [7:0] max_cycles;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 16'd0;
            cycle_count <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            u <= 8'd0;
            v <= 8'd0;
            is_complete <= 1'b0;
            found_nonedge <= 1'b0;
            temp_row <= 8'd0;
            temp_letter <= 2'd0;
            max_cycles <= 8'd100;
            for (k = 0; k < 8; k = k + 1) begin
                adj_matrix[k] <= 8'd0;
                assignment[k] <= 2'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Latch inputs
                        adj_matrix[0] <= row0;
                        adj_matrix[1] <= row1;
                        adj_matrix[2] <= row2;
                        adj_matrix[3] <= row3;
                        adj_matrix[4] <= row4;
                        adj_matrix[5] <= row5;
                        adj_matrix[6] <= row6;
                        adj_matrix[7] <= row7;
                        next_state <= CHECK_COMPLETE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_COMPLETE: begin
                    cycle_count <= cycle_count + 8'd1;
                    is_complete <= 1'b1;
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = 0; j < n; j = j + 1) begin
                            if (i != j && adj_matrix[i][j] == 1'b0) begin
                                is_complete <= 1'b0;
                            end
                        end
                    end
                    if (is_complete) begin
                        // All 'a'
                        for (i = 0; i < n; i = i + 1) begin
                            assignment[i] <= 2'd0;
                        end
                        next_state <= VERIFY;
                    end else begin
                        next_state <= FIND_NONEDGE;
                    end
                end

                FIND_NONEDGE: begin
                    cycle_count <= cycle_count + 8'd1;
                    found_nonedge <= 1'b0;
                    for (i = 0; i < n && !found_nonedge; i = i + 1) begin
                        for (j = 0; j < n && !found_nonedge; j = j + 1) begin
                            if (i != j && adj_matrix[i][j] == 1'b0) begin
                                u <= i;
                                v <= j;
                                found_nonedge <= 1'b1;
                            end
                        end
                    end
                    if (found_nonedge) begin
                        next_state <= ASSIGN_LETTERS;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                ASSIGN_LETTERS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Assign u='a', v='c'
                    assignment[u] <= 2'd0;
                    assignment[v] <= 2'd2;
                    // Assign other vertices
                    for (k = 0; k < n; k = k + 1) begin
                        if (k != u && k != v) begin
                            if (adj_matrix[k][u] == 1'b1 && adj_matrix[k][v] == 1'b1) begin
                                assignment[k] <= 2'd0; // 'a'
                            end else if (adj_matrix[k][u] == 1'b1 && adj_matrix[k][v] == 1'b0) begin
                                assignment[k] <= 2'd1; // 'b'
                            end else if (adj_matrix[k][u] == 1'b0 && adj_matrix[k][v] == 1'b1) begin
                                assignment[k] <= 2'd1; // 'b'
                            end else begin
                                assignment[k] <= 2'd2; // 'c'
                            end
                        end
                    end
                    next_state <= VERIFY;
                end

                VERIFY: begin
                    cycle_count <= cycle_count + 8'd1;
                    valid <= 1'b1;
                    for (i = 0; i < n && valid; i = i + 1) begin
                        for (j = 0; j < n && valid; j = j + 1) begin
                            if (i != j) begin
                                temp_letter <= {assignment[i], assignment[j]};
                                case (temp_letter)
                                    2'd0: begin // 'a' and 'a'
                                        if (adj_matrix[i][j] != 1'b1) valid <= 1'b0;
                                    end
                                    2'd1: begin // 'a' and 'b'
                                        if (adj_matrix[i][j] != 1'b1) valid <= 1'b0;
                                    end
                                    2'd2: begin // 'a' and 'c'
                                        if (adj_matrix[i][j] != 1'b0) valid <= 1'b0;
                                    end
                                    2'd3: begin // 'b' and 'a'
                                        if (adj_matrix[i][j] != 1'b1) valid <= 1'b0;
                                    end
                                    2'd4: begin // 'b' and 'b'
                                        if (adj_matrix[i][j] != 1'b0) valid <= 1'b0;
                                    end
                                    2'd5: begin // 'b' and 'c'
                                        if (adj_matrix[i][j] != 1'b1) valid <= 1'b0;
                                    end
                                    2'd6: begin // 'c' and 'a'
                                        if (adj_matrix[i][j] != 1'b0) valid <= 1'b0;
                                    end
                                    2'd7: begin // 'c' and 'b'
                                        if (adj_matrix[i][j] != 1'b1) valid <= 1'b0;
                                    end
                                    2'd8: begin // 'c' and 'c'
                                        if (adj_matrix[i][j] != 1'b1) valid <= 1'b0;
                                    end
                                    default: valid <= 1'b0;
                                endcase
                            end
                        end
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Pack result
                    result <= 16'd0;
                    for (i = 0; i < n; i = i + 1) begin
                        result[2*i + 1:2*i] <= assignment[i];
                    end
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule