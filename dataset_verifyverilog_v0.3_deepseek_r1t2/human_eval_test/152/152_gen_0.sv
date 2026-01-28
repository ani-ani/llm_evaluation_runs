module compare_arrays(
    input [7:0] score [0:7],
    input [7:0] guess [0:7],
    output [7:0] result [0:7]
);
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_abs_diff
            wire signed [7:0] diff = score[i] - guess[i];
            assign result[i] = (score[i] == guess[i]) ? 8'd0 : (diff[7] ? (~diff + 8'd1) : diff);
        end
    endgenerate
endmodule