module permutation_game (
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
    // States
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT_INV    = 3'd1;
    localparam [2:0] INIT_PERM   = 3'd2;
    localparam [2:0] CHECK       = 3'd3;
    localparam [2:0] COMPARE     = 3'd4;
    localparam [2:0] UPDATE      = 3'd5;
    localparam [2:0] INCREMENT   = 3'd6;
    localparam [2:0] DONE_STATE  = 3'd7;

    reg [2:0] state, next_state;
    reg [6:0] e_reg;
    reg [6:0] inv_q [0:99];
    reg [6:0] fwd [0:99];
    reg [6:0] bwd [0:99];
    reg [6:0] temp_fwd [0:99];
    reg [6:0] temp_bwd [0:99];
    reg [6:0] identity [0:99];
    reg match_found;
    reg equal_start;
    reg is_identity;
    reg order2;
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            yes <= 1'b0;
            done <= 1'b0;
            e_reg <= 7'd0;
            match_found <= 1'b0;
            equal_start <= 1'b0;
            is_identity <= 1'b0;
            order2 <= 1'b0;
            for (i = 0; i < 100; i = i + 1) begin
                inv_q[i] <= 7'd0;
                fwd[i] <= 7'd0;
                bwd[i] <= 7'd0;
                temp_fwd[i] <= 7'd0;
                temp_bwd[i] <= 7'd0;
                identity[i] <= 7'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT_INV;
                    end
                end

                INIT_INV: begin
                    for (i = 0; j < 100; j = j + 1) begin
                        inv_q[j] <= 7'd0;
                    end
                    for (i = 0; i < n; i = i + 1) begin
                        inv_q[q[i]] <= i;
                    end
                    next_state <= INIT_PERM;
                end

                INIT_PERM: begin
                    for (i = 0; i < n; i = i + 1) begin
                        fwd[i] <= i;
                        bwd[i] <= i;
                        identity[i] <= i;
                    end
                    e_reg <= 7'd0;
                    order2 <= 1'b1;
                    next_state <= CHECK;
                end

                CHECK: begin
                    // Check if s is identity
                    is_identity <= 1'b1;
                    for (i = 0; i < n; i = i + 1) begin
                        if (s[i] != identity[i]) begin
                            is_identity <= 1'b0;
                        end
                    end
                    // Check q^2 order
                    if (order2) begin
                        for (i = 0; i < n; i = i + 1) begin
                            if (q[q[i]] != identity[i]) begin
                                order2 <= 1'b0;
                            end
                        end
                    end
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    if (is_identity) begin
                        yes <= 1'b0;
                        match_found <= 1'b0;
                        next_state <= DONE_STATE;
                    end else if (e_reg != 7'd0 && (e_reg % 7'd2) == (k % 7'd2)) begin
                        // Compare fwd and bwd with s
                        match_found <= 1'b1;
                        for (i = 0; i < n; i = i + 1) begin
                            if (fwd[i] != s[i] && bwd[i] != s[i]) begin
                                match_found <= 1'b0;
                            end
                        end
                        if (e_reg == k) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= UPDATE;
                        end
                    end else if (e_reg == k) begin
                        match_found <= 1'b0;
                        next_state <= DONE_STATE;
                    end else begin
                        match_found <= 1'b0;
                        next_state <= UPDATE;
                    end
                end

                UPDATE: begin
                    if (order2 && k > 7'd1 && (fwd[0] == s[0])) begin
                        yes <= 1'b1;
                        next_state <= DONE_STATE;
                    end else begin
                        for (i = 0; i < n; i = i + 1) begin
                            temp_fwd[i] <= q[fwd[i]];
                            temp_bwd[i] <= inv_q[bwd[i]];
                        end
                        next_state <= INCREMENT;
                    end
                end

                INCREMENT: begin
                    for (i = 0; i < n; i = i + 1) begin
                        fwd[i] <= temp_fwd[i];
                        bwd[i] <= temp_bwd[i];
                    end
                    e_reg <= e_reg + 7'd1;
                    next_state <= COMPARE;
                end

                DONE_STATE: begin
                    yes <= match_found;
                    done <= 1'b1;
                    if (!start) next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule