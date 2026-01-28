module LCS3D(
    input clk,
    input rst_n,
    input start,
    input [2:0] len_a,
    input [2:0] len_b,
    input [2:0] len_c,
    input [7:0] str_a [0:7],
    input [7:0] str_b [0:7],
    input [7:0] str_c [0:7],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // DP table pointers
    reg [3:0] i, j, k;
    reg [3:0] i_next, j_next, k_next;

    // DP table storage (9x9x9 x 4-bit)
    reg [3:0] dp [0:8][0:8][0:8];
    integer idx_i, idx_j, idx_k;

    // Initialize DP table
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx_i = 0; idx_i < 9; idx_i = idx_i + 1) begin
                for (idx_j = 0; idx_j < 9; idx_j = idx_j + 1) begin
                    for (idx_k = 0; idx_k < 9; idx_k = idx_k + 1) begin
                        dp[idx_i][idx_j][idx_k] <= 4'd0;
                    end
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 4'd1;
                        j <= 4'd1;
                        k <= 4'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute current DP value
                    if (i > 4'd0 && j > 4'd0 && k > 4'd0 && 
                        str_a[i-1] == str_b[j-1] && str_a[i-1] == str_c[k-1]) begin
                        dp[i][j][k] <= dp[i-1][j-1][k-1] + 4'd1;
                    end else begin
                        dp[i][j][k] <= 4'd0;
                        if (i > 4'd0 && dp[i-1][j][k] > dp[i][j][k]) begin
                            dp[i][j][k] <= dp[i-1][j][k];
                        end
                        if (j > 4'd0 && dp[i][j-1][k] > dp[i][j][k]) begin
                            dp[i][j][k] <= dp[i][j-1][k];
                        end
                        if (k > 4'd0 && dp[i][j][k-1] > dp[i][j][k]) begin
                            dp[i][j][k] <= dp[i][j][k-1];
                        end
                    end
                    
                    // Update pointers
                    i_next <= i;
                    j_next <= j;
                    k_next <= k + 4'd1;
                    
                    if (k_next > len_c + 4'd1) begin
                        k_next <= 4'd1;
                        j_next <= j + 4'd1;
                        if (j_next > len_b + 4'd1) begin
                            j_next <= 4'd1;
                            i_next <= i + 4'd1;
                            if (i_next > len_a + 4'd1) begin
                                state <= FINISH;
                            end
                        end
                    end
                    
                    i <= i_next;
                    j <= j_next;
                    k <= k_next;
                    
                    // Safety check for cycle limit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= dp[len_a+1][len_b+1][len_c+1];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule