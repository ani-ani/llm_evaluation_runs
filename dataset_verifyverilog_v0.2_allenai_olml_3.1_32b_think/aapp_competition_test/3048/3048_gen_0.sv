module optimal_paths_length2 (
    input [15:0] adj_matrix [0:15],
    input [3:0] num_nodes,
    output reg [15:0] result
);

always @(*) begin
    result = 0;
    reg [15:0] degree_i;
    integer i, j;
    for (i=0; i < 16; i = i +1) begin
        if (i < num_nodes) begin
            degree_i = 0;
            for (j=0; j <16; j = j +1) begin
                degree_i = degree_i + (adj_matrix[i] >> j) & 1;
            end
            result = result + degree_i * (degree_i -1);
        end
    end
end
endmodule