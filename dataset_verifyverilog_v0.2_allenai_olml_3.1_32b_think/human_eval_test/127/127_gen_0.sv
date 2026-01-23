module interval_intersection_prime (
    input signed [7:0] start1, end1,
    input signed [7:0] start2, end2,
    output is_prime
);
wire signed [7:0] intersection_start, intersection_end;
wire [7:0] length;

assign intersection_start = (start1 > start2) ? start1 : start2;
assign intersection_end = (end1 < end2) ? end1 : end2;

always @(*) begin
    if (intersection_start > intersection_end) begin
        is_prime = 0;
    end else begin
        length = intersection_end - intersection_start;
        if (length == 0) begin
            is_prime = 0;
        end else begin
            case(length)
                2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61: is_prime = 1;
                default: is_prime = 0;
            endcase
        end
    end
end
endmodule