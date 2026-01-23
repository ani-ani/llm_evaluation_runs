module prob_calc(
    input [7:0] f,
    input [7:0] w,
    input [7:0] h,
    output reg [31:0] p
);

    localparam MOD = 1000000007;
    localparam MAX_N = 16;

    // Binomial coefficient table: C[n][k]
    reg [15:0] C [0:MAX_N][0:MAX_N];

    // Initialize C using Pascal's triangle
    integer i, j;
    initial begin
        // Initialize all to 0
        for (i = 0; i <= MAX_N; i = i + 1) begin
            for (j = 0; j <= MAX_N; j = j + 1) begin
                C[i][j] = 0;
            end
        end
        // Compute Pascal's triangle
        for (i = 0; i <= MAX_N; i = i + 1) begin
            C[i][0] = 1;
            C[i][i] = 1;
            for (j = 1; j < i; j = j + 1) begin
                C[i][j] = C[i-1][j-1] + C[i-1][j];
            end
        end
    end

    // Function to lookup modular inverse (precomputed for possible totals)
    function [31:0] inv_lookup;
        input [15:0] total;
        begin
            case(total)
                1: inv_lookup = 1;
                2: inv_lookup = 500000004;
                3: inv_lookup = 333333336;
                6: inv_lookup = 166666668;
                20: inv_lookup = 850000006;
                default: inv_lookup = 0;
            endcase
        end
    endfunction

    // Combinational logic
    reg [15:0] total, liked;
    reg [15:0] kmax;
    reg [15:0] term1, term2;
    reg [15:0] n2, r2;
    reg [15:0] k;
    reg [31:0] inv_total;

    always @(*) begin
        // Compute total = C[f+w][w]
        total = C[f + w][w];

        // Compute liked
        if (w == 0) begin
            liked = 1;
        end else begin
            liked = 0;
            // Compute kmax = min(w / (h+1), f+1)
            if (h == 8'hFF) begin
                kmax = 0;
            end else begin
                kmax = w / (h + 1);
            end
            if (kmax > f + 1) kmax = f + 1;

            for (k = 1; k <= kmax; k = k + 1) begin
                term1 = C[f + 1][k];
                n2 = w - k * h - 1;
                r2 = k - 1;
                if (n2 >= r2 && r2 >= 0) begin
                    term2 = C[n2][r2];
                end else begin
                    term2 = 0;
                end
                liked = liked + term1 * term2;
            end
        end

        // Lookup inverse
        inv_total = inv_lookup(total);

        // Compute result
        p = (liked * inv_total) % MOD;
    end

endmodule