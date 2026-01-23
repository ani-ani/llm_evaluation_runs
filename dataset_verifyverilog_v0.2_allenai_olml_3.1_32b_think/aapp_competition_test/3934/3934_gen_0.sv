module tree_checker (
    input [3:0] n,
    input [3:0] num_edges,
    input [5:0] edge_u [15:0],
    input [5:0] edge_v [15:0],
    output result
);

    generate
    for (i=0; i<16; i++) begin: gen_valid
        assign valid_i_<i> = num_edges > i;
    end
    endgenerate

    generate
    for (j=0; j<16; j++) begin: gen_degree
        wire [4:0] sum;
        assign sum = 0;
        generate
        for (i=0; i<16; i++) begin: gen_i
            sum = sum + (valid_i_<i> ? ( (edge_u[i][3:0] == j) + (edge_v[i][3:0] == j) ) :0);
        end
        endgenerate
        assign degrees[j] = sum;
    end
    endgenerate

    wire has_degree_2 = 0;
    generate
    for (j=0; j<16; j++) begin
        has_degree_2 = has_degree_2 | (degrees[j] == 2);
    end
    endgenerate

    assign result = (n == 2) ? 1'b1 : ( (n > 2) ? ( !has_degree_2 ? 1'b1 : 1'b0 ) : 1'b0 );

    endmodule