module max_revenue (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [9:0] S_0,
    input [9:0] S_1,
    input [9:0] S_2,
    input [9:0] S_3,
    input [9:0] S_4,
    input [9:0] S_5,
    input [9:0] S_6,
    input [9:0] S_7,
    input [9:0] S_8,
    input [9:0] S_9,
    input [9:0] S_10,
    input [9:0] S_11,
    input [9:0] S_12,
    input [9:0] S_13,
    output reg [6:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT_START   = 4'd1;
    localparam [3:0] INIT_SUM     = 4'd2;
    localparam [3:0] INIT_OMEGA   = 4'd3;
    localparam [3:0] INIT_NEXT    = 4'd4;
    localparam [3:0] DP_START     = 4'd5;
    localparam [3:0] DP_OUTER     = 4'd6;
    localparam [3:0] DP_INNER     = 4'd7;
    localparam [3:0] DP_NEXT      = 4'd8;
    localparam [3:0] DP_STORE     = 4'd9;
    localparam [3:0] DONE         = 4'd10;

    reg [3:0] state, next_state;

    // Constants
    localparam [13:0] MAX_MASK = 14'd16383;
    localparam [3:0] MAX_N = 4'd14;

    // Control signals
    reg [13:0] mask_reg, next_mask_reg;
    reg [13:0] sub_reg, next_sub_reg;
    reg [6:0] max_val_reg, next_max_val_reg;
    reg [6:0] candidate_val_reg, next_candidate_val_reg;
    reg [13:0] lsb_idx_reg, next_lsb_idx_reg;
    reg [13:0] prev_mask_reg, next_prev_mask_reg;

    // Prime list (primes up to 118)
    wire [6:0] prime_list [0:29];
    assign prime_list[0] = 7'd2;
    assign prime_list[1] = 7'd3;
    assign prime_list[2] = 7'd5;
    assign prime_list[3] = 7'd7;
    assign prime_list[4] = 7'd11;
    assign prime_list[5] = 7'd13;
    assign prime_list[6] = 7'd17;
    assign prime_list[7] = 7'd19;
    assign prime_list[8] = 7'd23;
    assign prime_list[9] = 7'd29;
    assign prime_list[10] = 7'd31;
    assign prime_list[11] = 7'd37;
    assign prime_list[12] = 7'd41;
    assign prime_list[13] = 7'd43;
    assign prime_list[14] = 7'd47;
    assign prime_list[15] = 7'd53;
    assign prime_list[16] = 7'd59;
    assign prime_list[17] = 7'd61;
    assign prime_list[18] = 7'd67;
    assign prime_list[19] = 7'd71;
    assign prime_list[20] = 7'd73;
    assign prime_list[21] = 7'd79;
    assign prime_list[22] = 7'd83;
    assign prime_list[23] = 7'd89;
    assign prime_list[24] = 7'd97;
    assign prime_list[25] = 7'd101;
    assign prime_list[26] = 7'd103;
    assign prime_list[27] = 7'd107;
    assign prime_list[28] = 7'd109;
    assign prime_list[29] = 7'd113;

    // Memory arrays (packed for synthesis compatibility)
    reg [13:0] subset_sum [0:16383];
    reg [2:0] subset_omega [0:16383];
    reg [6:0] dp [0:16383];

    // Omega computation state
    reg [2:0] omega_reg, next_omega_reg;
    reg [4:0] prime_idx_reg, next_prime_idx_reg;

    // Initialize memory indices
    integer i;

    // S array lookup
    wire [9:0] S_array [0:13];
    assign S_array[0] = S_0;
    assign S_array[1] = S_1;
    assign S_array[2] = S_2;
    assign S_array[3] = S_3;
    assign S_array[4] = S_4;
    assign S_array[5] = S_5;
    assign S_array[6] = S_6;
    assign S_array[7] = S_7;
    assign S_array[8] = S_8;
    assign S_array[9] = S_9;
    assign S_array[10] = S_10;
    assign S_array[11] = S_11;
    assign S_array[12] = S_12;
    assign S_array[13] = S_13;

    // Find lsb index
    reg [13:0] lsb_val;
    always @(*) begin
        lsb_val = 0;
        lsb_val[0] = (mask_reg[0] == 1'b1);
        lsb_val[1] = (mask_reg[1] == 1'b1);
        lsb_val[2] = (mask_reg[2] == 1'b1);
        lsb_val[3] = (mask_reg[3] == 1'b1);
        lsb_val[4] = (mask_reg[4] == 1'b1);
        lsb_val[5] = (mask_reg[5] == 1'b1);
        lsb_val[6] = (mask_reg[6] == 1'b1);
        lsb_val[7] = (mask_reg[7] == 1'b1);
        lsb_val[8] = (mask_reg[8] == 1'b1);
        lsb_val[9] = (mask_reg[9] == 1'b1);
        lsb_val[10] = (mask_reg[10] == 1'b1);
        lsb_val[11] = (mask_reg[11] == 1'b1);
        lsb_val[12] = (mask_reg[12] == 1'b1);
        lsb_val[13] = (mask_reg[13] == 1'b1);
    end

    // DP computation: get sum for submask
    wire [13:0] sub_sum;
    assign sub_sum = subset_sum[sub_reg];

    // DP computation: get omega for submask
    wire [2:0] sub_omega;
    assign sub_omega = subset_omega[sub_reg];

    // DP computation: get dp for (mask ^ sub)
    wire [6:0] dp_prev;
    assign dp_prev = dp[mask_reg ^ sub_reg];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask_reg <= 14'd0;
            sub_reg <= 14'd0;
            max_val_reg <= 7'd0;
            candidate_val_reg <= 7'd0;
            lsb_idx_reg <= 14'd0;
            prev_mask_reg <= 14'd0;
            omega_reg <= 3'd0;
            prime_idx_reg <= 5'd0;
            result <= 7'd0;
            done <= 1'b0;
            // Initialize memories to zero
            for (i = 0; i < 16384; i = i + 1) begin
                subset_sum[i] <= 14'd0;
                subset_omega[i] <= 3'd0;
                dp[i] <= 7'd0;
            end
        end else begin
            state <= next_state;
            mask_reg <= next_mask_reg;
            sub_reg <= next_sub_reg;
            max_val_reg <= next_max_val_reg;
            candidate_val_reg <= next_candidate_val_reg;
            lsb_idx_reg <= next_lsb_idx_reg;
            prev_mask_reg <= next_prev_mask_reg;
            omega_reg <= next_omega_reg;
            prime_idx_reg <= next_prime_idx_reg;
            // Output logic
            if (state == DONE) begin
                result <= dp[{{14-N}{1'b1}}];
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    always @(*) begin
        // Default assignments
        next_state = state;
        next_mask_reg = mask_reg;
        next_sub_reg = sub_reg;
        next_max_val_reg = max_val_reg;
        next_candidate_val_reg = candidate_val_reg;
        next_lsb_idx_reg = lsb_idx_reg;
        next_prev_mask_reg = prev_mask_reg;
        next_omega_reg = omega_reg;
        next_prime_idx_reg = prime_idx_reg;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_START;
                    next_mask_reg = 14'd1;
                end
            end

            INIT_START: begin
                // Mask is set from IDLE or INIT_NEXT
                if (mask_reg == MAX_MASK) begin
                    next_state = DP_START;
                end else begin
                    next_state = INIT_SUM;
                    // Compute prev_mask = mask_reg without lsb
                    next_prev_mask_reg = mask_reg;
                    // Find lsb index
                    next_lsb_idx_reg = 14'd0;
                    if (mask_reg[0]) next_lsb_idx_reg = 14'd0;
                    else if (mask_reg[1]) next_lsb_idx_reg = 14'd1;
                    else if (mask_reg[2]) next_lsb_idx_reg = 14'd2;
                    else if (mask_reg[3]) next_lsb_idx_reg = 14'd3;
                    else if (mask_reg[4]) next_lsb_idx_reg = 14'd4;
                    else if (mask_reg[5]) next_lsb_idx_reg = 14'd5;
                    else if (mask_reg[6]) next_lsb_idx_reg = 14'd6;
                    else if (mask_reg[7]) next_lsb_idx_reg = 14'd7;
                    else if (mask_reg[8]) next_lsb_idx_reg = 14'd8;
                    else if (mask_reg[9]) next_lsb_idx_reg = 14'd9;
                    else if (mask_reg[10]) next_lsb_idx_reg = 14'd10;
                    else if (mask_reg[11]) next_lsb_idx_reg = 14'd11;
                    else if (mask_reg[12]) next_lsb_idx_reg = 14'd12;
                    else if (mask_reg[13]) next_lsb_idx_reg = 14'd13;
                end
            end

            INIT_SUM: begin
                // Compute subset_sum[mask] = subset_sum[prev_mask without lsb] + S[lsb_idx]
                next_state = INIT_OMEGA;
                next_omega_reg = 3'd0;
                next_prime_idx_reg = 5'd0;
            end

            INIT_OMEGA: begin
                // Check divisibility by current prime
                if (prime_idx_reg < 5'd30) begin
                    if (prime_list[prime_idx_reg] < S_array[lsb_idx_reg]) begin
                        if (S_array[lsb_idx_reg] % prime_list[prime_idx_reg] == 0) begin
                            next_omega_reg = omega_reg + 3'd1;
                        end
                        next_prime_idx_reg = prime_idx_reg + 5'd1;
                    end else begin
                        // Prime is larger than value, done
                        next_state = INIT_NEXT;
                    end
                end else begin
                    next_state = INIT_NEXT;
                end
            end

            INIT_NEXT: begin
                next_mask_reg = mask_reg + 14'd1;
                next_state = INIT_START;
            end

            DP_START: begin
                next_mask_reg = 14'd1;
                next_state = DP_OUTER;
            end

            DP_OUTER: begin
                if (mask_reg == MAX_MASK) begin
                    next_state = DONE;
                end else begin
                    next_sub_reg = mask_reg;
                    next_max_val_reg = 7'd0;
                    next_state = DP_INNER;
                end
            end

            DP_INNER: begin
                if (sub_reg != 14'd0) begin
                    // candidate = dp[mask ^ sub] + subset_omega[sub]
                    next_candidate_val_reg = dp_prev + {4'd0, sub_omega};
                    if (candidate_val_reg > max_val_reg) begin
                        next_max_val_reg = candidate_val_reg;
                    end
                    next_sub_reg = (sub_reg - 14'd1) & mask_reg;
                end else begin
                    next_state = DP_STORE;
                end
            end

            DP_STORE: begin
                // dp[mask] = max_val_reg
                next_mask_reg = mask_reg + 14'd1;
                next_state = DP_OUTER;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule