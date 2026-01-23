module hopscotch_counter(
    input [7:0] N,
    input [7:0] X,
    input [7:0] Y,
    output reg [31:0] result
);

localparam [31:0] MOD = 32'd1000000007;

// Modular inverse of i for i=1..64 precomputed offline
function [31:0] inv;
    input [7:0] i;
    begin
        case (i)
            1: inv = 32'd1;
            2: inv = 32'd500000004;
            3: inv = 32'd333333336;
            4: inv = 32'd250000002;
            5: inv = 32'd400000003;
            6: inv = 32'd166666668;
            7: inv = 32'd142857144;
            8: inv = 32'd125000001;
            9: inv = 32'd111111112;
            10: inv = 32'd100000001;
            11: inv = 32'd90909091;
            12: inv = 32'd83333334;
            13: inv = 32'd76923077;
            14: inv = 32'd71428572;
            15: inv = 32'd66666667;
            16: inv = 32'd62500001;
            17: inv = 32'd58823530;
            18: inv = 32'd55555556;
            19: inv = 32'd52631579;
            20: inv = 32'd50000001;
            21: inv = 32'd47619048;
            22: inv = 32'd45454546;
            23: inv = 32'd43478261;
            24: inv = 32'd41666667;
            25: inv = 32'd40000001;
            26: inv = 32'd38461539;
            27: inv = 32'd37037037;
            28: inv = 32'd35714286;
            29: inv = 32'd34482759;
            30: inv = 32'd33333334;
            31: inv = 32'd32258065;
            32: inv = 32'd31250001;
            33: inv = 32'd30303031;
            34: inv = 32'd29411765;
            35: inv = 32'd28571429;
            36: inv = 32'd27777778;
            37: inv = 32'd27027027;
            38: inv = 32'd26315790;
            39: inv = 32'd25641026;
            40: inv = 32'd25000001;
            41: inv = 32'd24390244;
            42: inv = 32'd23809524;
            43: inv = 32'd23255814;
            44: inv = 32'd22727273;
            45: inv = 32'd22222222;
            46: inv = 32'd21739131;
            47: inv = 32'd21276596;
            48: inv = 32'd20833334;
            49: inv = 32'd20408164;
            50: inv = 32'd20000001;
            51: inv = 32'd19607844;
            52: inv = 32'd19230770;
            53: inv = 32'd18867925;
            54: inv = 32'd18518519;
            55: inv = 32'd18181819;
            56: inv = 32'd17857143;
            57: inv = 32'd17543860;
            58: inv = 32'd17241380;
            59: inv = 32'd16949153;
            60: inv = 32'd16666667;
            61: inv = 32'd16393443;
            62: inv = 32'd16129033;
            63: inv = 32'd15873016;
            64: inv = 32'd15625001;
            default: inv = 32'd0;
        endcase
    end
endfunction

// Modular multiplication
function [31:0] mod_mul;
    input [31:0] a;
    input [31:0] b;
    begin
        mod_mul = (a * b) % MOD;
    end
endfunction

// Binomial coefficient C(n, r)
function [31:0] binom;
    input [7:0] n;
    input [7:0] r;
    integer i;
    reg [31:0] prod;
    begin
        if (r > n)
            binom = 32'd0;
        else if (r == 8'd0)
            binom = 32'd1;
        else begin
            prod = 32'd1;
            for (i = 0; i < 8; i = i + 1) begin
                if (i < r) begin
                    prod = mod_mul(prod, n - i);
                    prod = mod_mul(prod, inv(i + 1));
                end
            end
            binom = prod;
        end
    end
endfunction

always @(*) begin
    reg [7:0] k;
    reg [7:0] k_max;
    reg [31:0] sum;
    reg [31:0] binom1;
    reg [31:0] binom2;
    reg [7:0] n1;
    reg [7:0] r1;
    reg [7:0] n2;
    reg [7:0] r2;
    
    // Determine maximum number of hops k_max
    k_max = 8'd0;
    for (k = 8'd1; k <= 8'd64; k = k + 1) begin
        if (k * X <= N && k * Y <= N) begin
            k_max = k;
        end
    end
    
    // Sum over k
    sum = 32'd0;
    for (k = 8'd1; k <= 8'd64; k = k + 1) begin
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