module drink_partitions (
    input [7:0] bad_pairs_ingredient_a,
    input [7:0] bad_pairs_ingredient_b,
    input [2:0] num_bad_pairs,
    output reg [15:0] num_partitions);

reg [7:0][7:0] matrix;

function automatic valid_segment(input int i, j);
    reg [7:0] valid;
    valid = 1'b1;
    for (int k = i; k <= j; k++) begin
        for (int l = k+1; l <= j; l++) begin
            if (matrix[k][l]) begin
                valid = 1'b0;
                break;
            end
        end
        if (!valid) break;
    end
    return valid;
endfunction

function automatic valid_partition(input int split_mask);
    reg [7:0] segments_start, segments_end;
    reg [7:0] pos, count = 0;
    reg [7:0] valid = 1'b1;
    segments_start = 8'd0;
    for (int i=0; i<7; i++) begin
        if (split_mask & (1<<i)) begin
            if (!valid_segment(segments_start, i)) begin
                valid = 1'b0;
            end
            segments_start = i+1;
        end
    end
    if (segments_start <=7) begin
        if (!valid_segment(segments_start, 7)) begin
            valid = 1'b0;
        end
    end
    return valid;
endfunction

always @(*) begin
    for (int i=0; i<8; i++) begin
        for (int j=0; j<8; j++) begin
            matrix[i][j] = (bad_pairs_ingredient_a[i] & bad_pairs_ingredient_b[j]) || (bad_pairs_ingredient_b[i] & bad_pairs_ingredient_a[j]);
        end
    end
end

always @(*) begin
    reg [15:0] total = 0;
    for (int mask=0; mask < 128; mask++) begin
        if (valid_partition(mask)) begin
            total = total + 1;
        end
    end
    num_partitions = total % 1024;
end

endmodule