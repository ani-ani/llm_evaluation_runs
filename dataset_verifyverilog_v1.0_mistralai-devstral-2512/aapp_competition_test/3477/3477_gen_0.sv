module kmeans_1d(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] k [0:7],
    input wire [1:0] m,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Prefix sums
    reg [15:0] sum_k [0:8];
    reg [23:0] sum_w [0:8];
    
    // DP table
    reg [23:0] dp [0:8][0:3];
    
    // Loop counters
    reg [2:0] i, j, t;
    reg [23:0] min_cost;
    reg [23:0] current_cost;
    reg [15:0] delta_k;
    reg [23:0] delta_w;
    reg [23:0] cost;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            for (i = 0; i < 8; i = i + 1) begin
                sum_k[i] <= 16'd0;
                sum_w[i] <= 24'd0;
            end
            sum_k[8] <= 16'd0;
            sum_w[8] <= 24'd0;
            
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    dp[i][j] <= 24'd0;
                end
            end
            
            i <= 3'd0;
            j <= 3'd0;
            t <= 3'd0;
            min_cost <= 24'd0;
            current_cost <= 24'd0;
            delta_k <= 16'd0;
            delta_w <= 24'd0;
            cost <= 24'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PRECOMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PRECOMPUTE: begin
                    // Compute prefix sums
                    sum_k[0] <= 16'd0;
                    sum_w[0] <= 24'd0;
                    for (i = 1; i <= 8; i = i + 1) begin
                        sum_k[i] <= sum_k[i-1] + k[i-1];
                        sum_w[i] <= sum_w[i-1] + (i-1) * k[i-1];
                    end
                    next_state <= DP_INIT;
                end

                DP_INIT: begin
                    // Initialize DP table
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 3; j = j + 1) begin
                            dp[i][j] <= 24'd0;
                        end
                    end
                    next_state <= DP_COMPUTE;
                    i <= 3'd0;
                    j <= 3'd0;
                end

                DP_COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (i == 0 && j == 0) begin
                        dp[0][0] <= 24'd0;
                        i <= i + 3'd1;
                        if (i >= 8) begin
                            i <= 3'd0;
                            j <= j + 3'd1;
                        end
                    end else if (i < 8 && j < m) begin
                        // Compute dp[i][j]
                        min_cost <= 24'd0;
                        for (t = 0; t < i; t = t + 1) begin
                            delta_k <= sum_k[i] - sum_k[t];
                            delta_w <= sum_w[i] - sum_w[t];
                            
                            if (delta_k == 16'd0) begin
                                cost <= 24'd0;
                            end else begin
                                cost <= (delta_w * delta_w * 256) / delta_k;
                            end
                            
                            current_cost <= dp[t][j-1] + cost;
                            
                            if (t == 0 || current_cost < min_cost) begin
                                min_cost <= current_cost;
                            end
                        end
                        dp[i][j] <= min_cost;
                        
                        // Move to next state
                        i <= i + 3'd1;
                        if (i >= 8) begin
                            i <= 3'd0;
                            j <= j + 3'd1;
                        end
                        
                        if (j >= m) begin
                            next_state <= OUTPUT;
                        end
                    end else begin
                        next_state <= OUTPUT;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result <= dp[8][m] >> 8;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule