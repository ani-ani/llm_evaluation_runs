module triangular_prism_volume(input [15:0] l, input [15:0] b, input [15:0] h, output [15:0] volume);
    wire [47:0] product;
    assign product = l * b * h;
    assign volume = product >> 1;
endmodule