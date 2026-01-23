module string_compression(
    input clk,
    input rst_n,
    input start,
    input [7:0] s0, s1, s2, s3, s4, s5, s6, s7,
    input [15:0] a, b,
    input [3:0] n,
    output reg [15:0] min_cost,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers to store inputs
    reg [7:0] s_reg [0:7];
    reg [15:0] a_reg, b_reg;
    reg [3:0] n_reg;

    // Internal tables for LCP and DP
    reg [3:0] lcp [0:8][0:8];  // 9x9 to avoid boundary issues
    reg [3:0] maxL [0:7];
    reg [15:0] dp [0:8];

    // Combinational logic for computation
    always @(*) begin
        // Initialize LCP table to zero
        integer i, j, k;
        for (i = 0; i <= 8; i = i + 1) begin
            for (j = 0; j <= 8; j = j + 1) begin
                lcp[i][j] = 4'd0;
            end
        end
        
        // Compute LCP table
        for (j = 7; j >= 1; j = j - 1) begin
            for (k = j - 1; k >= 0; k = k - 1) begin
                if (s_reg[k] == s_reg[j])
                    lcp[k][j] = 1 + lcp[k + 1][j + 1];
                else
                    lcp[k][j] = 4'd0;
            end
        end
        
        // Compute maxL for each position
        for (j = 0; j < 8; j = j + 1) begin
            maxL[j] = 4'd0;
            for (k = 0; k < j; k = k + 1) begin
                if (lcp[k][j] < (j - k))
                    maxL[j] = lcp[k][j];
                else
                    maxL[j] = (j - k);
            end
        end
        
        // Compute DP
        dp[0] = 16'd0;
        for (i = 1; i <= 8; i = i + 1) begin
            dp[i] = dp[i - 1] + a_reg;
            for (j = 0; j < i; j = j + 1) begin
                if (i - j <= maxL[j]) begin
                    if (dp[j] + b_reg < dp[i])
                        dp[i] = dp[j] + b_reg;
                end
            end
        end
        
        // Output result
        min_cost = dp[n_reg];
    end

    // Sequential logic for input capture and done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            for (i = 0; i < 8; i = i + 1) begin
                s_reg[i] <= 8'd0;
            end
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            n_reg <= 4'd0;
            
            // Initialize internal tables
            for (i = 0; i <= 8; i = i + 1) begin
                for (j = 0; j <= 8; j = j + 1) begin
                    lcp[i][j] <= 4'd0;
                end
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                maxL[i] <= 4'd0;
            end
            
            for (i = 0; i <= 8; i = i + 1) begin
                dp[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Capture inputs
                    s_reg[0] <= s0;
                    s_reg[1] <= s1;
                    s_reg[2] <= s2;
                    s_reg[3] <= s3;
                    s_reg[4] <= s4;
                    s_reg[5] <= s5;
                    s_reg[6] <= s6;
                    s_reg[7] <= s7;
                    a_reg <= a;
                    b_reg <= b;
                    n_reg <= n;
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule