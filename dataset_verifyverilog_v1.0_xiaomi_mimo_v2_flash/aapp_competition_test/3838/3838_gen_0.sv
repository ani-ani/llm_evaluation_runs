module permutation_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] n,        // number of elements (1-100)
    input wire [6:0] k,        // number of moves (1-100)
    input wire [6:0] q [0:99], // permutation q (0-indexed, values 0..n-1)
    input wire [6:0] s [0:99], // permutation s (0-indexed)
    output reg yes,
    output reg done
);
    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] INIT_INV   = 4'd1;
    localparam [3:0] CHECK_ID   = 4'd2;
    localparam [3:0] INIT_PERM  = 4'd3;
    localparam [3:0] CHECK_SAME = 4'd4;
    localparam [3: 0] UPDATE     = 4'd5;
    localparam [3:0] COMPARE    = 4'd6;
    localparam [3:0] INCREMENT  = 4'd7;
    localparam [3:0] UPDATE_BWD = 4'd8;
    localparam [3:0] DONE       = 4'd9;

    reg [3:0] state, next_state;
    reg [6:0] i, j, e;
    reg [6:0] inv_q [0:99];
    reg [6:0] fwd [0:99];
    reg [6:0] bwd [0:99];
    reg match_found;
    reg is_identity;
    reg order_is_two;
    reg s_is_q;
    reg [1:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            yes <= 1'b0;
            done <= 1'b0;
            i <= 7'd0;
            j <= 7'd0;
            e <= 7'd0;
            match_found <= 1'b0;
            is_identity <= 1'b0;
            order_is_two <= 1'b0;
            s_is_q <= 1'b0;
            counter <= 2'd0;
            for (i = 0; i < 8'd100; i = i + 1) begin
                inv_q[i] <= 7'd0;
                fwd[i] <= 7'd0;
                bwd[i] <= 7'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    yes <= 1'b0;
                    match_found <= 1'b0;
                    is_identity <= 1'b0;
                    order_is_two <= 1'b0;
                    s_is_q <= 1'b0;
                    i <= 7'd0;
                    j <= 7'd0;
                    e <= 7'd0;
                    counter <= 2'd0;
                    if (start) begin
                        state <= INIT_INV;
                    end
                end

                INIT_INV: begin
                    // Build inverse: inv_q[q[i]] = i
                    if (i < n) begin
                        inv_q[q[i]] <= i;
                        i <= i + 7'd1;
                    end else begin
                        i <= 7'd0;
                        state <= CHECK_ID;
                    end
                end

                CHECK_ID: begin
                    // Check if s is identity permutation
                    if (i < n) begin
                        if (s[i] != i) begin
                            is_identity <= 1'b0;
                            i <= 7'd0;
                            state <= INIT_PERM;
                        end else begin
                            i <= i + 7'd1;
                        end
                    end else begin
                        // All equal, s is identity
                        is_identity <= 1'b1;
                        i <= 7'd0;
                        state <= INIT_PERM;
                    end
                end

                INIT_PERM: begin
                    // Initialize fwd = identity, bwd = identity
                    if (i < n) begin
                        fwd[i] <= i;
                        bwd[i] <= i;
                        i <= i + 7'd1;
                    end else begin
                        i <= 7'd0;
                        if (is_identity) begin
                            // s is identity
                            if (k == 0) begin
                                yes <= 1'b1;
                            end else begin
                                yes <= 1'b0;
                            end
                            state <= DONE;
                        end else begin
                            state <= CHECK_SAME;
                        end
                    end
                end

                CHECK_SAME: begin
                    // Check if s == q
                    if (i < n) begin
                        if (s[i] != q[i]) begin
                            s_is_q <= 1'b0;
                            i <= 7'd0;
                            e <= 7'd0;
                            state <= UPDATE;
                        end else begin
                            i <= i + 7'd1;
                        end
                    end else begin
                        s_is_q <= 1'b1;
                        i <= 7'd0;
                        e <= 7'd0;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Update fwd = q ∘ fwd
                    if (i < n) begin
                        fwd[i] <= q[fwd[i]];
                        i <= i + 7'd1;
                    end else begin
                        i <= 7'd0;
                        e <= e + 7'd1;
                        counter <= 2'd0;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Check if fwd == s or bwd == s for current e
                    if (counter == 2'd0) begin
                        // Check fwd == s
                        if (i < n) begin
                            if (fwd[i] != s[i]) begin
                                counter <= 2'd1;
                                i <= 7'd0;
                            end else begin
                                i <= i + 7'd1;
                            end
                        end else begin
                            // fwd == s
                            if (e > 0) begin
                                if ((e & 1'b1) == (k & 1'b1)) begin
                                    match_found <= 1'b1;
                                end
                            end
                            counter <= 2'd1;
                            i <= 7'd0;
                        end
                    end else begin
                        // Check bwd == s
                        if (i < n) begin
                            if (bwd[i] != s[i]) begin
                                i <= i + 7'd0;
                                state <= UPDATE_BWD;
                            end else begin
                                i <= i + 7'd1;
                            end
                        end else begin
                            // bwd == s
                            if (e > 0) begin
                                if ((e & 1'b1) == (k & 1'b1)) begin
                                    match_found <= 1'b1;
                                end
                            end
                            state <= UPDATE_BWD;
                        end
                    end
                end

                UPDATE_BWD: begin
                    // Update bwd = inv_q ∘ bwd
                    if (i < n) begin
                        bwd[i] <= inv_q[bwd[i]];
                        i <= i + 7'd1;
                    end else begin
                        i <= 7'd0;
                        // Check termination
                        if (e >= k) begin
                            if (match_found) begin
                                if (s_is_q && k > 1 && (k & 1'b1) == 1'b0) begin
                                    // Special case: s = q, order 2, k even > 1
                                    yes <= 1'b0;
                                end else begin
                                    yes <= 1'b1;
                                end
                            end else begin
                                yes <= 1'b0;
                            end
                            state <= DONE;
                        end else begin
                            state <= UPDATE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule