module random_picture_counter(input [3:0] N, input [3:0] M, output [29:0] result);
localparam [15:0] Fib[16] = '{1,1,2,3,5,8,13,21,34,55,89,144,233,377,610,987};
wire [15:0] F_N, F_M;
wire [15:0] sum;
always @(*) begin
    case(N)
    0: F_N = Fib[0];
    1: F_N = Fib[1];
    2: F_N = Fib[2];
    3: F_N = Fib[3];
    4: F_N = Fib[4];
    5: F_N = Fib[5];
    6: F_N = Fib[6];
    7: F_N = Fib[7];
    8: F_N = Fib[8];
    9: F_N = Fib[9];
    10: F_N = Fib[10];
    11: F_N = Fib[11];
    12: F_N = Fib[12];
    13: F_N = Fib[13];
    14: F_N = Fib[14];
    15: F_N = Fib[15];
    default: F_N = 0;
    endcase
    case(M)
    0: F_M = Fib[0];
    1: F_M = Fib[1];
    2: F_M = Fib[2];
    3: F_M = Fib[3];
    4: F_M = Fib[4];
    5: F_M = Fib[5];
    6: F_M = Fib[6];
    7: F_M = Fib[7];
    8: F_M = Fib[8];
    9: F_M = Fib[9];
    10: F_M = Fib[10];
    11: F_M = Fib[11];
    12: F_M = Fib[12];
    13: F_M = Fib[13];
    14: F_M = Fib[14];
    15: F_M = Fib[15];
    default: F_M = 0;
    endcase
end
assign sum = F_N + F_M - 1;
assign result = 2 * sum;
endmodule