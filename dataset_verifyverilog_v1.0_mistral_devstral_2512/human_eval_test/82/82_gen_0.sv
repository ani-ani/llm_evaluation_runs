module prime_length(
    input [127:0] string_data,
    input [3:0] string_len,
    output result
);
    
    // Combinational logic to determine if string_len is prime
    // Prime numbers between 0-16: 2, 3, 5, 7, 11, 13
    assign result = 
        (string_len == 4'd2)  || 
        (string_len == 4'd3)  || 
        (string_len == 4'd5)  || 
        (string_len == 4'd7)  || 
        (string_len == 4'd11) || 
        (string_len == 4'd13);
    
endmodule