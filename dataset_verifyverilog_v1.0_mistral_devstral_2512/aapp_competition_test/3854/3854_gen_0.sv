module subset_sum_mask (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] k,
    input [7:0] coin_in,
    output reg done,
    output reg [16:0] result_mask
);

    parameter MAX_N = 8;
    parameter MAX_K = 16;

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] counter;
    reg [4:0] k_reg;
    reg [3:0] n_reg;
    reg [16:0] dp [0:MAX_K];
    integer s;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            k_reg <= 5'd0;
            n_reg <= 4'd0;
            for (s = 0; s <= MAX_K; s = s + 1) begin
                dp[s] <= 17'd0;
            end
            dp[0] <= 17'd1;
            done <= 1'b0;
            result_mask <= 17'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_mask <= 17'd0;
                    if (start) begin
                        state <= PROCESS;
                        counter <= 4'd0;
                        k_reg <= k;
                        n_reg <= n;
                    end
                end
                PROCESS: begin
                    if (counter < n_reg) begin
                        for (s = 0; s <= MAX_K; s = s + 1) begin
                            if (s >= coin_in) begin
                                dp[s] <= dp[s] | (dp[s - coin_in] << coin_in);
                            end
                        end
                        counter <= counter + 4'd1;
                        if (counter == n_reg) begin
                            state <= DONE;
                        end
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    result_mask <= dp[k_reg];
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule