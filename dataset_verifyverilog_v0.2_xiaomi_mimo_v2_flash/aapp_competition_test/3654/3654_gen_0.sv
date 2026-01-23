module mta_rock_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [15:0] n,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam CHECK_LAWN = 4'd1;
    localparam COMPUTE_SEQUENCE = 4'd2;
    localparam VERIFY_RECTANGLE = 4'd3;
    localparam VERIFY_DIVIDE = 4'd4;
    localparam VERIFY_CHECK_Q = 4'd5;
    localparam UPDATE_COUNT = 4'd6;
    localparam DONE = 4'd7;
    localparam ITERATE_NEXT = 4'd8;

    reg [3:0] state;
    reg [15:0] n_cnt;          // Current iteration counter (1 to n)
    reg [15:0] current_F;
    reg [15:0] prev_F;
    reg [7:0] k_reg;
    reg [15:0] n_reg;
    
    // Factorization variables
    reg [7:0] p_idx;           // Index into prime table
    reg [7:0] current_p;       // Current prime to test
    reg [15:0] q_val;          // Calculated q = F/p
    
    // Prime lookup table (ROM) - primes up to 255
    reg [7:0] prime_table [0:61];
    
    // Initialize prime table (using initial block)
    integer i;
    initial begin
        prime_table[0] = 2;
        prime_table[1] = 3;
        prime_table[2] = 5;
        prime_table[3] = 7;
        prime_table[4] = 11;
        prime_table[5] = 13;
        prime_table[6] = 17;
        prime_table[7] = 19;
        prime_table[8] = 23;
        prime_table[9] = 29;
        prime_table[10] = 31;
        prime_table[11] = 37;
        prime_table[12] = 41;
        prime_table[13] = 43;
        prime_table[14] = 47;
        prime_table[15] = 53;
        prime_table[16] = 59;
        prime_table[17] = 61;
        prime_table[18] = 67;
        prime_table[19] = 71;
        prime_table[20] = 73;
        prime_table[21] = 79;
        prime_table[22] = 83;
        prime_table[23] = 89;
        prime_table[24] = 97;
        prime_table[25] = 101;
        prime_table[26] = 103;
        prime_table[27] = 107;
        prime_table[28] = 109;
        prime_table[29] = 113;
        prime_table[30] = 127;
        prime_table[31] = 131;
        prime_table[32] = 137;
        prime_table[33] = 139;
        prime_table[34] = 149;
        prime_table[35] = 151;
        prime_table[36] = 157;
        prime_table[37] = 163;
        prime_table[38] = 167;
        prime_table[39] = 173;
        prime_table[40] = 179;
        prime_table[41] = 181;
        prime_table[42] = 191;
        prime_table[43] = 193;
        prime_table[44] = 197;
        prime_table[45] = 199;
        prime_table[46] = 211;
        prime_table[47] = 223;
        prime_table[48] = 227;
        prime_table[49] = 229;
        prime_table[50] = 233;
        prime_table[51] = 239;
        prime_table[52] = 241;
        prime_table[53] = 251;
        prime_table[54] = 257;
        prime_table[55] = 263;
        prime_table[56] = 269;
        prime_table[57] = 271;
        prime_table[58] = 277;
        prime_table[59] = 281;
        prime_table[60] = 283;
        prime_table[61] = 293;
    end

    // Prime check logic - combinational
    reg is_prime_p;
    reg is_prime_q;
    reg [7:0] check_val;
    
    always @(*) begin
        // Check if check_val is in prime_table
        is_prime_p = 1'b0;
        is_prime_q = 1'b0;
        
        // Simple combinational lookup (linear search for synthesis)
        // Since table is small, this is acceptable
        for (i = 0; i <= 61; i = i + 1) begin
            if (prime_table[i] == current_p) begin
                is_prime_p = 1'b1;
            end
            if (prime_table[i] == q_val[7:0] && q_val[15:8] == 8'b0) begin
                is_prime_q = 1'b1;
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            n_cnt <= 16'd0;
            current_F <= 16'd0;
            prev_F <= 16'd0;
            k_reg <= 8'd0;
            n_reg <= 16'd0;
            p_idx <= 8'd0;
            current_p <= 8'd0;
            q_val <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        k_reg <= k;
                        n_reg <= n;
                        result <= 8'd0;
                        n_cnt <= 16'd1;
                        // F_k(1) = 42
                        current_F <= 16'd42;
                        prev_F <= 16'd0; // F_k(0) undefined, but unused for n=1
                        state <= CHECK_LAWN;
                    end
                end

                CHECK_LAWN: begin
                    // Check if we've processed all lawns
                    if (n_cnt > n_reg) begin
                        state <= DONE;
                    end else begin
                        // Reset prime search
                        p_idx <= 8'd0;
                        current_p <= prime_table[0];
                        state <= VERIFY_RECTANGLE;
                    end
                end

                VERIFY_RECTANGLE: begin
                    // Get current prime
                    current_p <= prime_table[p_idx];
                    state <= VERIFY_DIVIDE;
                end

                VERIFY_DIVIDE: begin
                    // Check if p^2 > current_F to stop searching
                    // Using approximation: if current_p * current_p > current_F
                    // For synthesis, we'll just check if p_idx reached end or p > current_F
                    if (p_idx > 61 || current_p > current_F[7:0] || (current_p != 0 && current_p > current_F / current_p)) begin
                        // No valid factorization found
                        state <= UPDATE_COUNT;
                    end else begin
                        // Calculate q = F / p
                        if (current_p != 0) begin
                            q_val <= current_F / current_p;
                        end else begin
                            q_val <= 16'd0;
                        end
                        state <= VERIFY_CHECK_Q;
                    end
                end

                VERIFY_CHECK_Q: begin
                    // Check if division is exact and q is prime
                    if (current_p != 0 && current_F % current_p == 0 && q_val[15:8] == 8'b0 && is_prime_q && current_p != q_val[7:0]) begin
                        // Valid wonderful rectangle found
                        result <= result + 1;
                        state <= UPDATE_COUNT;
                    end else begin
                        // Try next prime
                        p_idx <= p_idx + 8'd1;
                        state <= VERIFY_RECTANGLE;
                    end
                end

                UPDATE_COUNT: begin
                    n_cnt <= n_cnt + 16'd1;
                    // Compute next F_k(n)
                    if (n_cnt == 16'd1) begin
                        // F_k(2) = 11*k + 77
                        current_F <= 16'd11 * k_reg + 16'd77;
                        prev_F <= 16'd42; // F_k(1)
                    end else if (n_cnt >= 16'd2 && n_cnt < n_reg) begin
                        // F_k(n) = 2*F_k(n-1) - F_k(n-2) + 10*k
                        current_F <= (current_F << 1) - prev_F + (k_reg << 3) + (k_reg << 1);
                        prev_F <= current_F;
                    end
                    state <= CHECK_LAWN;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
