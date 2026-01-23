module mirko_wins (
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    output reg [29:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] PRECOMP = 3'b001;
    localparam [2:0] ITERATE = 3'b010;
    localparam [2:0] COUNT = 3'b011;
    localparam [2:0] DONE = 3'b100;

    reg [2:0] state = IDLE;
    reg [29:0] sum = 0;
    reg [18:0] mask = 0; // 2^(N-1) max 2^19 = 524,288
    reg [4:0] mask_idx = 0; // Current partition being checked
    reg [4:0] pair_a = 0;
    reg [4:0] pair_b = 0;
    reg [4:0] pair_count = 0;
    reg [4:0] compatible_count = 0;
    reg [4:0] bit_count = 0;
    reg [4:0] gcd_a = 0;
    reg [4:0] gcd_b = 0;
    reg [4:0] gcd_temp = 0;
    reg [4:0] gcd_rem = 0;
    reg [4:0] gcd_div = 0;
    reg [4:0] gcd_quot = 0;
    reg [4:0] gcd_step = 0;
    reg gcd_done = 0;
    reg [19:0] valid_pairs = 0; // Bitmask of valid pairs (a,b)
    reg [4:0] precomp_a = 0;
    reg [4:0] precomp_b = 0;
    reg [4:0] precomp_idx = 0;
    reg precomp_done = 0;

    // GCD computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_a <= 0;
            gcd_b <= 0;
            gcd_temp <= 0;
            gcd_rem <= 0;
            gcd_div <= 0;
            gcd_quot <= 0;
            gcd_step <= 0;
            gcd_done <= 0;
        end else if (state == PRECOMP && !precomp_done) begin
            case (gcd_step)
                0: begin // Initialize
                    gcd_a <= precomp_a;
                    gcd_b <= precomp_b;
                    gcd_temp <= precomp_a;
                    gcd_rem <= precomp_b;
                    gcd_div <= precomp_b;
                    gcd_quot <= 0;
                    gcd_step <= 1;
                end
                1: begin // Division step
                    if (gcd_temp >= gcd_div) begin
                        gcd_temp <= gcd_temp - gcd_div;
                        gcd_quot <= gcd_quot + 1;
                    end else begin
                        gcd_rem <= gcd_temp;
                        gcd_temp <= gcd_div;
                        gcd_div <= gcd_rem;
                        if (gcd_rem == 0) begin
                            gcd_done <= 1;
                            gcd_step <= 0;
                        end else begin
                            gcd_step <= 1;
                        end
                    end
                end
            endcase
        end
    end

    // Precompute valid pairs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            precomp_a <= 0;
            precomp_b <= 0;
            precomp_idx <= 0;
            precomp_done <= 0;
            valid_pairs <= 0;
        end else if (state == PRECOMP && !precomp_done) begin
            if (!gcd_done) begin
                // Wait for GCD to complete
            end else begin
                if (gcd_rem == 1) begin
                    // gcd(a,b) == 1, mark as valid
                    valid_pairs[precomp_idx] <= 1;
                end
                // Move to next pair
                precomp_b <= precomp_b + 1;
                if (precomp_b > N) begin
                    precomp_a <= precomp_a + 1;
                    precomp_b <= precomp_a + 1;
                end
                precomp_idx <= precomp_idx + 1;
                if (precomp_a == N-1 && precomp_b == N) begin
                    precomp_done <= 1;
                end else begin
                    gcd_done <= 0;
                end
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum <= 0;
            mask <= 0;
            mask_idx <= 0;
            pair_a <= 0;
            pair_b <= 0;
            pair_count <= 0;
            compatible_count <= 0;
            bit_count <= 0;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PRECOMP;
                        precomp_a <= 1;
                        precomp_b <= 2;
                        precomp_idx <= 0;
                        precomp_done <= 0;
                        valid_pairs <= 0;
                    end
                end
                PRECOMP: begin
                    if (precomp_done) begin
                        state <= ITERATE;
                        mask <= 0;
                        mask_idx <= 0;
                        pair_a <= 1;
                        pair_b <= 2;
                        pair_count <= 0;
                        compatible_count <= 0;
                        bit_count <= 0;
                    end
                end
                ITERATE: begin
                    if (mask_idx == N-1) begin
                        state <= COUNT;
                        pair_a <= 1;
                        pair_b <= 2;
                        pair_count <= 0;
                        compatible_count <= 0;
                    end else begin
                        mask_idx <= mask_idx + 1;
                    end
                end
                COUNT: begin
                    if (pair_count == (N*(N-1)/2 - 1)) begin
                        // Update sum based on inclusion-exclusion
                        if (bit_count % 2 == 0) begin
                            sum <= sum + (1 << compatible_count);
                        end else begin
                            sum <= sum - (1 << compatible_count);
                        end
                        // Move to next mask
                        mask <= mask + 1;
                        if (mask == (1 << (N-1)) - 1) begin
                            state <= DONE;
                        end else begin
                            state <= ITERATE;
                            mask_idx <= 0;
                            pair_a <= 1;
                            pair_b <= 2;
                            pair_count <= 0;
                            compatible_count <= 0;
                            bit_count <= 0;
                        end
                    end else begin
                        // Check if pair is compatible with current mask
                        if (valid_pairs[pair_count]) begin
                            if ((pair_b < mask_idx + 2) || (pair_a >= mask_idx + 2)) begin
                                compatible_count <= compatible_count + 1;
                            end
                        end
                        // Move to next pair
                        pair_b <= pair_b + 1;
                        if (pair_b > N) begin
                            pair_a <= pair_a + 1;
                            pair_b <= pair_a + 1;
                        end
                        pair_count <= pair_count + 1;
                    end
                end
                DONE: begin
                    done <= 1;
                    result <= sum % 1000000000;
                end
            endcase
        end
    end

    // Count bits in mask
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 0;
        end else if (state == ITERATE && mask_idx == 0) begin
            bit_count <= 0;
        end else if (state == ITERATE) begin
            if (mask[mask_idx]) begin
                bit_count <= bit_count + 1;
            end
        end
    end

endmodule