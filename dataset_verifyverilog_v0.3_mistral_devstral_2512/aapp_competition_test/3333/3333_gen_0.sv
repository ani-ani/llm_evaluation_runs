module fox_hiding_distance (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] roost_x,
    input wire [31:0] roost_y,
    input wire [31:0] spot_x [0:7],
    input wire [31:0] spot_y [0:7],
    input wire [3:0] N,
    output reg done,
    output reg [31:0] result
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_DIST_ROOST = 4'd1;
    localparam [3:0] COMPUTE_DIST_SPOT = 4'd2;
    localparam [3:0] DP_INIT = 4'd3;
    localparam [3:0] DP_OUTER = 4'd4;
    localparam [3:0] DP_INNER_I = 4'd5;
    localparam [3:0] DP_INNER_J = 4'd6;
    localparam [3:0] DP_UPDATE = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    // Registers
    reg [3:0] state, next_state;
    reg [3:0] i_cnt, j_cnt;
    reg [7:0] mask;
    reg [7:0] prev_mask;
    reg [7:0] dp_addr;
    reg [31:0] dp_data;
    reg dp_wr_en;
    reg [31:0] dist_roost [0:7];
    reg [31:0] dist_spot [0:7][0:7];
    reg [31:0] dp [0:255];
    reg [31:0] x1, y1, x2, y2;
    reg [31:0] dx, dy, dist_sq;
    reg [31:0] temp_result;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            mask <= 8'd0;
            dp_wr_en <= 1'b0;
            for (integer i = 0; i < 8; i = i + 1) begin
                dist_roost[i] <= 32'd0;
                for (integer j = 0; j < 8; j = j + 1) begin
                    dist_spot[i][j] <= 32'd0;
                end
            end
            for (integer i = 0; i < 256; i = i + 1) begin
                dp[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_DIST_ROOST;
            end
            COMPUTE_DIST_ROOST: begin
                if (i_cnt >= N) next_state = COMPUTE_DIST_SPOT;
            end
            COMPUTE_DIST_SPOT: begin
                if (i_cnt >= N) next_state = DP_INIT;
            end
            DP_INIT: begin
                next_state = DP_OUTER;
            end
            DP_OUTER: begin
                if (mask >= (1 << N)) next_state = DONE_STATE;
                else next_state = DP_INNER_I;
            end
            DP_INNER_I: begin
                if (i_cnt >= N) next_state = DP_OUTER;
                else if (mask[i_cnt]) next_state = DP_INNER_J;
                else next_state = DP_INNER_I;
            end
            DP_INNER_J: begin
                if (j_cnt >= N) next_state = DP_INNER_I;
                else if (j_cnt > i_cnt && mask[j_cnt]) next_state = DP_UPDATE;
                else next_state = DP_INNER_J;
            end
            DP_UPDATE: begin
                next_state = DP_INNER_J;
            end
            DONE_STATE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in state transition
        end else begin
            case (state)
                IDLE: begin
                    i_cnt <= 4'd0;
                    j_cnt <= 4'd0;
                    mask <= 8'd1;
                    done <= 1'b0;
                end
                COMPUTE_DIST_ROOST: begin
                    x1 <= roost_x;
                    y1 <= roost_y;
                    x2 <= spot_x[i_cnt];
                    y2 <= spot_y[i_cnt];
                    dx <= x1 - x2;
                    dy <= y1 - y2;
                    dist_sq <= dx * dx + dy * dy;
                    dist_roost[i_cnt] <= dist_sq;
                    i_cnt <= i_cnt + 4'd1;
                end
                COMPUTE_DIST_SPOT: begin
                    if (i_cnt < N && j_cnt < N && i_cnt != j_cnt) begin
                        x1 <= spot_x[i_cnt];
                        y1 <= spot_y[i_cnt];
                        x2 <= spot_x[j_cnt];
                        y2 <= spot_y[j_cnt];
                        dx <= x1 - x2;
                        dy <= y1 - y2;
                        dist_sq <= dx * dx + dy * dy;
                        dist_spot[i_cnt][j_cnt] <= dist_sq;
                    end
                    if (j_cnt + 4'd1 >= N) begin
                        j_cnt <= 4'd0;
                        i_cnt <= i_cnt + 4'd1;
                    end else begin
                        j_cnt <= j_cnt + 4'd1;
                    end
                end
                DP_INIT: begin
                    dp[0] <= 32'd0;
                    mask <= 8'd1;
                    i_cnt <= 4'd0;
                    j_cnt <= 4'd0;
                end
                DP_OUTER: begin
                    if (mask >= (1 << N)) begin
                        result <= dp[(1 << N) - 1];
                        done <= 1'b1;
                    end else begin
                        dp[mask] <= 32'd0;
                        i_cnt <= 4'd0;
                        j_cnt <= 4'd0;
                    end
                end
                DP_INNER_I: begin
                    if (i_cnt < N) begin
                        if (mask[i_cnt]) begin
                            prev_mask <= mask & ~(1 << i_cnt);
                            temp_result <= dp[prev_mask] + dist_roost[i_cnt] + dist_roost[i_cnt];
                            dp_addr <= mask;
                            dp_data <= temp_result;
                            dp_wr_en <= 1'b1;
                            i_cnt <= i_cnt + 4'd1;
                        end else begin
                            i_cnt <= i_cnt + 4'd1;
                        end
                    end
                end
                DP_INNER_J: begin
                    dp_wr_en <= 1'b0;
                    if (j_cnt < N) begin
                        if (j_cnt > i_cnt && mask[j_cnt]) begin
                            prev_mask <= mask & ~(1 << i_cnt) & ~(1 << j_cnt);
                            temp_result <= dp[prev_mask] + dist_roost[i_cnt] + dist_spot[i_cnt][j_cnt] + dist_roost[j_cnt];
                            dp_addr <= mask;
                            dp_data <= temp_result;
                            dp_wr_en <= 1'b1;
                        end
                        j_cnt <= j_cnt + 4'd1;
                    end else begin
                        j_cnt <= 4'd0;
                        i_cnt <= i_cnt + 4'd1;
                    end
                end
                DP_UPDATE: begin
                    if (dp_wr_en) begin
                        if (dp_data < dp[mask]) begin
                            dp[mask] <= dp_data;
                        end
                        dp_wr_en <= 1'b0;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule