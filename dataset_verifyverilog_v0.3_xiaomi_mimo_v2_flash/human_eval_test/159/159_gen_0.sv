module eat(
    input [7:0] number,
    input [7:0] need,
    input [7:0] remaining,
    output [7:0] total,
    output [7:0] left
);

    // Calculate min(need, remaining)
    wire [7:0] min_val;
    assign min_val = (need < remaining) ? need : remaining;

    // Calculate total: number + min_val (may exceed 8 bits)
    wire [8:0] total_extended;
    assign total_extended = {1'b0, number} + {1'b0, min_val};
    
    // Handle overflow: if > 255, saturate to 255
    assign total = (total_extended > 9'd255) ? 8'd255 : total_extended[7:0];

    // Calculate left: remaining - min_val (always non-negative)
    assign left = remaining - min_val;

endmodule