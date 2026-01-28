module CountNonSimilarWorlds(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n_in,
    input wire [5:0] m_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [5:0] MAX_N = 6'd50;

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] OUTER_LOOP = 4'd2;
    localparam [3:0] INNER_LOOP = 4'd3;
    localparam [3:0] CALC_TMP = 4'd4;
    localparam [3:0] COMBINE = 4'd5;
    localparam [3:0] UPDATE_S = 4'd6;
    localparam [3:0] FINISH = 4'd7;

    // Control signals
    reg [3:0] state;
    reg [5:0] node;
    reg [5:0] cut;
    reg [5:0] ln;
    reg [5:0] lc;
    reg [5:0] i;

    // DP tables (51x51)
    reg [31:0] f [0:50][0:50];
    reg [31:0] s [0:50][0:50];

    // Temporary registers
    reg [31:0] tmp;
    reg [31:0] cnt;
    reg [31:0] product;

    // Precomputed inverses (1..50)
    reg [31:0] inv [1:50];

    // Precompute inverses at reset
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 1; k <= 50; k = k + 1) begin
                inv[k] = compute_inverse(k);
            end
        end
    end

    // Compute modular inverse (using Fermat's little theorem)
    function [31:0] compute_inverse(input [5:0] x);
        reg [31:0] res;
        reg [31:0] base;
        reg [31:0] exp;
        integer j;
        begin
            base = x;
            exp = MOD - 2;
            res = 1;
            for (j = 0; j < 30; j = j + 1) begin
                if (exp[j]) begin
                    res = (res * base) % MOD;
                end
                base = (base * base) % MOD;
            end
            compute_inverse = res;
        end
    endfunction

    // Modular multiplication
    function [31:0] mod_mul(input [31:0] a, input [31:0] b);
        reg [63:0] product;
        begin
            product = a * b;
            mod_mul = product % MOD;
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            node <= 6'd0;
            cut <= 6'd0;
            ln <= 6'd0;
            lc <= 6'd0;
            i <= 6'd0;
            tmp <= 32'd0;
            cnt <= 32'd0;
            product <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;

            // Initialize DP tables
            for (k = 0; k <= 50; k = k + 1) begin
                for (integer l = 0; l <= 50; l = l + 1) begin
                    f[k][l] <= 32'd0;
                    s[k][l] <= 32'd0;
                end
            end
            f[0][0] <= 32'd1;
            s[0][0] <= 32'd1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Reset counters
                    node <= 6'd1;
                    cut <= 6'd1;
                    ln <= 6'd0;
                    lc <= 6'd0;
                    tmp <= 32'd0;
                    cnt <= 32'd0;
                    product <= 32'd0;
                    state <= OUTER_LOOP;
                end

                OUTER_LOOP: begin
                    if (node > n_in) begin
                        state <= FINISH;
                    end else begin
                        cut <= 6'd1;
                        state <= INNER_LOOP;
                    end
                end

                INNER_LOOP: begin
                    if (cut > node) begin
                        state <= UPDATE_S;
                    end else begin
                        ln <= 6'd0;
                        lc <= 6'd0;
                        tmp <= 32'd0;
                        state <= CALC_TMP;
                    end
                end

                CALC_TMP: begin
                    if (ln >= node) begin
                        // Calculate cnt
                        if (tmp != 0) begin
                            product <= 32'd1;
                            i <= 6'd1;
                            state <= COMBINE;
                        end else begin
                            state <= INNER_LOOP;
                        end
                    end else if (lc >= cut) begin
                        ln <= ln + 6'd1;
                        lc <= 6'd0;
                    end else begin
                        if (lc == cut - 1) begin
                            tmp <= tmp + mod_mul(f[ln][lc], s[node - ln - 1][cut - 1]);
                        end else begin
                            tmp <= tmp + mod_mul(f[ln][lc], f[node - ln - 1][cut - 1]);
                        end
                        lc <= lc + 6'd1;
                    end
                end

                COMBINE: begin
                    if (i > 50) begin
                        // Update f table
                        f[node][cut] <= mod_mul(tmp, cnt);
                        state <= INNER_LOOP;
                    end else begin
                        product <= mod_mul(product, mod_mul(tmp + i - 1, inv[i]));
                        i <= i + 6'd1;
                    end
                end

                UPDATE_S: begin
                    // Update s table
                    s[node][cut] <= mod_mul(s[node][cut - 1], f[node][cut]);
                    if (cut == node) begin
                        node <= node + 6'd1;
                        state <= OUTER_LOOP;
                    end else begin
                        cut <= cut + 6'd1;
                        state <= INNER_LOOP;
                    end
                end

                FINISH: begin
                    result <= f[n_in][m_in];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule