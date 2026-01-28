module island_courier(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [15:0] adj,
    input wire [63:0] L,
    output reg [15:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ORIG = 3'd1;
    localparam [2:0] ITER_START = 3'd2;
    localparam [2:0] ITER_BODY = 3'd3;
    localparam [2:0] EVALUATE = 3'd4;
    localparam [2:0] UPDATE = 3'd5;
    localparam [2:0] DONE = 3'd6;

    reg [2:0] state;
    reg [1:0] i_idx, j_idx;
    reg [15:0] orig_adj_reg;
    reg [15:0] new_adj;
    reg [15:0] min_result;
    reg [15:0] candidate;
    reg strong_flag;

    function automatic is_strongly_connected;
        input [15:0] adj_mat;
        input [1:0] num_nodes;
        integer i, j, k;
        reg [15:0] reach;
        begin
            reach = adj_mat;
            for (k = 0; k < 4; k = k + 1) begin
                if (k < num_nodes) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < num_nodes) begin
                            for (j = 0; j < 4; j = j + 1) begin
                                if (j < num_nodes) begin
                                    reach[i*4 + j] = reach[i*4 + j] | (reach[i*4 + k] & reach[k*4 + j]);
                                end
                            end
                        end
                    end
                end
            end
            is_strongly_connected = 1'b1;
            for (i = 0; i < 4; i = i + 1) begin
                if (i < num_nodes) begin
                    for (j = 0; j < 4; j = j + 1) begin
                        if (j < num_nodes) begin
                            if (reach[i*4 + j] != 1'b1) begin
                                is_strongly_connected = 1'b0;
                            end
                        end
                    end
                end
            end
        end
    endfunction

    function automatic [15:0] get_L;
        input [63:0] L_mat;
        input [1:0] i, j;
        begin
            get_L = L_mat[16*(i*4 + j) +: 16];
        end
    endfunction

    always @(*) begin
        new_adj = orig_adj_reg;
        if (state == ITER_BODY || state == EVALUATE) begin
            if (i_idx < n && j_idx < n) begin
                new_adj[i_idx*4 + j_idx] = 1'b1;
                new_adj[j_idx*4 + i_idx] = 1'b1;
            end
        end
        strong_flag = is_strongly_connected(new_adj, n);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            min_result <= 16'd65535;
            i_idx <= 2'd0;
            j_idx <= 2'd0;
            orig_adj_reg <= 16'd0;
            candidate <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        orig_adj_reg <= adj;
                        state <= CHECK_ORIG;
                        min_result <= 16'd65535;
                    end
                end

                CHECK_ORIG: begin
                    if (strong_flag) begin
                        result <= 16'd0;
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        state <= ITER_START;
                    end
                end

                ITER_START: begin
                    i_idx <= 2'd0;
                    j_idx <= 2'd1;
                    state <= ITER_BODY;
                end

                ITER_BODY: begin
                    if (i_idx < n && j_idx < n) begin
                        state <= EVALUATE;
                    end else begin
                        if (j_idx < n - 1) begin
                            j_idx <= j_idx + 1;
                        end else begin
                            j_idx <= 2'd0;
                            if (i_idx < n - 1) begin
                                i_idx <= i_idx + 1;
                            end else begin
                                state <= DONE;
                            end
                        end
                    end
                end

                EVALUATE: begin
                    if (strong_flag) begin
                        candidate <= get_L(L, i_idx, j_idx);
                        state <= UPDATE;
                    end else begin
                        state <= ITER_BODY;
                        if (j_idx < n - 1) begin
                            j_idx <= j_idx + 1;
                        end else begin
                            j_idx <= 2'd0;
                            if (i_idx < n - 1) begin
                                i_idx <= i_idx + 1;
                            end else begin
                                state <= DONE;
                            end
                        end
                    end
                end

                UPDATE: begin
                    if (candidate < min_result) begin
                        min_result <= candidate;
                    end
                    state <= ITER_BODY;
                    if (j_idx < n - 1) begin
                        j_idx <= j_idx + 1;
                    end else begin
                        j_idx <= 2'd0;
                        if (i_idx < n - 1) begin
                            i_idx <= i_idx + 1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    if (min_result != 16'd65535) begin
                        result <= min_result;
                    end else begin
                        result <= 16'd65535;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule