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

    localparam IDLE = 3'b000;
    localparam BUILD_ADJ = 3'b001;
    localparam FIND_AC = 3'b010;
    localparam ASSIGN_LETTERS = 3'b011;
    localparam VERIFY = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state, next_state;
    reg [N-1:0][N-1:0] adj;
    reg [7:0] [N-1:0] letter;
    reg [7:0] captured_num_edges;
    reg [7:0] edge_idx;
    reg [2:0] i_find, j_find;
    reg [3:0] found_i, found_j;
    reg invalid;
    reg [3:0] k_index;
    reg [3:0] i_verif, j_verif;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            adj <= 0;
            letter <= 0;
            captured_num_edges <=0;
            edge_idx <=0;
            i_find <=0;
            j_find <=0;
            found_i <=0;
            found_j <=0;
            invalid <=0;
            k_index <=0;
            i_verif <=0;
            j_verif <=0;
        end else begin
            case (state)
                IDLE: begin
                    if (start ==1) begin
                        next_state = BUILD_ADJ;
                        captured_num_edges <= num_edges;
                    end else begin
                        next_state = IDLE;
                    end
                end
                BUILD_ADJ: begin
                    if (edge_idx < captured_num_edges) begin
                        reg [3:0] u, v;
                        u = edge_u[edge_idx];
                        v = edge_v[edge_idx];
                        adj[u][v] <= 1'b1;
                        adj[v][u] <= 1'b1;
                        edge_idx <= edge_idx +1;
                        next_state <= BUILD_ADJ;
                    end else begin
                        next_state <= FIND_AC;
                        edge_idx <=0;
                    end
                end
                FIND_AC: begin
                    if (i_find < N-1) begin
                        if (j_find < N) begin
                            if (adj[i_find][j_find] ==0) begin
                                found_i <= i_find;
                                found_j <= j_find;
                                letter[found_i] <= 8'b01100001;
                                letter[found_j] <= 8'b01100011;
                                next_state <= ASSIGN_LETTERS;
                            end else begin
                                j_find <= j_find +1;
                            end
                        end else begin
                            i_find <= i_find +1;
                            if (i_find < N-1) begin
                                j_find <= i_find +1;
                            end else begin
                                next_state <= ASSIGN_LETTERS;
                            end
                        end
                    end else begin
                        next_state <= ASSIGN_LETTERS;
                    end
                end
                ASSIGN_LETTERS: begin
                    if (k_index < N) begin
                        if (k_index != found_i && k_index != found_j) begin
                            reg [3:0] connected_a, connected_c;
                            connected_a = adj[k_index][found_i];
                            connected_c = adj[k_index][found_j];
                            if (!connected_a && !connected_c) begin
                                invalid <=1;
                                next_state <= DONE;
                            end else if (connected_a && !connected_c) begin
                                letter[k_index] <= 8'b01100001;
                            end else if (!connected_a && connected_c) begin
                                letter[k_index] <= 8'b01100011;
                            end else if (connected_a && connected_c) begin
                                letter[k_index] <= 8'b01100010;
                            end
                        end
                        k_index <= k_index +1;
                        next_state <= ASSIGN_LETTERS;
                    end else begin
                        next_state <= VERIFY;
                        k_index <=0;
                    end
                end
                VERIFY: begin
                    if (i_verif < N-1) begin
                        if (j_verif < N) begin
                            reg [7:0] char_i, char_j;
                            char_i = letter[i_verif];
                            char_j = letter[j_verif];
                            if (adj[i_verif][j_verif] ==1) begin
                                if ((char_i == 8'b01100001 && char_j == 8'b01100011) ||
                                    (char_i == 8'b01100011 && char_j == 8'b01100001)) begin
                                    invalid <=1;
                                    next_state <= DONE;
                                end
                            end else begin
                                if (char_i == char_j) begin
                                    invalid <=1;
                                    next_state <= DONE;
                                end else if (((char_i ==8'b01100001 && char_j ==8'b01100010) ||
                                            (char_i ==8'b01100010 && char_j ==8'b01100001) ||
                                            (char_i ==8'b01100010 && char_j ==8'b01100011) ||
                                            (char_i ==8'b01100011 && char_j ==8'b01100010))) begin
                                    invalid <=1;
                                    next_state <= DONE;
                                end
                            end
                            j_verif <= j_verif +1;
                            next_state <= VERIFY;
                        end else begin
                            i_verif <= i_verif +1;
                            if (i_verif < N-1) begin
                                j_verif <= i_verif +1;
                            end else begin
                                j_verif <= N;
                            end
                            next_state <= VERIFY;
                        end
                    end else begin
                        invalid <=0;
                        next_state <= DONE;
                    end
                end
                DONE: begin
                    valid <= !invalid;
                    result_string <= letter;
                    next_state <= DONE;
                end
            endcase
            state <= next_state;
        end
    end

    always @(*) begin
        valid = 0;
        result_string = 0;
    end

endmodule