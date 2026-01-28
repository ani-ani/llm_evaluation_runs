module choose_num(
    input [15:0] x,
    input [15:0] y,
    output [15:0] result
);
    
    wire [15:0] largest_even;
    wire [15:0] output_value;
    
    // Calculate largest even number <= y
    assign largest_even = (y[0] == 1'b0) ? y : (y - 16'd1);
    
    // Check if x > y
    assign output_value = (x > y) ? 16'hFFFF : 
                         ((largest_even >= x) ? largest_even : 16'hFFFF);
    
    assign result = output_value;
    
endmodule