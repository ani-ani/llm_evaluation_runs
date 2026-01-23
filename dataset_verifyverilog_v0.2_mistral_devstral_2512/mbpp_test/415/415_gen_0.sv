module max_product_pair (
    input [7:0][15:0] data_in,
    output [15:0] value_a,
    output [15:0] value_b
);

    wire [31:0] products [27:0];
    wire [15:0] pairs_a [27:0];
    wire [15:0] pairs_b [27:0];
    wire [31:0] max_product;
    integer i, j, k;

    // Generate all 28 pairs and their products
    genvar g1, g2;
    generate
        k = 0;
        for (g1 = 0; g1 < 8; g1 = g1 + 1) begin : outer_loop
            for (g2 = g1 + 1; g2 < 8; g2 = g2 + 1) begin : inner_loop
                assign pairs_a[k] = data_in[g1];
                assign pairs_b[k] = data_in[g2];
                assign products[k] = $signed(data_in[g1]) * $signed(data_in[g2]);
                k = k + 1;
            end
        end
    endgenerate

    // Find the maximum product
    wire [31:0] max_temp = products[0];
    wire [15:0] max_a_temp = pairs_a[0];
    wire [15:0] max_b_temp = pairs_b[0];

    always @(*) begin
        max_product = max_temp;
        value_a = max_a_temp;
        value_b = max_b_temp;
        for (i = 1; i < 28; i = i + 1) begin
            if (products[i] > max_product) begin
                max_product = products[i];
                value_a = pairs_a[i];
                value_b = pairs_b[i];
            end
        end
    end

endmodule