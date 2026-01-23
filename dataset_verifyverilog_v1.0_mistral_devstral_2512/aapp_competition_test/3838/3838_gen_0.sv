module permutation_game(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] n,
    input wire [6:0] k,
    input wire [6:0] q [0:99],
    input wire [6:0] s [0:99],
    output reg yes,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] INIT_INV    = 4'd1;
    localparam [3:0] INIT_PERM   = 4'd2;
    localparam [3:0] CHECK       = 4'd3;
    localparam [3:0] COMPARE     = 4'd4;
    localparam [3:0] UPDATE      = 4'd5;
    localparam [3:0] INCREMENT   = 4'd6;
    localparam [3:0] DONE_STATE  = 4'd7;

    reg [3:0] state, next_state;
    reg [6:0] e;                  // Current move counter
    reg [6:0] inv_q [0:99];      // Inverse permutation of q
    reg [6:0] fwd [0:99];       // Forward permutation
    reg [6:0] bwd [0:99];       // Backward permutation
    reg [6:0] i, j;              // Loop counters
    reg is_identity;             // Flag if s is identity
    reg is_special;              // Flag for special case
    reg [6:0] order;             // Order of permutation q

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            e <= 7'd0;
            yes <= 1'b0;
            done <= 1'b0;
            is_identity <= 1'b0;
            is_special <= 1'b0;
            order <= 7'd0;
            for (i = 0; i < 100; i = i + 1) begin
                inv_q[i] <= 7'd0;
                fwd[i] <= 7'd0;
                bwd[i] <= 7'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                yes <= 1'b0;
                e <= 7'd0;
                is_identity <= 1'b0;
                is_special <= 1'b0;
                order <= 7'd0;

                // Check if s is identity
                for (i = 0; i < n; i = i + 1) begin
                    if (s[i] != i) begin
                        is_identity = 1'b0;
                    end
                end

                if (is_identity) begin
                    yes <= 1'b0;
                    next_state = DONE_STATE;
                end else if (start) begin
                    next_state = INIT_INV;
                end
            end

            INIT_INV: begin
                // Compute inverse permutation inv_q
                for (i = 0; i < n; i = i + 1) begin
                    inv_q[q[i]] = i;
                end

                // Initialize fwd and bwd
                for (i = 0; i < n; i = i + 1) begin
                    fwd[i] = i;
                    bwd[i] = i;
                end

                // Check if q is identity
                reg is_q_identity;
                is_q_identity = 1'b1;
                for (i = 0; i < n; i = i + 1) begin
                    if (q[i] != i) begin
                        is_q_identity = 1'b0;
                    end
                end

                if (is_q_identity) begin
                    // If q is identity, check if s is identity (already handled)
                    // or if k == 0 (but k >= 1 per spec)
                    yes <= 1'b0;
                    next_state = DONE_STATE;
                end else begin
                    next_state = INIT_PERM;
                end
            end

            INIT_PERM: begin
                // Check if s == q and k > 1 (special case)
                reg s_equals_q;
                s_equals_q = 1'b1;
                for (i = 0; i < n; i = i + 1) begin
                    if (s[i] != q[i]) begin
                        s_equals_q = 1'b0;
                    end
                end

                if (s_equals_q && k > 1) begin
                    is_special = 1'b1;
                end

                // Compute order of q (find smallest m where q^m = identity)
                reg [6:0] temp [0:99];
                reg [6:0] m;
                for (m = 1; m <= n; m = m + 1) begin
                    // Compute q^m
                    for (i = 0; i < n; i = i + 1) begin
                        temp[i] = i;
                    end
                    for (j = 0; j < m; j = j + 1) begin
                        for (i = 0; i < n; i = i + 1) begin
                            temp[i] = q[temp[i]];
                        end
                    end

                    // Check if q^m is identity
                    reg is_identity_temp;
                    is_identity_temp = 1'b1;
                    for (i = 0; i < n; i = i + 1) begin
                        if (temp[i] != i) begin
                            is_identity_temp = 1'b0;
                        end
                    end

                    if (is_identity_temp) begin
                        order = m;
                        break;
                    end
                end

                next_state = CHECK;
            end

            CHECK: begin
                if (e == k) begin
                    next_state = COMPARE;
                end else begin
                    next_state = UPDATE;
                end
            end

            COMPARE: begin
                // Compare fwd and bwd with s
                reg fwd_equals_s, bwd_equals_s;
                fwd_equals_s = 1'b1;
                bwd_equals_s = 1'b1;

                for (i = 0; i < n; i = i + 1) begin
                    if (fwd[i] != s[i]) begin
                        fwd_equals_s = 1'b0;
                    end
                    if (bwd[i] != s[i]) begin
                        bwd_equals_s = 1'b0;
                    end
                end

                if (fwd_equals_s || bwd_equals_s) begin
                    if (e == k) begin
                        yes <= 1'b1;
                    end else begin
                        yes <= 1'b0;
                    end
                end else begin
                    yes <= 1'b0;
                end

                next_state = DONE_STATE;
            end

            UPDATE: begin
                // Update fwd = q ∘ fwd
                for (i = 0; i < n; i = i + 1) begin
                    fwd[i] = q[fwd[i]];
                end

                // Update bwd = inv_q ∘ bwd
                for (i = 0; i < n; i = i + 1) begin
                    bwd[i] = inv_q[bwd[i]];
                end

                next_state = INCREMENT;
            end

            INCREMENT: begin
                e = e + 7'd1;
                next_state = CHECK;
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule