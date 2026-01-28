module JazzBandTour(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] tour_seg [0:7],
    input wire [1:0] ticket_s [0:7],
    input wire [1:0] ticket_d [0:7],
    input wire ticket_t [0:7],
    input wire [15:0] ticket_p [0:7],
    output reg [31:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PREP = 2'd1;
    localparam [1:0] DP_LOOP = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [7:0] mask;
    reg [7:0] next_mask;
    reg [31:0] dp [0:255];
    reg [31:0] min_cost;
    reg [31:0] temp_cost;
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] k;
    reg [7:0] seg_idx;
    reg [7:0] rev_seg_idx;
    reg [1:0] src;
    reg [1:0] dest;
    reg [1:0] rev_src;
    reg [1:0] rev_dest;
    reg [1:0] current_city;
    reg [1:0] next_city;
    reg [1:0] tour [0:7];
    reg [1:0] ticket_s_reg [0:7];
    reg [1:0] ticket_d_reg [0:7];
    reg ticket_t_reg [0:7];
    reg [15:0] ticket_p_reg [0:7];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 256; i = i + 1) begin
                dp[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            tour[i] <= tour_seg[i];
                            ticket_s_reg[i] <= ticket_s[i];
                            ticket_d_reg[i] <= ticket_d[i];
                            ticket_t_reg[i] <= ticket_t[i];
                            ticket_p_reg[i] <= ticket_p[i];
                        end
                        state <= PREP;
                    end
                end

                PREP: begin
                    for (i = 0; i < 256; i = i + 1) begin
                        dp[i] <= 32'd0;
                    end
                    dp[0] <= 32'd0;
                    for (i = 1; i < 256; i = i + 1) begin
                        dp[i] <= 32'd0;
                    end
                    mask <= 8'd0;
                    state <= DP_LOOP;
                end

                DP_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        if (mask == 8'd255) begin
                            state <= DONE_STATE;
                        end else begin
                            min_cost <= 32'd0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (!mask[i]) begin
                                    seg_idx <= i;
                                    current_city <= tour[seg_idx];
                                    if (seg_idx < 7) begin
                                        next_city <= tour[seg_idx + 1];
                                    end else begin
                                        next_city <= 2'd0;
                                    end

                                    for (j = 0; j < 8; j = j + 1) begin
                                        src <= ticket_s_reg[j];
                                        dest <= ticket_d_reg[j];
                                        if (src == current_city && dest == next_city) begin
                                            if (!ticket_t_reg[j]) begin
                                                temp_cost <= dp[mask] + ticket_p_reg[j];
                                                if (min_cost == 32'd0 || temp_cost < min_cost) begin
                                                    min_cost <= temp_cost;
                                                end
                                            end
                                        end
                                    end

                                    for (j = 0; j < 8; j = j + 1) begin
                                        src <= ticket_s_reg[j];
                                        dest <= ticket_d_reg[j];
                                        if (src == current_city && dest == next_city && ticket_t_reg[j]) begin
                                            temp_cost <= dp[mask] + ticket_p_reg[j];
                                            if (min_cost == 32'd0 || temp_cost < min_cost) begin
                                                min_cost <= temp_cost;
                                            end
                                        end
                                    end

                                    for (j = 0; j < 8; j = j + 1) begin
                                        src <= ticket_s_reg[j];
                                        dest <= ticket_d_reg[j];
                                        if (src == current_city && dest == next_city && ticket_t_reg[j]) begin
                                            for (k = seg_idx + 1; k < 8; k = k + 1) begin
                                                rev_src <= tour[k];
                                                rev_dest <= tour[k + 1];
                                                if (rev_src == dest && rev_dest == src && !mask[k]) begin
                                                    temp_cost <= dp[mask] + ticket_p_reg[j];
                                                    if (min_cost == 32'd0 || temp_cost < min_cost) begin
                                                        min_cost <= temp_cost;
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    if (min_cost != 32'd0) begin
                                        next_mask <= mask;
                                        next_mask[seg_idx] <= 1'b1;
                                        dp[next_mask] <= min_cost;
                                    end
                                end
                            end
                            mask <= mask + 8'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= dp[8'd255];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule