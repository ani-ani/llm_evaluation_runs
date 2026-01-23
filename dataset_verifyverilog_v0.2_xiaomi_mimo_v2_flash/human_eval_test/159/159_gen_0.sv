module eat_carrots(
    input [7:0] number,
    input [7:0] need,
    input [7:0] remaining,
    output reg [7:0] total_eaten,
    output reg [7:0] left_over
);
    always @(*) begin
        if (need <= remaining) begin
            total_eaten = number + need;
            left_over = remaining - need;
        end else begin
            total_eaten = number + remaining;
            left_over = 8'b0;
        end
    end
endmodule