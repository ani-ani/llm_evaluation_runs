module interval_intersection(
    input [15:0] start1, end1,
    input [15:0] start2, end2,
    output reg result
);

    reg [7:0] intersection_start;
    reg [7:0] intersection_end;
    reg [7:0] length;

    always @(*) begin
        // Compute intersection interval
        intersection_start = (start1 > start2) ? start1 : start2;
        intersection_end = (end1 < end2) ? end1 : end2;
        
        // Compute length
        length = intersection_end - intersection_start;
        
        // Check if intersection exists and length is prime
        if (length >= 0) begin
            case (length)
                2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 
                73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 
                151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 
                229, 233, 239, 241, 251:
                    result = 1'b1;
                default:
                    result = 1'b0;
            endcase
        end else begin
            result = 1'b0;
        end
    end

endmodule