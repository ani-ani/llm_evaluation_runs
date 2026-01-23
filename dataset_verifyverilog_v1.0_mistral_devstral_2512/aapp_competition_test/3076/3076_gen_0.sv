module knapsack_solver(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [3:0] k,
    input [8:0] s_0,
    input [8:0] s_1,
    input [8:0] s_2,
    input [8:0] s_3,
    input [8:0] s_4,
    input [8:0] s_5,
    input [8:0] s_6,
    input [8:0] s_7,
    input [31:0] v_0,
    input [31:0] v_1,
    input [31:0] v_2,
    input [31:0] v_3,
    input [31:0] v_4,
    input [31:0] v_5,
    input [31:0] v_6,
    input [31:0] v_7,
    output reg [31:0] result_1,
    output reg [31:0] result_2,
    output reg [31:0] result_3,
    output reg [31:0] result_4,
    output reg [31:0] result_5,
    output reg [31:0] result_6,
    output reg [31:0] result_7,
    output reg [31:0] result_8,
    output reg [31:0] result_9,
    output reg [31:0] result_10,
    output reg [31:0] result_11,
    output reg [31:0] result_12,
    output reg [31:0] result_13,
    output reg [31:0] result_14,
    output reg [31:0] result_15,
    output reg [31:0] result_16,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RUN = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] jewel_idx;
    reg [3:0] capacity;
    reg [3:0] max_k;
    reg [2:0] max_n;

    reg [31:0] dp [0:16];
    reg [8:0] s_reg [0:7];
    reg [31:0] v_reg [0:7];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            jewel_idx <= 4'd0;
            capacity <= 4'd0;
            max_k <= 4'd0;
            max_n <= 3'd0;
            done <= 1'b0;
            for (i = 0; i < 17; i = i + 1) begin
                dp[i] <= 32'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                s_reg[i] <= 9'd0;
                v_reg[i] <= 32'd0;
            end
            result_1 <= 32'd0;
            result_2 <= 32'd0;
            result_3 <= 32'd0;
            result_4 <= 32'd0;
            result_5 <= 32'd0;
            result_6 <= 32'd0;
            result_7 <= 32'd0;
            result_8 <= 32'd0;
            result_9 <= 32'd0;
            result_10 <= 32'd0;
            result_11 <= 32'd0;
            result_12 <= 32'd0;
            result_13 <= 32'd0;
            result_14 <= 32'd0;
            result_15 <= 32'd0;
            result_16 <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        max_n <= n;
                        max_k <= k;
                        s_reg[0] <= s_0;
                        s_reg[1] <= s_1;
                        s_reg[2] <= s_2;
                        s_reg[3] <= s_3;
                        s_reg[4] <= s_4;
                        s_reg[5] <= s_5;
                        s_reg[6] <= s_6;
                        s_reg[7] <= s_7;
                        v_reg[0] <= v_0;
                        v_reg[1] <= v_1;
                        v_reg[2] <= v_2;
                        v_reg[3] <= v_3;
                        v_reg[4] <= v_4;
                        v_reg[5] <= v_5;
                        v_reg[6] <= v_6;
                        v_reg[7] <= v_7;
                        jewel_idx <= 4'd0;
                        capacity <= max_k;
                        state <= RUN;
                    end
                end

                RUN: begin
                    if (jewel_idx < max_n) begin
                        if (capacity >= s_reg[jewel_idx]) begin
                            if (dp[capacity] < dp[capacity - s_reg[jewel_idx]] + v_reg[jewel_idx]) begin
                                dp[capacity] <= dp[capacity - s_reg[jewel_idx]] + v_reg[jewel_idx];
                            end
                            capacity <= capacity - 4'd1;
                        end else begin
                            capacity <= capacity - 4'd1;
                        end
                        if (capacity == 4'd0) begin
                            jewel_idx <= jewel_idx + 4'd1;
                            capacity <= max_k;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result_1 <= dp[1];
                    result_2 <= dp[2];
                    result_3 <= dp[3];
                    result_4 <= dp[4];
                    result_5 <= dp[5];
                    result_6 <= dp[6];
                    result_7 <= dp[7];
                    result_8 <= dp[8];
                    result_9 <= dp[9];
                    result_10 <= dp[10];
                    result_11 <= dp[11];
                    result_12 <= dp[12];
                    result_13 <= dp[13];
                    result_14 <= dp[14];
                    result_15 <= dp[15];
                    result_16 <= dp[16];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule