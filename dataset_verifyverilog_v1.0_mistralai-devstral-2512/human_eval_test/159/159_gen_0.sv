module CarrotCalculator(
    input [9:0] number,
    input [9:0] need,
    input [9:0] remaining,
    output [10:0] total,
    output [10:0] remaining_after
);

    wire [9:0] eaten;
    assign eaten = (need < remaining) ? need : remaining;
    assign total = number + eaten;
    assign remaining_after = remaining - eaten;

endmodule