module find_kth (
    input [3:0] k,
    input [2:0] m,
    input [2:0] n,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    output [7:0] kth_element
);

    wire [7:0] merged [0:15];
    integer i, j, idx;

    // Generate all possible merged array elements
    genvar g1, g2;
    generate
        for (g1 = 0; g1 < 8; g1 = g1 + 1) begin : gen_arr1
            for (g2 = 0; g2 < 8; g2 = g2 + 1) begin : gen_arr2
                assign merged[g1 + g2] = (arr1[g1] < arr2[g2]) ? arr1[g1] : arr2[g2];
            end
        end
    endgenerate

    // Find the k-th smallest element
    always @* begin
        kth_element = 8'h0;
        if (k > 0 && k <= m + n) begin
            for (idx = 0; idx < 16; idx = idx + 1) begin
                if (idx == k - 1) begin
                    kth_element = merged[idx];
                end
            end
        end
    end

endmodule