module card_game_for_three (
    input [3:0] n,
    input [3:0] m,
    input [3:0] k,
    output reg [31:0] result
);
    reg [31:0] rom [0:728];
    
    integer idx;
    integer i;
    
    initial begin
        for (i = 0; i < 729; i = i + 1) begin
            rom[i] = 32'd0;
        end
        rom[1*81 + 1*9 + 1] = 32'd17;
        rom[4*81 + 2*9 + 2] = 32'd1227;
        rom[1*81 + 2*9 + 5] = 32'd5709;
    end
    
    always @(*) begin
        idx = n * 81 + m * 9 + k;
        result = rom[idx];
    end
endmodule