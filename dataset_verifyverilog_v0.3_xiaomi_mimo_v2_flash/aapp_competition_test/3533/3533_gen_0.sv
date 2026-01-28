module min_toll (
    input clk,
    input rst_n,
    input start,
    input [7:0] entrances [0:7],
    input [7:0] exits [0:7],
    output reg [15:0] result,
    output reg done
);

    parameter N = 8;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT_ENTRANCES = 3'd1;
    localparam [2:0] SORT_EXITS = 3'd2;
    localparam [2:0] DP_INIT = 3'd3;
    localparam [2:0] DP_COMPUTE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state;
    reg [7:0] sorted_entrances [0:7];
    reg [7:0] sorted_exits [0:7];
    reg [15:0] dp [0:8];
    reg [3:0] i;
    reg [3:0] sort_i, sort_j;
    reg [7:0] temp;
    reg [2:0] swap_count;
    reg swap_flag;

    localparam [15:0] INF = 16'hFFFF;

    function [15:0] abs_diff;
        input [7:0] a;
        input [7:0] b;
        begin
            if (a > b)
                abs_diff = a - b;
            else
                abs_diff = b - a;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            i <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            temp <= 8'd0;
            swap_count <= 3'd0;
            swap_flag <= 1'b0;
            for (integer k = 0; k < 8; k = k + 1) begin
                sorted_entrances[k] <= 8'd0;
                sorted_exits[k] <= 8'd0;
                dp[k] <= 16'd0;
            end
            dp[8] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        for (integer k = 0; k < 8; k = k + 1) begin
                            sorted_entrances[k] <= entrances[k];
                            sorted_exits[k] <= exits[k];
                        end
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        state <= SORT_ENTRANCES;
                    end
                end

                SORT_ENTRANCES: begin
                    if (sort_i < 3'd7) begin
                        if (sort_j < 3'd6 - sort_i) begin
                            if (sorted_entrances[sort_j] > sorted_entrances[sort_j + 1]) begin
                                temp <= sorted_entrances[sort_j];
                                sorted_entrances[sort_j] <= sorted_entrances[sort_j + 1];
                                sorted_entrances[sort_j + 1] <= temp;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        state <= SORT_EXITS;
                    end
                end

                SORT_EXITS: begin
                    if (sort_i < 3'd7) begin
                        if (sort_j < 3'd6 - sort_i) begin
                            if (sorted_exits[sort_j] > sorted_exits[sort_j + 1]) begin
                                temp <= sorted_exits[sort_j];
                                sorted_exits[sort_j] <= sorted_exits[sort_j + 1];
                                sorted_exits[sort_j + 1] <= temp;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    dp[0] <= 16'd0;
                    if (sorted_entrances[0] != sorted_exits[0])
                        dp[1] <= abs_diff(sorted_entrances[0], sorted_exits[0]);
                    else
                        dp[1] <= INF;
                    i <= 4'd1;
                    state <= DP_COMPUTE;
                end

                DP_COMPUTE: begin
                    if (i < 4'd8) begin
                        reg [15:0] option1;
                        reg [15:0] option2;
                        reg [15:0] option3;
                        reg [15:0] option4;

                        option1 = INF;
                        option2 = INF;
                        option3 = INF;
                        option4 = INF;

                        if (sorted_entrances[i] != sorted_exits[i]) begin
                            option1 = dp[i] + abs_diff(sorted_entrances[i], sorted_exits[i]);
                        end

                        if (i >= 1) begin
                            if (sorted_entrances[i] != sorted_exits[i-1] && sorted_entrances[i-1] != sorted_exits[i]) begin
                                option2 = dp[i-1] + abs_diff(sorted_entrances[i], sorted_exits[i-1]) + abs_diff(sorted_entrances[i-1], sorted_exits[i]);
                            end
                        end

                        if (i >= 2) begin
                            if (sorted_entrances[i] != sorted_exits[i-2] && sorted_entrances[i-1] != sorted_exits[i] && sorted_entrances[i-2] != sorted_exits[i-1]) begin
                                option3 = dp[i-2] + abs_diff(sorted_entrances[i], sorted_exits[i-2]) + abs_diff(sorted_entrances[i-1], sorted_exits[i]) + abs_diff(sorted_entrances[i-2], sorted_exits[i-1]);
                            end
                        end

                        if (i >= 2) begin
                            if (sorted_entrances[i] != sorted_exits[i-1] && sorted_entrances[i-1] != sorted_exits[i-2] && sorted_entrances[i-2] != sorted_exits[i]) begin
                                option4 = dp[i-2] + abs_diff(sorted_entrances[i], sorted_exits[i-1]) + abs_diff(sorted_entrances[i-1], sorted_exits[i-2]) + abs_diff(sorted_entrances[i-2], sorted_exits[i]);
                            end
                        end

                        dp[i+1] <= option1;
                        if (option2 < dp[i+1]) dp[i+1] <= option2;
                        if (option3 < dp[i+1]) dp[i+1] <= option3;
                        if (option4 < dp[i+1]) dp[i+1] <= option4;

                        i <= i + 4'd1;
                    end else begin
                        result <= dp[8];
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule