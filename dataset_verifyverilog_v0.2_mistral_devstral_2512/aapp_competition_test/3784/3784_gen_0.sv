module world_counter (
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [5:0] m,
    output reg [63:0] result,
    output reg done
);

    // Constants
    localparam MOD = 64'd1000000007;
    localparam MAX_N = 50;
    localparam MAX_M = 50;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        PREPARE_INVERSE,
        DP_LOOP,
        FINISHED
    } state_t;

    state_t state;

    // DP tables (f and s)
    reg [63:0] f [0:MAX_N][0:MAX_M];
    reg [63:0] s [0:MAX_N][0:MAX_M];

    // Inverse table
    reg [63:0] inv [1:MAX_N];

    // Loop counters
    reg [5:0] node;
    reg [5:0] cut;
    reg [5:0] ln;
    reg [5:0] lc;
    reg [5:0] i;

    // Intermediate variables
    reg [63:0] tmp;
    reg [63:0] cnt;
    reg [63:0] product;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 1'b0;
                    end
                end
                INIT: begin
                    state <= PREPARE_INVERSE;
                end
                PREPARE_INVERSE: begin
                    state <= DP_LOOP;
                end
                DP_LOOP: begin
                    if (node == n && cut == m) begin
                        state <= FINISHED;
                    end
                end
                FINISHED: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Initialize DP tables
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all tables
            for (int i = 0; i <= MAX_N; i++) begin
                for (int j = 0; j <= MAX_M; j++) begin
                    f[i][j] <= 64'd0;
                    s[i][j] <= 64'd0;
                end
            end
        end else if (state == INIT) begin
            // Initialize f[0][0] and s[0][0]
            f[0][0] <= 64'd1;
            s[0][0] <= 64'd1;
        end
    end

    // Prepare inverse table
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 1; i <= MAX_N; i++) begin
                inv[i] <= 64'd0;
            end
        end else if (state == PREPARE_INVERSE) begin
            // Hard-coded inverses for numbers 1 to 50
            inv[1] <= 64'd1;
            inv[2] <= 64'd500000004; // 2^(MOD-2) mod MOD
            inv[3] <= 64'd333333336; // 3^(MOD-2) mod MOD
            inv[4] <= 64'd250000002; // 4^(MOD-2) mod MOD
            inv[5] <= 64'd400000003; // 5^(MOD-2) mod MOD
            inv[6] <= 64'd166666668; // 6^(MOD-2) mod MOD
            inv[7] <= 64'd142857144; // 7^(MOD-2) mod MOD
            inv[8] <= 64'd125000001; // 8^(MOD-2) mod MOD
            inv[9] <= 64'd111111112; // 9^(MOD-2) mod MOD
            inv[10] <= 64'd100000001; // 10^(MOD-2) mod MOD
            inv[11] <= 64'd90909091; // 11^(MOD-2) mod MOD
            inv[12] <= 64'd83333334; // 12^(MOD-2) mod MOD
            inv[13] <= 64'd76923077; // 13^(MOD-2) mod MOD
            inv[14] <= 64'd71428572; // 14^(MOD-2) mod MOD
            inv[15] <= 64'd66666667; // 15^(MOD-2) mod MOD
            inv[16] <= 64'd62500001; // 16^(MOD-2) mod MOD
            inv[17] <= 64'd58823530; // 17^(MOD-2) mod MOD
            inv[18] <= 64'd55555556; // 18^(MOD-2) mod MOD
            inv[19] <= 64'd52631579; // 19^(MOD-2) mod MOD
            inv[20] <= 64'd50000001; // 20^(MOD-2) mod MOD
            inv[21] <= 64'd47619048; // 21^(MOD-2) mod MOD
            inv[22] <= 64'd45454546; // 22^(MOD-2) mod MOD
            inv[23] <= 64'd43478261; // 23^(MOD-2) mod MOD
            inv[24] <= 64'd41666667; // 24^(MOD-2) mod MOD
            inv[25] <= 64'd40000001; // 25^(MOD-2) mod MOD
            inv[26] <= 64'd38461539; // 26^(MOD-2) mod MOD
            inv[27] <= 64'd37037037; // 27^(MOD-2) mod MOD
            inv[28] <= 64'd35714286; // 28^(MOD-2) mod MOD
            inv[29] <= 64'd34482759; // 29^(MOD-2) mod MOD
            inv[30] <= 64'd33333334; // 30^(MOD-2) mod MOD
            inv[31] <= 64'd32258065; // 31^(MOD-2) mod MOD
            inv[32] <= 64'd31250001; // 32^(MOD-2) mod MOD
            inv[33] <= 64'd30303031; // 33^(MOD-2) mod MOD
            inv[34] <= 64'd29411765; // 34^(MOD-2) mod MOD
            inv[35] <= 64'd28571429; // 35^(MOD-2) mod MOD
            inv[36] <= 64'd27777778; // 36^(MOD-2) mod MOD
            inv[37] <= 64'd27027027; // 37^(MOD-2) mod MOD
            inv[38] <= 64'd26315789; // 38^(MOD-2) mod MOD
            inv[39] <= 64'd25641026; // 39^(MOD-2) mod MOD
            inv[40] <= 64'd25000001; // 40^(MOD-2) mod MOD
            inv[41] <= 64'd24390244; // 41^(MOD-2) mod MOD
            inv[42] <= 64'd23809524; // 42^(MOD-2) mod MOD
            inv[43] <= 64'd23255814; // 43^(MOD-2) mod MOD
            inv[44] <= 64'd22727273; // 44^(MOD-2) mod MOD
            inv[45] <= 64'd22222222; // 45^(MOD-2) mod MOD
            inv[46] <= 64'd21739131; // 46^(MOD-2) mod MOD
            inv[47] <= 64'd21276596; // 47^(MOD-2) mod MOD
            inv[48] <= 64'd20833334; // 48^(MOD-2) mod MOD
            inv[49] <= 64'd20408163; // 49^(MOD-2) mod MOD
            inv[50] <= 64'd20000001; // 50^(MOD-2) mod MOD
        end
    end

    // DP loop logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            node <= 6'd0;
            cut <= 6'd0;
            ln <= 6'd0;
            lc <= 6'd0;
            i <= 6'd0;
            tmp <= 64'd0;
            cnt <= 64'd0;
            product <= 64'd0;
        end else if (state == DP_LOOP) begin
            // Outer loop: node from 1 to n
            if (node < n) begin
                // Middle loop: cut from 1 to n
                if (cut < n) begin
                    // Inner loop: ln from 0 to node-1
                    if (ln < node) begin
                        // Inner loop: lc from 0 to cut-1
                        if (lc < cut) begin
                            // Sum tmp += f[ln][lc] * s[node-1-ln][cut-1-lc]
                            tmp <= (tmp + (f[ln][lc] * s[node-1-ln][cut-1-lc]) % MOD) % MOD;
                            lc <= lc + 1'b1;
                        end else begin
                            lc <= 6'd0;
                            ln <= ln + 1'b1;
                        end
                    end else begin
                        ln <= 6'd0;
                        // Calculate cnt
                        if (tmp != 64'd0) begin
                            product <= 64'd1;
                            for (int j = 1; j <= node; j++) begin
                                product <= (product * ((tmp + j - 1) % MOD)) % MOD;
                                product <= (product * inv[j]) % MOD;
                            end
                            cnt <= product;
                        end else begin
                            cnt <= 64'd0;
                        end
                        // Update f[node][cut]
                        f[node][cut] <= (f[node][cut] + cnt) % MOD;
                        cut <= cut + 1'b1;
                    end
                end else begin
                    cut <= 6'd0;
                    // Update s[node][cut]
                    s[node][cut] <= (s[node][cut] + f[node][cut]) % MOD;
                    node <= node + 1'b1;
                end
            end else begin
                // Final result
                result <= f[n][m-1];
            end
        end
    end

endmodule