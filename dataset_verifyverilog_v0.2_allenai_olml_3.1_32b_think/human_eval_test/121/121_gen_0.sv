module sum_odd_even_pos (
    input [7:0][7:0] data,
    input [2:0] length,
    output [9:0] result
);

assign result = 
    ( (length > 0) ? (data[0][0] ? data[0] : 0) : 0 ) + 
    ( (length > 2) ? (data[2][0] ? data[2] : 0) : 0 ) + 
    ( (length > 4) ? (data[4][0] ? data[4] : 0 ) : 0 ) + 
    ( (length > 6) ? (data[6][0] ? data[6] : 0 ) : 0 );

endmodule