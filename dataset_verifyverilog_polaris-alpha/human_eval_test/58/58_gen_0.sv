module sorted_common_elements(
    input              clk,
    input              rst_n,
    input              start,
    input      [15:0]  l1 [0:7],
    input      [15:0]  l2 [0:7],
    input      [3:0]   len1,
    input      [3:0]   len2,
    output reg [15:0]  result [0:7],
    output reg [3:0]   result_len,
    output reg         done
);

    // Stage 0: latch inputs and generate common-elements (deduplicated, order-preserving)
    reg [15:0]  l1_reg [0:7];
    reg [15:0]  l2_reg [0:7];
    reg [3:0]   len1_reg;
    reg [3:0]   len2_reg;

    reg [15:0]  common_raw [0:7];
    reg [3:0]   common_raw_len;

    // Combinational generation of common elements with deduplication
    integer i,j,k;
    reg match_found;
    reg duplicate;

    always @(*) begin
        // Default
        for (k = 0; k < 8; k = k + 1) begin
            common_raw[k] = 16'd0;
        end
        common_raw_len = 4'd0;

        // Traverse l1 in order to maintain original order for dedup
        for (i = 0; i < 8; i = i + 1) begin
            if (i < len1_reg) begin
                // Check if l1_reg[i] exists in l2_reg[0:len2_reg-1]
                match_found = 1'b0;
                for (j = 0; j < 8; j = j + 1) begin
                    if ((j < len2_reg) && (l1_reg[i] == l2_reg[j])) begin
                        match_found = 1'b1;
                    end
                end

                if (match_found) begin
                    // Deduplication against already collected common_raw
                    duplicate = 1'b0;
                    for (k = 0; k < 8; k = k + 1) begin
                        if ((k < common_raw_len) && (common_raw[k] == l1_reg[i])) begin
                            duplicate = 1'b1;
                        end
                    end
                    if (!duplicate && (common_raw_len < 8)) begin
                        common_raw[common_raw_len] = l1_reg[i];
                        common_raw_len = common_raw_len + 1'b1;
                    end
                end
            end
        end
    end

    // Stage 1: combinational sorting network for up to 8 elements (ascending)
    // We sort common_raw into sorted_out using a fixed network of compare-and-swap.

    reg [15:0] s0 [0:7];
    reg [15:0] s1 [0:7];
    reg [15:0] s2 [0:7];
    reg [15:0] s3 [0:7];
    reg [15:0] s4 [0:7];
    reg [15:0] s5 [0:7];
    reg [15:0] s6 [0:7];
    reg [15:0] s7 [0:7];

    integer idx;

    // Helper compare-swap task (combinational)
    task automatic cswap;
        input  [15:0] a_in;
        input  [15:0] b_in;
        output [15:0] a_out;
        output [15:0] b_out;
        begin
            if (a_in > b_in) begin
                a_out = b_in;
                b_out = a_in;
            end else begin
                a_out = a_in;
                b_out = b_in;
            end
        end
    endtask

    always @(*) begin
        // Initialize with common_raw; positions beyond common_raw_len are padded high
        for (idx = 0; idx < 8; idx = idx + 1) begin
            if (idx < common_raw_len)
                s0[idx] = common_raw[idx];
            else
                s0[idx] = 16'hFFFF; // sentinel large value to keep them at end
        end

        // Sorting network for 8 elements (bitonic-like / known network)
        // Stage A
        cswap(s0[0], s0[1], s1[0], s1[1]);
        cswap(s0[2], s0[3], s1[2], s1[3]);
        cswap(s0[4], s0[5], s1[4], s1[5]);
        cswap(s0[6], s0[7], s1[6], s1[7]);

        // Stage B
        cswap(s1[0], s1[2], s2[0], s2[2]);
        cswap(s1[1], s1[3], s2[1], s2[3]);
        cswap(s1[4], s1[6], s2[4], s2[6]);
        cswap(s1[5], s1[7], s2[5], s2[7]);

        // Stage C
        cswap(s2[1], s2[2], s3[1], s3[2]);
        cswap(s2[5], s2[6], s3[5], s3[6]);
        // pass-through others
        s3[0] = s2[0];
        s3[3] = s2[3];
        s3[4] = s2[4];
        s3[7] = s2[7];

        // Stage D
        cswap(s3[0], s3[4], s4[0], s4[4]);
        cswap(s3[1], s3[5], s4[1], s4[5]);
        cswap(s3[2], s3[6], s4[2], s4[6]);
        cswap(s3[3], s3[7], s4[3], s4[7]);

        // Stage E
        cswap(s4[2], s4[4], s5[2], s5[4]);
        cswap(s4[3], s4[5], s5[3], s5[5]);
        // pass-through others
        s5[0] = s4[0];
        s5[1] = s4[1];
        s5[6] = s4[6];
        s5[7] = s4[7];

        // Stage F
        cswap(s5[1], s5[2], s6[1], s6[2]);
        cswap(s5[3], s5[4], s6[3], s6[4]);
        cswap(s5[5], s5[6], s6[5], s6[6]);
        // pass-through
        s6[0] = s5[0];
        s6[7] = s5[7];

        // Stage G
        cswap(s6[0], s6[1], s7[0], s7[1]);
        cswap(s6[2], s6[3], s7[2], s7[3]);
        cswap(s6[4], s6[5], s7[4], s7[5]);
        cswap(s6[6], s6[7], s7[6], s7[7]);
    end

    // Stage 2: sequential pipeline and handshake
    // Latch inputs, run combinational common+sort in same cycle, outputs next cycle.

    integer m;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state: clear outputs and regs
            len1_reg      <= 4'd0;
            len2_reg      <= 4'd0;
            for (m = 0; m < 8; m = m + 1) begin
                l1_reg[m]   <= 16'd0;
                l2_reg[m]   <= 16'd0;
                result[m]   <= 16'd0;
            end
            result_len     <= 4'd0;
            done           <= 1'b0;
        end else begin
            // Default done low; pulsed high one cycle after start
            done <= 1'b0;

            if (start) begin
                // Latch inputs
                len1_reg <= (len1 > 4'd8) ? 4'd8 : len1;
                len2_reg <= (len2 > 4'd8) ? 4'd8 : len2;
                for (m = 0; m < 8; m = m + 1) begin
                    l1_reg[m] <= l1[m];
                    l2_reg[m] <= l2[m];
                end

                // Use already-formed combinational s7/common_raw_len as result next cycle
                // Here we capture the sorted outputs and length for current cycle's inputs
                for (m = 0; m < 8; m = m + 1) begin
                    if (m < common_raw_len)
                        result[m] <= s7[m];
                    else
                        result[m] <= 16'd0;
                end
                result_len <= common_raw_len;

                // Signal completion (valid next clock cycle as per spec)
                done <= 1'b1;
            end
        end
    end

endmodule