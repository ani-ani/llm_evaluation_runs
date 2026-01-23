module oven_decision (
    input [15:0] n,
    input [15:0] t,
    input [15:0] k,
    input [15:0] d,
    output build_second
);
assign build_second = ( ( (n + k - 1) / k ) * t ) > (d + t) ? 1'b1 : 1'b0;
endmodule