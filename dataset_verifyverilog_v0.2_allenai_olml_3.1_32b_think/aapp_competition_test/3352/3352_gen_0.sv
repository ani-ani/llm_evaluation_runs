module magic_color_counter (
    input [3:0] flat_tree [0:255],
    input [7:0] query_start_idx,
    input [7:0] query_end_idx,
    input [2:0] num_colors,
    output reg [3:0] magical_count
);

reg [3:0] parity;

always @(*) begin
    parity = 4'b0000;
    generate
        for (int i=0; i<=255; i++) begin
            if (i >= query_start_idx && i < query_end_idx) begin
                if (flat_tree[i] !=0 && flat_tree[i] <= num_colors) begin
                    parity[flat_tree[i]-1] ^= 1;
                end
            end
        end
    endgenerate
end

reg [3:0] sum_p;
always @(*) begin
    sum_p = 0;
    if (num_colors >=1) sum_p += parity[0];
    if (num_colors >=2) sum_p += parity[1];
    if (num_colors >=3) sum_p += parity[2];
    if (num_colors >=4) sum_p += parity[3];
end

assign magical_count = sum_p;

endmodule