module string_compression (
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
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CAPTURE   = 2'd1;
    localparam [1:0] COMPUTE   = 2'd2;
    localparam [1:0] FINISH    = 2'd3;
    
    reg [1:0] state;
    reg [7:0] s_reg [0:7];
    reg [15:0] a_reg, b_reg;
    reg [3:0] n_reg;
    
    // Computation variables
    reg [3:0] i, j, k;
    reg [3:0] lcp [0:8][0:8];
    reg [3:0] maxL [0:7];
    reg [15:0] dp [0:8];
    reg [15:0] temp_dp;
    reg [3:0] L;
    reg computation_done;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_cost <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp_dp <= 16'd0;
            L <= 4'd0;
            computation_done <= 1'b0;
            // Initialize s_reg
            s_reg[0] <= 8'd0;
            s_reg[1] <= 8'd0;
            s_reg[2] <= 8'd0;
            s_reg[3] <= 8'd0;
            s_reg[4] <= 8'd0;
            s_reg[5] <= 8'd0;
            s_reg[6] <= 8'd0;
            s_reg[7] <= 8'd0;
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            n_reg <= 4'd0;
            // Initialize lcp table
            for (i = 0; i <= 8; i = i + 1) begin
                for (j = 0; j <= 8; j = j + 1) begin
                    lcp[i][j] <= 4'd0;
                end
            end
            // Initialize maxL
            for (i = 0; i < 8; i = i + 1) begin
                maxL[i] <= 4'd0;
            end
            // Initialize dp
            for (i = 0; i <= 8; i = i + 1) begin
                dp[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CAPTURE;
                        i <= 4'd0;
                    end
                end
                
                CAPTURE: begin
                    // Capture inputs into registers
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
                    
                    // Initialize lcp table to zero
                    i <= 4'd0;
                    state <= COMPUTE;
                    computation_done <= 1'b0;
                end
                
                COMPUTE: begin
                    // Sequential computation to avoid combinational loops
                    
                    // Step 1: Compute LCP table
                    if (i == 4'd0) begin
                        // Compute LCP for j=7 down to 1, k=j-1 down to 0
                        if (j <= 4'd7) begin
                            if (k <= j - 4'd1) begin
                                if (s_reg[k] == s_reg[j]) begin
                                    if (j < 4'd7 && k < 4'd7) begin
                                        lcp[k][j] <= lcp[k + 4'd1][j + 4'd1] + 4'd1;
                                    end else begin
                                        lcp[k][j] <= 4'd1;
                                    end
                                end else begin
                                    lcp[k][j] <= 4'd0;
                                end
                                k <= k + 4'd1;
                            end else begin
                                k <= 4'd0;
                                j <= j + 4'd1;
                                if (j == 4'd7) begin
                                    j <= 4'd0;
                                    i <= 4'd1; // Move to next step
                                end
                            end
                        end
                    end else if (i == 4'd1) begin
                        // Step 2: Compute maxL
                        if (j < 4'd8) begin
                            if (k < j) begin
                                if (lcp[k][j] < (j - k)) begin
                                    L <= lcp[k][j];
                                end else begin
                                    L <= j - k;
                                end
                                if (L > maxL[j]) begin
                                    maxL[j] <= L;
                                end
                                k <= k + 4'd1;
                            end else begin
                                k <= 4'd0;
                                j <= j + 4'd1;
                            end
                        end else begin
                            j <= 4'd0;
                            i <= 4'd2; // Move to next step
                        end
                    end else if (i == 4'd2) begin
                        // Step 3: Compute DP
                        if (j == 4'd0) begin
                            dp[0] <= 16'd0;
                            j <= 4'd1;
                        end else if (j <= n_reg) begin
                            // Initialize dp[j] = dp[j-1] + a_reg
                            temp_dp <= dp[j - 4'd1] + a_reg;
                            k <= 4'd0;
                            i <= 4'd3; // Inner loop
                        end else begin
                            // Done
                            computation_done <= 1'b1;
                            state <= FINISH;
                        end
                    end else if (i == 4'd3) begin
                        // Inner loop for j
                        if (k < j) begin
                            // Check condition
                            if (j - k <= maxL[k]) begin
                                if (dp[k] + b_reg < temp_dp) begin
                                    temp_dp <= dp[k] + b_reg;
                                end
                            end
                            k <= k + 4'd1;
                        end else begin
                            dp[j] <= temp_dp;
                            j <= j + 4'd1;
                            i <= 4'd2; // Back to outer loop
                        end
                    end
                end
                
                FINISH: begin
                    min_cost <= dp[n_reg];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule