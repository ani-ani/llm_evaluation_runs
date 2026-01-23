module best_subsequence(input [7:0] k, input [63:0] data, input [5:0] n, output reg [5:0] start_index, output reg [5:0] length);
reg [5:0] best_start;
reg [5:0] best_length;
reg [63:0] best_sum;
always_comb begin
    best_start = 6'd0;
    best_length = 6'd0;
    best_sum = 0;

    integer i, j, m;
    integer candidate_sum, candidate_length;

    for (i=0; i < n; i++) begin
        if (i + k > n) continue;
        for (j = i +k; j <= n; j++) begin
            candidate_sum =0;
            for (m =i; m < j; m++) begin
                candidate_sum += data[m];
            end
            candidate_length = j - i;

            if (best_length ==0) begin
                best_start = i;
                best_length = candidate_length;
                best_sum = candidate_sum;
            end else begin
                if (candidate_sum * best_length > best_sum * candidate_length) begin
                    best_start = i;
                    best_length = candidate_length;
                    best_sum = candidate_sum;
                end else if (candidate_sum * best_length == best_sum * candidate_length) begin
                    if (i < best_start) begin
                        best_start = i;
                        best_length = candidate_length;
                        best_sum = candidate_sum;
                    end else if (i == best_start) begin
                        if (candidate_length > best_length) begin
                            best_length = candidate_length;
                            best_sum = candidate_sum;
                        end
                    end
                end
            end
        end
    end

    if (best_length ==0) begin
        start_index = 0;
        length =0;
    end else begin
        start_index = best_start;
        length = best_length;
    end
end
endmodule