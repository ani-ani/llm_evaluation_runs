module close_element_checker (
    input [127:0] numbers_packed,
    input [15:0] threshold_q8_8,
    output has_close_pair
);
    wire [15:0] nums [0:7];
    assign nums[0] = numbers_packed[127:112];
    assign nums[1] = numbers_packed[111:96];
    assign nums[2] = numbers_packed[95:80];
    assign nums[3] = numbers_packed[79:64];
    assign nums[4] = numbers_packed[63:48];
    assign nums[5] = numbers_packed[47:32];
    assign nums[6] = numbers_packed[31:16];
    assign nums[7] = numbers_packed[15:0];

    wire [27:0] close_pairs;

    genvar i, j;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_i
            for (j = i + 1; j < 8; j = j + 1) begin : gen_j
                localparam integer idx = ((15 - i)*i/2) + (j - i - 1);
                wire [15:0] a = nums[i];
                wire [15:0] b = nums[j];
                wire [15:0] diff_sub = a - b;
                wire [15:0] diff_add = b - a;
                wire [15:0] abs_diff = (a >= b) ? diff_sub : diff_add;
                assign close_pairs[idx] = (abs_diff < threshold_q8_8);
            end
        end
    endgenerate

    assign has_close_pair = |close_pairs;
endmodule