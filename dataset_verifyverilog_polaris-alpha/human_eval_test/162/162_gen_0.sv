module md5_single_block(
    input        clk,
    input        rst_n,
    input        start,
    input [511:0] blk,
    output reg [127:0] hash,
    output reg   done
);

    // MD5 initial values
    localparam [31:0] A0 = 32'h67452301;
    localparam [31:0] B0 = 32'hefcdab89;
    localparam [31:0] C0 = 32'h98badcfe;
    localparam [31:0] D0 = 32'h10325476;

    // K constants (T[i])
    localparam [31:0] K [0:63] = '{
        32'hd76aa478, 32'he8c7b756, 32'h242070db, 32'hc1bdceee,
        32'hf57c0faf, 32'h4787c62a, 32'ha8304613, 32'hfd469501,
        32'h698098d8, 32'h8b44f7af, 32'hffff5bb1, 32'h895cd7be,
        32'h6b901122, 32'hfd987193, 32'ha679438e, 32'h49b40821,
        32'hf61e2562, 32'hc040b340, 32'h265e5a51, 32'he9b6c7aa,
        32'hd62f105d, 32'h02441453, 32'hd8a1e681, 32'he7d3fbc8,
        32'h21e1cde6, 32'hc33707d6, 32'hf4d50d87, 32'h455a14ed,
        32'ha9e3e905, 32'hfcefa3f8, 32'h676f02d9, 32'h8d2a4c8a,
        32'hfffa3942, 32'h8771f681, 32'h6d9d6122, 32'hfde5380c,
        32'ha4beea44, 32'h4bdecfa9, 32'hf6bb4b60, 32'hbebfbc70,
        32'h289b7ec6, 32'heaa127fa, 32'hd4ef3085, 32'h04881d05,
        32'hd9d4d039, 32'he6db99e5, 32'h1fa27cf8, 32'hc4ac5665,
        32'hf4292244, 32'h432aff97, 32'hab9423a7, 32'hfc93a039,
        32'h655b59c3, 32'h8f0ccc92, 32'hffeff47d, 32'h85845dd1,
        32'h6fa87e4f, 32'hfe2ce6e0, 32'ha3014314, 32'h4e0811a1,
        32'hf7537e82, 32'hbd3af235, 32'h2ad7d2bb, 32'heb86d391
    };

    // s shift amounts
    localparam [4:0] S [0:63] = '{
        7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
        5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
        4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
        6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21
    };

    // Internal block words (little-endian 32-bit words)
    reg [31:0] M [0:15];

    // Working state
    reg [31:0] A_reg, B_reg, C_reg, D_reg;
    reg [31:0] A_next, B_next, C_next, D_next;

    // Latched initial state for final addition
    reg [31:0] A_init, B_init, C_init, D_init;

    // Round counter (0..63)
    reg [6:0] round;

    // Control: busy when processing
    reg busy;

    // Combinational helpers
    reg [31:0] F_val;
    reg [31:0] msg_word;
    reg [31:0] temp;
    reg [5:0]  g; // index into M

    // Combinational MD5 round logic
    always @* begin
        // Default next state is current
        A_next = A_reg;
        B_next = B_reg;
        C_next = C_reg;
        D_next = D_reg;

        F_val  = 32'd0;
        msg_word = 32'd0;
        g = 6'd0;
        temp = 32'd0;

        if (busy) begin
            // Select function F and word index g according to round
            if (round < 16) begin
                F_val = (B_reg & C_reg) | ((~B_reg) & D_reg);
                g = round[5:0];
            end
            else if (round < 32) begin
                F_val = (D_reg & B_reg) | ((~D_reg) & C_reg);
                g = (5*round + 1) & 6'h0F; // mod 16
            end
            else if (round < 48) begin
                F_val = B_reg ^ C_reg ^ D_reg;
                g = (3*round + 5) & 6'h0F; // mod 16
            end
            else begin
                F_val = C_reg ^ (B_reg | (~D_reg));
                g = (7*round) & 6'h0F; // mod 16
            end

            msg_word = M[g[3:0]];

            // temp = B + leftrotate( A + F + K[i] + M[g], s[i] )
            temp = A_reg + F_val + K[round] + msg_word;
            temp = (temp << S[round]) | (temp >> (32 - S[round]));
            temp = B_reg + temp;

            // Next registers: rotate (D,C,B,temp)
            A_next = D_reg;
            B_next = temp;
            C_next = B_reg;
            D_next = C_reg;
        end
    end

    // Sequential control and state updates
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset: set to initial MD5 values and idle
            A_reg <= A0;
            B_reg <= B0;
            C_reg <= C0;
            D_reg <= D0;

            A_init <= A0;
            B_init <= B0;
            C_init <= C0;
            D_init <= D0;

            round  <= 7'd0;
            busy   <= 1'b0;
            done   <= 1'b0;
            hash   <= 128'd0;

            for (i = 0; i < 16; i = i + 1) begin
                M[i] <= 32'd0;
            end
        end else begin
            if (start && !busy && !done) begin
                // Latch the input block (512 bits) into 16x32-bit words, little-endian per word
                // blk[31:0] is word0 LSB-first, etc.
                M[0]  <= blk[ 31:  0];
                M[1]  <= blk[ 63: 32];
                M[2]  <= blk[ 95: 64];
                M[3]  <= blk[127: 96];
                M[4]  <= blk[159:128];
                M[5]  <= blk[191:160];
                M[6]  <= blk[223:192];
                M[7]  <= blk[255:224];
                M[8]  <= blk[287:256];
                M[9]  <= blk[319:288];
                M[10] <= blk[351:320];
                M[11] <= blk[383:352];
                M[12] <= blk[415:384];
                M[13] <= blk[447:416];
                M[14] <= blk[479:448];
                M[15] <= blk[511:480];

                // Initialize working variables from IV
                A_reg <= A0;
                B_reg <= B0;
                C_reg <= C0;
                D_reg <= D0;

                // Save initial for final addition
                A_init <= A0;
                B_init <= B0;
                C_init <= C0;
                D_init <= D0;

                round <= 7'd0;
                busy  <= 1'b1;
                // done remains unchanged (per requirement: stays high until reset)

            end else if (busy) begin
                // Perform one round per cycle
                A_reg <= A_next;
                B_reg <= B_next;
                C_reg <= C_next;
                D_reg <= D_next;

                if (round == 7'd63) begin
                    // Completed 64 rounds in this cycle; compute final hash next state
                    busy <= 1'b0;
                    // As per MD5: add initial values
                    hash[ 31:  0] <= A_next + A_init;
                    hash[ 63: 32] <= B_next + B_init;
                    hash[ 95: 64] <= C_next + C_init;
                    hash[127: 96] <= D_next + D_init;
                    done <= 1'b1; // remains high until reset
                    round <= 7'd0;
                end else begin
                    round <= round + 7'd1;
                end
            end
            // If not start and not busy: hold state; done stays asserted once set
        end
    end

endmodule