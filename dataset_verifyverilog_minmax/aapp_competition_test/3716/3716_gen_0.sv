module max_triple_lcm(
    input [7:0] n,
    output reg [23:0] max_lcm
);

    function [7:0] gcd8 (input [7:0] a, input [7:0] b);
        reg [7:0] x = a;
        reg [7:0] y = b;
        while (y != 0) begin
            reg [7:0] t = y;
            y = x % y;
            x = t;
        end
        gcd8 = x;
    endfunction

    function [15:0] lcm2_8 (input [7:0] a, input [7:0] b);
        if (a == 0 || b == 0)
            lcm2_8 = 0;
        else
            lcm2_8 = (a / gcd8(a, b)) * b;
    endfunction

    function [15:0] gcd16 (input [15:0] a, input [15:0] b);
        reg [15:0] x = a;
        reg [15:0] y = b;
        while (y != 0) begin
            reg [15:0] t = y;
            y = x % y;
            x = t;
        end
        gcd16 = x;
    endfunction

    function [23:0] lcm2 (input [7:0] a, input [15:0] b);
        reg [15:0] a16 = a;
        if (a16 == 0 || b == 0)
            lcm2 = 0;
        else begin
            reg [15:0] g = gcd16(a16, b);
            reg [7:0] a_div = a16 / g;
            lcm2 = a_div * b;
        end
    endfunction

    always @(*) begin
        reg [7:0] start = (n > 7) ? (n - 7) : 1;
        max_lcm = 0;
        for (int i = start; i <= n; i++) begin
            for (int j = start; j <= i; j++) begin
                for (int k = start; k <= j; k++) begin
                    reg [15:0] lcm_jk = lcm2_8(j, k);
                    reg [23:0] lcm_ijk = lcm2(i, lcm_jk);
                    if (lcm_ijk > max_lcm)
                        max_lcm = lcm_ijk;
                end
            end
        end
    end

endmodule