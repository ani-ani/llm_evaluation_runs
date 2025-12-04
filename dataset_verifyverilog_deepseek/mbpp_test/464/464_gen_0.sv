module dict_value_check (
    input [31:0] entries,
    input [7:0] n,
    output result
);
    assign result = (entries[7:0] == n) && 
                    (entries[15:8] == n) && 
                    (entries[23:16] == n) && 
                    (entries[31:24] == n);
endmodule