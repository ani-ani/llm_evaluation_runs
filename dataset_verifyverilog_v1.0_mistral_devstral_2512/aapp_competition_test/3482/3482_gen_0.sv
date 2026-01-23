module transit_card (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] l,
    input wire [9:0] p0, p1, p2, p3,
    input wire [3:0] d0, d1, d2,
    input wire [3:0] n,
    input wire [3:0] away_a0, away_a1, away_a2, away_a3,
    input wire [3:0] away_b0, away_b1, away_b2, away_b3,
    input wire [4:0] t,
    output reg [15:0] result,
    output reg done
);

    reg [3:0] state;
    reg [3:0] next_state;

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_SEGMENTS = 4'd1;
    localparam [3:0] DP_INIT = 4'd2;
    localparam [3:0] DP_OUTER_LOOP = 4'd3;
    localparam [3:0] DP_INNER_LOOP = 4'd4;
    localparam [3:0] COMPUTE_LENGTH = 4'd5;
    localparam [3:0] COMPUTE_COST_START = 4'd6;
    localparam [3:0] COMPUTE_COST_LEVEL = 4'd7;
    localparam [3:0] UPDATE_DP = 4'd8;
    localparam [3:0] NEXT_J = 4'd9;
    localparam [3:0] NEXT_I = 4'd10;
    localparam [3:0] DONE_STATE = 4'd11;

    reg [4:0] seg [0:4];
    reg [4:0] away [0:3];
    reg [9:0] cum_dur [0:3];
    reg [15:0] dp [0:5];
    reg [3:0] m;
    reg [3:0] i, j;
    reg [4:0] L;
    reg [15:0] cost_reg;
    reg [4:0] remaining;
    reg [3:0] level;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            level <= 3'd0;
            L <= 5'd0;
            cost_reg <= 16'd0;
            remaining <= 5'd0;
            m <= 4'd0;
            for (integer k = 0; k < 5; k = k + 1) begin
                seg[k] <= 5'd0;
            end
            for (integer k = 0; k < 4; k = k + 1) begin
                away[k] <= 5'd0;
            end
            for (integer k = 0; k < 4; k = k + 1) begin
                cum_dur[k] <= 10'd0;
            end
            for (integer k = 0; k < 6; k = k + 1) begin
                dp[k] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_SEGMENTS;
                end
            end

            COMPUTE_SEGMENTS: begin
                if (n == 4'd0) begin
                    m = 4'd1;
                    seg[0] = t;
                end else begin
                    m = n + 4'd1;
                    seg[0] = away_a0 - 4'd1;
                    if (n >= 4'd1) begin
                        away[0] = away_b0 - away_a0 + 4'd1;
                        if (n >= 4'd2) begin
                            seg[1] = away_a1 - away_b0 - 4'd1;
                            away[1] = away_b1 - away_a1 + 4'd1;
                            if (n >= 4'd3) begin
                                seg[2] = away_a2 - away_b1 - 4'd1;
                                away[2] = away_b2 - away_a2 + 4'd1;
                                if (n >= 4'd4) begin
                                    seg[3] = away_a3 - away_b2 - 4'd1;
                                    away[3] = away_b3 - away_a3 + 4'd1;
                                    seg[4] = t - away_b3;
                                end else begin
                                    seg[3] = t - away_b2;
                                end
                            end else begin
                                seg[2] = t - away_b1;
                            end
                        end else begin
                            seg[1] = t - away_b0;
                        end
                    end
                end
                cum_dur[0] = 10'd0;
                if (l >= 4'd2) cum_dur[1] = d0;
                if (l >= 4'd3) cum_dur[2] = d0 + d1;
                if (l >= 4'd4) cum_dur[3] = d0 + d1 + d2;
                next_state = DP_INIT;
            end

            DP_INIT: begin
                dp[0] = 16'd0;
                i = 4'd1;
                next_state = DP_OUTER_LOOP;
            end

            DP_OUTER_LOOP: begin
                if (i <= m) begin
                    dp[i] = 16'hFFFF;
                    j = 4'd0;
                    next_state = DP_INNER_LOOP;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DP_INNER_LOOP: begin
                if (j < i) begin
                    next_state = COMPUTE_LENGTH;
                end else begin
                    next_state = NEXT_I;
                end
            end

            COMPUTE_LENGTH: begin
                L = 5'd0;
                for (integer k = 0; k < i; k = k + 1) begin
                    if (k >= j) begin
                        L = L + seg[k];
                    end
                end
                for (integer k = 0; k < i; k = k + 1) begin
                    if (k >= j) begin
                        L = L + away[k];
                    end
                end
                next_state = COMPUTE_COST_START;
            end

            COMPUTE_COST_START: begin
                cost_reg = 16'd0;
                remaining = L;
                level = 3'd0;
                next_state = COMPUTE_COST_LEVEL;
            end

            COMPUTE_COST_LEVEL: begin
                if (level < l) begin
                    reg [4:0] days_in_level;
                    if (level < l - 4'd1) begin
                        if (remaining < d0) begin
                            days_in_level = remaining;
                        end else begin
                            days_in_level = d0;
                        end
                    end else begin
                        days_in_level = remaining;
                    end
                    if (level == 3'd0) begin
                        cost_reg = cost_reg + days_in_level * p0;
                    end else if (level == 3'd1) begin
                        cost_reg = cost_reg + days_in_level * p1;
                    end else if (level == 3'd2) begin
                        cost_reg = cost_reg + days_in_level * p2;
                    end else if (level == 3'd3) begin
                        cost_reg = cost_reg + days_in_level * p3;
                    end
                    remaining = remaining - days_in_level;
                    level = level + 3'd1;
                    if (remaining > 4'd0 && level < l) begin
                        next_state = COMPUTE_COST_LEVEL;
                    end else begin
                        next_state = UPDATE_DP;
                    end
                end else begin
                    next_state = UPDATE_DP;
                end
            end

            UPDATE_DP: begin
                if (dp[j] + cost_reg < dp[i]) begin
                    dp[i] = dp[j] + cost_reg;
                end
                next_state = NEXT_J;
            end

            NEXT_J: begin
                j = j + 4'd1;
                next_state = DP_INNER_LOOP;
            end

            NEXT_I: begin
                i = i + 4'd1;
                next_state = DP_OUTER_LOOP;
            end

            DONE_STATE: begin
                result = dp[m];
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule