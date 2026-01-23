module smooth_array(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] K,
    input wire [4:0] S,
    input wire [7:0] A0,
    input wire [7:0] A1,
    input wire [7:0] A2,
    input wire [7:0] A3,
    input wire [7:0] A4,
    input wire [7:0] A5,
    input wire [7:0] A6,
    input wire [7:0] A7,
    input wire [7:0] A8,
    input wire [7:0] A9,
    input wire [7:0] A10,
    input wire [7:0] A11,
    input wire [7:0] A12,
    input wire [7:0] A13,
    input wire [7:0] A14,
    input wire [7:0] A15,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] COUNT_FREQ = 4'd2;
    localparam [3:0] DP_INIT = 4'd3;
    localparam [3:0] DP_ITER = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state;
    reg [7:0] array [0:15];
    reg [7:0] freq [0:15][0:16];
    reg [7:0] dp [0:16];
    reg [7:0] new_dp [0:16];
    reg [3:0] i;
    reg [3:0] r;
    reg [4:0] v;
    reg [4:0] s;
    reg [7:0] max_val;
    reg [7:0] temp;
    reg [7:0] profit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            i <= 4'd0;
            r <= 4'd0;
            v <= 5'd0;
            s <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                array[i] <= 8'd0;
            end
            for (r = 0; r < 16; r = r + 1) begin
                for (v = 0; v < 17; v = v + 1) begin
                    freq[r][v] <= 8'd0;
                end
            end
            for (s = 0; s < 17; s = s + 1) begin
                dp[s] <= 8'd0;
                new_dp[s] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    array[0] <= A0;
                    array[1] <= A1;
                    array[2] <= A2;
                    array[3] <= A3;
                    array[4] <= A4;
                    array[5] <= A5;
                    array[6] <= A6;
                    array[7] <= A7;
                    array[8] <= A8;
                    array[9] <= A9;
                    array[10] <= A10;
                    array[11] <= A11;
                    array[12] <= A12;
                    array[13] <= A13;
                    array[14] <= A14;
                    array[15] <= A15;
                    state <= COUNT_FREQ;
                    i <= 4'd0;
                    r <= 4'd0;
                end

                COUNT_FREQ: begin
                    if (i < N) begin
                        r <= i % K;
                        if (array[i] <= S) begin
                            freq[r][array[i]] <= freq[r][array[i]] + 8'd1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        state <= DP_INIT;
                        s <= 5'd0;
                    end
                end

                DP_INIT: begin
                    if (s < 17) begin
                        if (s == 0) begin
                            dp[s] <= 8'd0;
                        end else begin
                            dp[s] <= 8'd255;
                        end
                        s <= s + 5'd1;
                    end else begin
                        state <= DP_ITER;
                        r <= 4'd0;
                        s <= 5'd0;
                        v <= 5'd0;
                    end
                end

                DP_ITER: begin
                    if (r < K) begin
                        if (s < 17) begin
                            if (v < 17) begin
                                if (s >= v) begin
                                    if (dp[s - v] != 8'd255) begin
                                        temp <= dp[s - v] + freq[r][v];
                                        if (temp > new_dp[s]) begin
                                            new_dp[s] <= temp;
                                        end
                                    end
                                end
                                v <= v + 5'd1;
                            end else begin
                                v <= 5'd0;
                                s <= s + 5'd1;
                            end
                        end else begin
                            for (s = 0; s < 17; s = s + 1) begin
                                dp[s] <= new_dp[s];
                                new_dp[s] <= 8'd0;
                            end
                            r <= r + 4'd1;
                            s <= 5'd0;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    profit <= dp[S];
                    if (profit == 8'd255) begin
                        result <= 5'd0;
                    end else begin
                        result <= N - profit;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule