module StringMergeChecker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] s [0:15],
    input wire [4:0] s1 [0:15],
    input wire [4:0] s2 [0:15],
    input wire [3:0] len_s,
    input wire [3:0] len_s1,
    input wire [3:0] len_s2,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // DP table registers (16x16)
    reg [15:0] dp [0:15];
    reg [3:0] i_reg, j_reg;
    reg [3:0] i_next, j_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP table
            integer k, l;
            for (k = 0; k < 16; k = k + 1) begin
                for (l = 0; l < 16; l = l + 1) begin
                    dp[k][l] <= 1'b0;
                end
            end
            
            i_reg <= 4'd0;
            j_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        
                        // Initialize DP table
                        integer k, l;
                        for (k = 0; k < 16; k = k + 1) begin
                            for (l = 0; l < 16; l = l + 1) begin
                                dp[k][l] <= 1'b0;
                            end
                        end
                        
                        // Base case: dp[0][0] = 1
                        dp[0][0] <= 1'b1;
                        
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute next i and j
                    if (i_reg < len_s1 && j_reg < len_s2) begin
                        i_next = i_reg + 4'd1;
                        j_next = j_reg;
                    end else if (i_reg < len_s1) begin
                        i_next = i_reg + 4'd1;
                        j_next = j_reg;
                    end else if (j_reg < len_s2) begin
                        i_next = i_reg;
                        j_next = j_reg + 4'd1;
                    end else begin
                        i_next = i_reg;
                        j_next = j_reg;
                    end
                    
                    // Update DP table
                    if (i_reg > 0 && j_reg > 0) begin
                        if (dp[i_reg-1][j_reg] && s[i_reg+j_reg-1] == s1[i_reg-1]) begin
                            dp[i_reg][j_reg] <= 1'b1;
                        end else if (dp[i_reg][j_reg-1] && s[i_reg+j_reg-1] == s2[j_reg-1]) begin
                            dp[i_reg][j_reg] <= 1'b1;
                        end else begin
                            dp[i_reg][j_reg] <= 1'b0;
                        end
                    end else if (i_reg > 0) begin
                        if (dp[i_reg-1][j_reg] && s[i_reg+j_reg-1] == s1[i_reg-1]) begin
                            dp[i_reg][j_reg] <= 1'b1;
                        end else begin
                            dp[i_reg][j_reg] <= 1'b0;
                        end
                    end else if (j_reg > 0) begin
                        if (dp[i_reg][j_reg-1] && s[i_reg+j_reg-1] == s2[j_reg-1]) begin
                            dp[i_reg][j_reg] <= 1'b1;
                        end else begin
                            dp[i_reg][j_reg] <= 1'b0;
                        end
                    end
                    
                    // Update i and j
                    i_reg <= i_next;
                    j_reg <= j_next;
                    
                    // Check if computation is complete
                    if ((i_reg == len_s1 && j_reg == len_s2) || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Check if the entire string is matched
                    if (len_s == len_s1 + len_s2 && dp[len_s1][len_s2]) begin
                        valid <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule