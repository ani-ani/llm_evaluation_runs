module eat(
    input [7:0] number,
    input [7:0] need,
    input [7:0] remaining,
    output [7:0] total,
    output [7:0] left
);
    
    wire [7:0] carrots_eaten;
    wire [8:0] total_temp;
    
    assign carrots_eaten = (need < remaining) ? need : remaining;
    assign total_temp = number + carrots_eaten;
    assign total = total_temp[7:0];
    assign left = remaining - carrots_eaten;
    
endmodule