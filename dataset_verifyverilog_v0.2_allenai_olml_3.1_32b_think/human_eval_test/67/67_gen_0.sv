module fruit_distribution(
    input [7:0] apples_str,
    input [7:0] oranges_str,
    input [7:0] total_fruits,
    output [7:0] mangoes
);
assign mangoes = ( ( (signed)total_fruits - (signed)apples_str - (signed)oranges_str ) >= 0 ) ? ( (signed)total_fruits - (signed)apples_str - (signed)oranges_str ) : 8'b0;
endmodule