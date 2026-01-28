module subset_sum_mask (
    input clk, rst_n,
    input start,
    input [3:0] n,
    input [4:0] k,
    input [7:0] coin_in,
    output reg done,
    output reg [16:0] result_mask
);

    parameter MAX_N = 8;
    parameter MAX_K = 16;

    // State encoding
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] PROCESS = 2'b01;
    localparam [1:0] DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] counter, next_counter;
    reg [16:0] dp [0:MAX_K];
    reg [4:0] k_reg;
    reg [3:0] n_reg;
    reg [4:0] s;

    // State and counter update
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
            state <= next_state;
            counter <= next_counter;
            done <= 1'b0;
            result_mask <= 17'd0;
            
            if (state == IDLE && start) begin
                k_reg <= k;
                n_reg <= n;
                for (s = 0; s <= MAX_K; s = s + 1) begin
                    dp[s] <= 17'd0;
                end
                dp[0] <= 17'd1;
            end
            
            if (state == PROCESS) begin
                for (s = 0; s <= MAX_K; s = s + 1) begin
                    if (s < coin_in) begin
                        dp[s] <= dp[s];
                    end else begin
                        if (s >= coin_in && s - coin_in <= MAX_K) begin
                            dp[s] <= dp[s] | dp[s - coin_in] | (dp[s - coin_in] << coin_in);
                        end
                    end
                end
            end
            
            if (state == DONE) begin
                done <= 1'b1;
                if (k_reg <= MAX_K) begin
                    result_mask <= dp[k_reg];
                end else begin
                    result_mask <= 17'd0;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_counter = counter;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    next_counter = 4'd0;
                end
            end
            PROCESS: begin
                next_counter = counter + 4'd1;
                if (counter + 4'd1 >= n_reg) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule