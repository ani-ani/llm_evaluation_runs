module next_perfect_square (
    input [15:0] N,
    output [15:0] result
);

    reg [7:0] sqrt_floor;
    integer i;

    always @(*) begin
        sqrt_floor = 0;
        for (i = 7; i >= 0; i = i - 1) begin
            if (((sqrt_floor | (8'h1 << i)) * (sqrt_floor | (8'h1 << i))) <= N)
                sqrt_floor = sqrt_floor | (8'h1 << i);
        end
    end

    wire [8:0] nextN;
    assign nextN = sqrt_floor + 1;

    assign result = nextN * nextN;

endmodule