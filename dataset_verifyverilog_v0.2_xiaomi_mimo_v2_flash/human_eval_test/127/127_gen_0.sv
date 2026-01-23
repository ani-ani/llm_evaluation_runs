module interval_intersection_prime(
    input signed [7:0] start1,
    input signed [7:0] end1,
    input signed [7:0] start2,
    input signed [7:0] end2,
    output reg is_prime
);

    wire signed [7:0] i_start;
    wire signed [7:0] i_end;
    wire signed [7:0] len_temp;
    wire [6:0] length;

    // Calculate intersection boundaries
    assign i_start = (start1 > start2) ? start1 : start2;
    assign i_end = (end1 < end2) ? end1 : end2;

    // Calculate length
    // Range is [-32, 31], so difference is [-63, 63]
    // Intersection exists implies i_start <= i_end
    assign len_temp = i_end - i_start;
    assign length = len_temp[6:0]; // Use 7 bits to represent 0-63

    // Prime detection logic
    always @(*) begin
        if (i_start > i_end) begin
            is_prime = 1'b0;
        end else begin
            case (length)
                7'd2, 7'd3, 7'd5, 7'd7, 
                7'd11, 7'd13, 7'd17, 7'd19, 
                7'd23, 7'd29, 7'd31, 7'd37, 
                7'd41, 7'd43, 7'd47, 7'd53, 
                7'd59, 7'd61: 
                    is_prime = 1'b1;
                default: 
                    is_prime = 1'b0;
            endcase
        end
    end

endmodule