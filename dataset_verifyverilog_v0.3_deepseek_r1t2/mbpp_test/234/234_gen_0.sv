module cube_volume(
    input [7:0] side_length,
    output reg [23:0] volume
);
    always @(*) begin
        volume = side_length * side_length * side_length;
    end
endmodule