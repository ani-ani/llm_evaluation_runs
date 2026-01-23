module count_up_to (
    input [5:0] n,
    output [5:0] primes [0:17],
    output [4:0] count
);

localparam primes_full[17:0] = {2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61};

always @(*) begin
    if (2 >= n) count = 0;
    else if (3 >= n) count = 1;
    else if (5 >= n) count = 2;
    else if (7 >= n) count = 3;
    else if (11 >= n) count = 4;
    else if (13 >= n) count = 5;
    else if (17 >= n) count = 6;
    else if (19 >= n) count = 7;
    else if (23 >= n) count = 8;
    else if (29 >= n) count = 9;
    else if (31 >= n) count =10;
    else if (37 >= n) count =11;
    else if (41 >= n) count =12;
    else if (43 >= n) count =13;
    else if (47 >= n) count =14;
    else if (53 >= n) count =15;
    else if (59 >= n) count =16;
    else if (61 >= n) count =17;
    else count =18;
end

always @(*) begin
    generate
        for (int i=0; i<18; i++) begin
            if (i < count) 
                primes[i] = primes_full[i];
            else
                primes[i] = 0;
        end
    endgenerate
end

endmodule