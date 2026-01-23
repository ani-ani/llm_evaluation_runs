module substring_counter(
    input [7:0] str_len,  // Length of string (0-8)
    output reg [15:0] result  // Number of substrings
);

// Combinational logic to calculate n*(n+1)/2
always @(*) begin
    result = str_len * (str_len + 1) >> 1;
end

endmodule