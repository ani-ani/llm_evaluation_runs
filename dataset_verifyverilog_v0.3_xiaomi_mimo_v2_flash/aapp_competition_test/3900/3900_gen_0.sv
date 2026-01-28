module suspect_pair_counter #(
    parameter N_MAX = 10
)(
    input [3:0] n,
    input [3:0] p,
    input [3:0] x0, y0,
    input [3:0] x1, y1,
    input [3:0] x2, y2,
    input [3:0] x3, y3,
    input [3:0] x4, y4,
    input [3:0] x5, y5,
    input [3:0] x6, y6,
    input [3:0] x7, y7,
    input [3:0] x8, y8,
    input [3:0] x9, y9,
    output reg [5:0] result
);

    reg [3:0] deg [0:N_MAX-1];
    reg [3:0] edge_cnt_0 [0:N_MAX-1];
    reg [3:0] edge_cnt_1 [0:N_MAX-1];
    reg [3:0] edge_cnt_2 [0:N_MAX-1];
    reg [3:0] edge_cnt_3 [0:N_MAX-1];
    reg [3:0] edge_cnt_4 [0:N_MAX-1];
    reg [3:0] edge_cnt_5 [0:N_MAX-1];
    reg [3:0] edge_cnt_6 [0:N_MAX-1];
    reg [3:0] edge_cnt_7 [0:N_MAX-1];
    reg [3:0] edge_cnt_8 [0:N_MAX-1];
    reg [3:0] edge_cnt_9 [0:N_MAX-1];

    integer i, j, a, b;
    reg [3:0] x_val, y_val;
    reg [5:0] temp_result;

    always_comb begin
        // Initialize deg and edge_cnt to zero
        for (i = 0; i < N_MAX; i = i + 1) begin
            deg[i] = 4'b0;
            edge_cnt_0[i] = 4'b0;
            edge_cnt_1[i] = 4'b0;
            edge_cnt_2[i] = 4'b0;
            edge_cnt_3[i] = 4'b0;
            edge_cnt_4[i] = 4'b0;
            edge_cnt_5[i] = 4'b0;
            edge_cnt_6[i] = 4'b0;
            edge_cnt_7[i] = 4'b0;
            edge_cnt_8[i] = 4'b0;
            edge_cnt_9[i] = 4'b0;
        end

        // Process each coder
        for (i = 0; i < 10; i = i + 1) begin
            if (i < n) begin
                case (i)
                    0: begin x_val = x0 - 4'd1; y_val = y0 - 4'd1; end
                    1: begin x_val = x1 - 4'd1; y_val = y1 - 4'd1; end
                    2: begin x_val = x2 - 4'd1; y_val = y2 - 4'd1; end
                    3: begin x_val = x3 - 4'd1; y_val = y3 - 4'd1; end
                    4: begin x_val = x4 - 4'd1; y_val = y4 - 4'd1; end
                    5: begin x_val = x5 - 4'd1; y_val = y5 - 4'd1; end
                    6: begin x_val = x6 - 4'd1; y_val = y6 - 4'd1; end
                    7: begin x_val = x7 - 4'd1; y_val = y7 - 4'd1; end
                    8: begin x_val = x8 - 4'd1; y_val = y8 - 4'd1; end
                    9: begin x_val = x9 - 4'd1; y_val = y9 - 4'd1; end
                endcase

                // Update degrees
                deg[x_val] = deg[x_val] + 4'd1;
                deg[y_val] = deg[y_val] + 4'd1;

                // Update edge count for the unordered pair
                if (x_val < y_val) begin
                    edge_cnt_0[x_val] = edge_cnt_0[x_val] + 4'd1;
                end else if (y_val < x_val) begin
                    edge_cnt_0[y_val] = edge_cnt_0[y_val] + 4'd1;
                end
            end
        end

        // Count valid pairs (a,b) with a < b, both < n
        temp_result = 6'b0;
        for (a = 0; a < N_MAX; a = a + 1) begin
            if (a < n) begin
                for (b = a + 1; b < N_MAX; b = b + 1) begin
                    if (b < n) begin
                        logic [5:0] agreement;
                        logic [5:0] edge_val;
                        // Calculate edge count between a and b
                        edge_val = 6'b0;
                        if (a < b) begin
                            edge_val = {2'b0, edge_cnt_0[a]};
                        end else begin
                            edge_val = {2'b0, edge_cnt_0[b]};
                        end
                        agreement = {2'b0, deg[a]} + {2'b0, deg[b]} - edge_val;
                        if (agreement >= {2'b0, p}) begin
                            temp_result = temp_result + 6'd1;
                        end
                    end
                end
            end
        end
        result = temp_result;
    end

endmodule