module compute_F(
    input clk,
    input rst_n,
    input start,
    input [3:0] x,
    input [3:0] y,
    output reg [31:0] result,
    output reg done
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    localparam [31:0] MOD = 32'd1000000007;
    
    reg [1:0] state, next_state;
    reg [3:0] i, j;
    reg [31:0] dp [0:8];
    reg [31:0] dp_next [0:8];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (k = 0; k < 9; k = k + 1) begin
                dp[k] <= 32'd0;
                dp_next[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            if (state == COMPUTE) begin
                cycle_count <= cycle_count + 8'd1;
                
                if (i == 4'd0 && j == 4'd0) begin
                    dp_next[0] <= 32'd0;
                end else if (i == 4'd0 && j == 4'd1) begin
                    dp_next[1] <= 32'd1;
                end else if (i == 4'd1 && j == 4'd0) begin
                    dp_next[0] <= 32'd1;
                end else if (i >= 4'd2 && j == 4'd0) begin
                    dp_next[0] <= (dp[0] + dp[1]) % MOD;
                end else if (i == 4'd0 && j >= 4'd2) begin
                    dp_next[j] <= (dp[j] + dp[j-1]) % MOD;
                end else if (i >= 4'd1 && j >= 4'd1) begin
                    dp_next[j] <= (dp[j] + dp[j-1]) % MOD;
                end
                
                if (j == y) begin
                    if (i == x) begin
                        next_state <= DONE_STATE;
                        result <= dp_next[y];
                    end else begin
                        i <= i + 4'd1;
                        j <= 4'd0;
                        for (k = 0; k < 9; k = k + 1) begin
                            dp[k] <= dp_next[k];
                        end
                    end
                end else begin
                    j <= j + 4'd1;
                    for (k = 0; k < 9; k = k + 1) begin
                        dp[k] <= dp_next[k];
                    end
                end
            end else if (state == DONE_STATE) begin
                done <= 1'b1;
                next_state <= IDLE;
            end else begin
                done <= 1'b0;
            end
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = COMPUTE;
                    i = 4'd0;
                    j = 4'd0;
                    cycle_count = 8'd0;
                    for (k = 0; k < 9; k = k + 1) begin
                        dp[k] = 32'd0;
                        dp_next[k] = 32'd0;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule