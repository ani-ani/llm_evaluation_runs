module surfacearea_cylinder (
    input [31:0] r,
    input [31:0] h,
    output [31:0] result
);
localparam CONSTANT_2PI = 411774;
assign result = ( (CONSTANT_2PI * ( (r * r) >> 16 )) >> 16 ) + ( (CONSTANT_2PI * ( (r * h) >> 16 )) >> 16 );
endmodule