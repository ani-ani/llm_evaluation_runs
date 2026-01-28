module ScarySubarrayCounter(
    input [3:0] p [0:15],
    output reg [9:0] scary_count
);
    integer l, r, k;
    reg [3:0] current_less, current_greater;
    always @(*) begin
        scary_count = 10'd0;
        for (l = 0; l < 16; l = l + 1) begin
            for (r = l; r < 16; r = r + 1) begin
                if ((r - l + 1) % 2 == 1) begin
                    current_less = 4'd0;
                    current_greater = 4'd0;
                    for (k = l; k <= r; k = k + 1) begin
                        if (p[k] < p[l]) begin
                            current_less = current_less + 4'd1;
                        end else if (p[k] > p[l]) begin
                            current_greater = current_greater + 4'd1;
                        end
                    end
                    if (current_less == current_greater) begin
                        scary_count = scary_count + 10'd1;
                    end
                end
            end
        end
    end
endmodule