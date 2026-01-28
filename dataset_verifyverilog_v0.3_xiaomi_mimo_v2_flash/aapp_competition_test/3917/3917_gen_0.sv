module min_distance (
    input [3:0] n,
    input signed [7:0] a0, a1, a2, a3, a4, a5, a6, a7,
    output reg [31:0] result
);
    wire signed [15:0] p [0:8];
    assign p[0] = 0;
    assign p[1] = a0;
    assign p[2] = a0 + a1;
    assign p[3] = a0 + a1 + a2;
    assign p[4] = a0 + a1 + a2 + a3;
    assign p[5] = a0 + a1 + a2 + a3 + a4;
    assign p[6] = a0 + a1 + a2 + a3 + a4 + a5;
    assign p[7] = a0 + a1 + a2 + a3 + a4 + a5 + a6;
    assign p[8] = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;

    wire signed [3:0] dx [1:8][1:8];
    wire signed [15:0] dy [1:8][1:8];
    wire [31:0] dist [1:8][1:8];

    genvar i_gen, j_gen;
    generate
        for (i_gen = 1; i_gen <= 8; i_gen = i_gen + 1) begin : gen_i
            for (j_gen = i_gen + 1; j_gen <= 8; j_gen = j_gen + 1) begin : gen_j
                assign dx[i_gen][j_gen] = i_gen - j_gen;
                assign dy[i_gen][j_gen] = p[i_gen] - p[j_gen];
                assign dist[i_gen][j_gen] = dx[i_gen][j_gen] * dx[i_gen][j_gen] + dy[i_gen][j_gen] * dy[i_gen][j_gen];
            end
        end
    endgenerate

    integer i, j;
    always @(*) begin
        result = 32'hFFFF_FFFF;
        for (i = 1; i <= 8; i = i + 1) begin
            for (j = i + 1; j <= 8; j = j + 1) begin
                if (i <= n && j <= n && dist[i][j] < result)
                    result = dist[i][j];
            end
        end
    end
endmodule