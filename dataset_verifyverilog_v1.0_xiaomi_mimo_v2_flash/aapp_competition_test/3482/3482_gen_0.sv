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

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [4:0] seg_0, seg_1, seg_2, seg_3, seg_4;
    reg [4:0] away_0, away_1, away_2, away_3;
    reg [9:0] cum_dur_0, cum_dur_1, cum_dur_2, cum_dur_3;
    reg [15:0] dp_0, dp_1, dp_2, dp_3, dp_4, dp_5;
    reg [3:0] m;
    reg [3:0] i, j;
    reg [4:0] L;
    reg [15:0] cost_reg;
    reg [4:0] remaining;
    reg [3:0] level;
    reg [4:0] days_in_level;
    reg [15:0] temp_cost;
    reg [3:0] k;

    // State definitions
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

    // Price and duration arrays
    wire [9:0] p_array [0:3];
    assign p_array[0] = p0;
    assign p_array[1] = p1;
    assign p_array[2] = p2;
    assign p_array[3] = p3;

    wire [3:0] d_array [0:2];
    assign d_array[0] = d0;
    assign d_array[1] = d1;
    assign d_array[2] = d2;

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // State transition and datapath
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_SEGMENTS;
                end
            end

            COMPUTE_SEGMENTS: begin
                // Compute m and segments
                if (n == 4'd0) begin
                    m = 4'd1;
                    seg_0 = t;
                end else begin
                    m = n + 4'd1;
                    seg_0 = away_a0 - 4'd1;
                    if (n >= 4'd1) begin
                        away_0 = away_b0 - away_a0 + 4'd1;
                        if (n >= 4'd2) begin
                            seg_1 = away_a1 - away_b0 - 4'd1;
                            away_1 = away_b1 - away_a1 + 4'd1;
                            if (n >= 4'd3) begin
                                seg_2 = away_a2 - away_b1 - 4'd1;
                                away_2 = away_b2 - away_a2 + 4'd1;
                                if (n == 4'd4) begin
                                    seg_3 = away_a3 - away_b2 - 4'd1;
                                    away_3 = away_b3 - away_a3 + 4'd1;
                                    seg_4 = t - away_b3;
                                end else begin
                                    seg_3 = t - away_b2;
                                end
                            end else begin
                                seg_2 = t - away_b1;
                            end
                        end else begin
                            seg_1 = t - away_b0;
                        end
                    end
                end
                // Compute cumulative durations
                cum_dur_0 = 10'd0;
                if (l >= 4'd2) cum_dur_1 = d0;
                else cum_dur_1 = 10'd0;
                if (l >= 4'd3) cum_dur_2 = d0 + d1;
                else cum_dur_2 = 10'd0;
                if (l >= 4'd4) cum_dur_3 = d0 + d1 + d2;
                else cum_dur_3 = 10'd0;
                next_state = DP_INIT;
            end

            DP_INIT: begin
                dp_0 = 16'd0;
                i = 4'd1;
                next_state = DP_OUTER_LOOP;
            end

            DP_OUTER_LOOP: begin
                if (i <= m) begin
                    if (i == 4'd1) dp_1 = 16'hFFFF;
                    else if (i == 4'd2) dp_2 = 16'hFFFF;
                    else if (i == 4'd3) dp_3 = 16'hFFFF;
                    else if (i == 4'd4) dp_4 = 16'hFFFF;
                    else if (i == 4'd5) dp_5 = 16'hFFFF;
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
                L = 4'd0;
                // Add present segments from j to i
                k = j;
                while (k <= i) begin
                    if (k == 4'd0) L = L + seg_0;
                    else if (k == 4'd1) L = L + seg_1;
                    else if (k == 4'd2) L = L + seg_2;
                    else if (k == 4'd3) L = L + seg_3;
                    else if (k == 4'd4) L = L + seg_4;
                    k = k + 4'd1;
                end
                // Add away segments from j to i-1
                k = j;
                while (k < i) begin
                    if (k == 4'd0) L = L + away_0;
                    else if (k == 4'd1) L = L + away_1;
                    else if (k == 4'd2) L = L + away_2;
                    else if (k == 4'd3) L = L + away_3;
                    k = k + 4'd1;
                end
                next_state = COMPUTE_COST_START;
            end

            COMPUTE_COST_START: begin
                cost_reg = 16'd0;
                remaining = L;
                level = 4'd0;
                next_state = COMPUTE_COST_LEVEL;
            end

            COMPUTE_COST_LEVEL: begin
                if (level < l) begin
                    if (level < l - 4'd1) begin
                        days_in_level = (remaining < d_array[level]) ? remaining : d_array[level];
                    end else begin
                        days_in_level = remaining;
                    end
                    if (level == 4'd0) temp_cost = days_in_level * p0;
                    else if (level == 4'd1) temp_cost = days_in_level * p1;
                    else if (level == 4'd2) temp_cost = days_in_level * p2;
                    else temp_cost = days_in_level * p3;
                    cost_reg = cost_reg + temp_cost;
                    remaining = remaining - days_in_level;
                    level = level + 4'd1;
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
                // Get current dp[j]
                if (j == 4'd0) temp_cost = dp_0;
                else if (j == 4'd1) temp_cost = dp_1;
                else if (j == 4'd2) temp_cost = dp_2;
                else if (j == 4'd3) temp_cost = dp_3;
                else if (j == 4'd4) temp_cost = dp_4;
                else temp_cost = dp_5;
                
                temp_cost = temp_cost + cost_reg;
                
                // Update dp[i] if better
                if (i == 4'd1) begin
                    if (temp_cost < dp_1) dp_1 = temp_cost;
                end else if (i == 4'd2) begin
                    if (temp_cost < dp_2) dp_2 = temp_cost;
                end else if (i == 4'd3) begin
                    if (temp_cost < dp_3) dp_3 = temp_cost;
                end else if (i == 4'd4) begin
                    if (temp_cost < dp_4) dp_4 = temp_cost;
                end else if (i == 4'd5) begin
                    if (temp_cost < dp_5) dp_5 = temp_cost;
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
                if (m == 4'd1) result = dp_1;
                else if (m == 4'd2) result = dp_2;
                else if (m == 4'd3) result = dp_3;
                else if (m == 4'd4) result = dp_4;
                else if (m == 4'd5) result = dp_5;
                else result = dp_1;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 16'd0;
            seg_0 <= 5'd0;
            seg_1 <= 5'd0;
            seg_2 <= 5'd0;
            seg_3 <= 5'd0;
            seg_4 <= 5'd0;
            away_0 <= 5'd0;
            away_1 <= 5'd0;
            away_2 <= 5'd0;
            away_3 <= 5'd0;
            cum_dur_0 <= 10'd0;
            cum_dur_1 <= 10'd0;
            cum_dur_2 <= 10'd0;
            cum_dur_3 <= 10'd0;
            dp_0 <= 16'd0;
            dp_1 <= 16'd0;
            dp_2 <= 16'd0;
            dp_3 <= 16'd0;
            dp_4 <= 16'd0;
            dp_5 <= 16'd0;
            m <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            L <= 5'd0;
            cost_reg <= 16'd0;
            remaining <= 5'd0;
            level <= 4'd0;
            days_in_level <= 5'd0;
            temp_cost <= 16'd0;
            k <= 4'd0;
        end else begin
            if (state == DONE_STATE) begin
                done <= 1'b1;
            end else if (state == IDLE && start) begin
                done <= 1'b0;
            end
        end
    end

endmodule