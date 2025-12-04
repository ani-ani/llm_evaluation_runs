module adder (input wire [7:0] a, b, input wire cin, output reg [8:0] sum); 

  always @(*) begin 
    sum = a + b + cin; 
  end 

endmodule