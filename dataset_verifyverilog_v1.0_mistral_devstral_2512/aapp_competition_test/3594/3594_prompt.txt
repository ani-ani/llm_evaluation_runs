module game_scores(
    input [1:0] start_player,  // 00: O, 01: E, 10: I
    input [4:0] start_number,  // 1 to 20
    output reg [7:0] score_O,
    output reg [7:0] score_E,
    output reg [7:0] score_I
);

// ROM for 60 entries (3 players * 20 numbers) of 24 bits each
reg [23:0] rom [0:59];

initial begin
    $readmemh("rom_data.hex", rom);
end

always @(*) begin
    reg [5:0] index;
    if (start_number >= 1 && start_number <= 20)
        index = start_player * 20 + (start_number - 1);
    else
        index = 0;
    {score_O, score_E, score_I} = rom[index];
end

endmodule