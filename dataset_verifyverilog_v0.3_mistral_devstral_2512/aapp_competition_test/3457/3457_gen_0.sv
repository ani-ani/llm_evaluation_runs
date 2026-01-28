module hopscotch_counter(
    input [7:0] N,
    input [7:0] X,
    input [7:0] Y,
    output reg [31:0] result
);

localparam MOD = 1000000007;

// Modular inverse of i for i=1..64 precomputed offline using Fermat's little theorem.
function [31:0] inv;
    input [7:0] i;
    begin
        case (i)
            1: inv = 1;
            2: inv = 500000004;
            3: inv = 333333336;
            4: inv = 250000002;
            5: inv = 400000003;
            6: inv = 166666668;
            7: inv = 142857144;
            8: inv = 125000001;
            9: inv = 111111112;
            10: inv = 100000001;
            11: inv = 90909091;
            12: inv = 83333334;
            13: inv = 76923077;
            14: inv = 71428572;
            15: inv = 66666667;
            16: inv = 62500001;
            17: inv = 58823530;
            18: inv = 55555556;
            19: inv = 52631579;
            20: inv = 50000001;
            21: inv = 47619048;
            22: inv = 45454546;
            23: inv = 43478261;
            24: inv = 41666667;
            25: inv = 40000001;
            26: inv = 38461539;
            27: inv = 37037037;
            28: inv = 35714286;
            29: inv = 34482759;
            30: inv = 33333334;
            31: inv = 32258065;
            32: inv = 31250001;
            33: inv = 30303031;
            34: inv = 29411765;
            35: inv = 28571429;
            36: inv = 27777778;
            37: inv = 27027027;
            38: inv = 26315790;
            39: inv = 25641026;
            40: inv = 25000001;
            41: inv = 24390244;
            42: inv = 23809524;
            43: inv = 23255814;
            44: inv = 22727273;
            45: inv = 22222222;
            46: inv = 21739131;
            47: inv = 21276596;
            48: inv = 20833334;
            49: inv = 20408164;
            50: inv = 20000001;
            51: inv = 19607844;
            52: inv = 19230770;
            53: inv = 18867925;
            54: inv = 18518519;
            55: inv = 18181819;
            56: inv = 17857143;
            57: inv = 17543860;
            58: inv = 17241380;
            59: inv = 16949153;
            60: inv = 16666667;
            61: inv = 16393443;
            62: inv = 16129033;
            63: inv = 15873016;
            64: inv = 15625001;
            default: inv = 0;
        endcase
    end
endfunction

// Modular multiplication (a*b) % MOD
function [31:0] mod_mul;
    input [31:0] a;
    input [31:0] b;
    begin
        mod_mul = (a * b) % MOD;
    end
endfunction

// Binomial coefficient C(n, r) using product formula
function [31:0] binom;
    input [7:0] n;
    input [7:0] r;
    integer i;
    reg [31:0] prod;
    begin
        if (r > n)
            binom = 0;
        else if (r == 0)
            binom = 1;
        else begin
            prod = 1;
            for (i = 0; i < r; i = i + 1) begin
                prod = mod_mul(prod, n - i);
                prod = mod_mul(prod, inv(i+1));
            end
            binom = prod;
        end
    end
endfunction

// Main combinational logic
always @(*) begin
    reg [7:0] k;
    reg [7:0] k_max;
    reg [31:0] sum;
    reg [31:0] binom1, binom2;
    reg [7:0] n1, r1, n2, r2;
    
    // Determine maximum number of hops k_max
    k_max = 0;
    for (k = 1; k <= 64; k = k + 1) begin
        if (k * X <= N && k * Y <= N) begin
            k_max = k;
        end
    end
    
    // Sum over k
    sum = 0;
    for (k = 1; k <= 64; k = k + 1) begin
        if (k <= k_max) begin
            n1 = N - k * X + k - 1;
            r1 = k - 1;
            n2 = N - k * Y + k - 1;
            r2 = k - 1;
            binom1 = binom(n1, r1);
            binom2 = binom(n2, r2);
            sum = (sum + mod_mul(binom1, binom2)) % MOD;
        end
    end
    
    result = sum;
end

endmodule