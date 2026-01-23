module coin_count(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [31:0] a [0:7],
    input [15:0] b [0:7],
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;
    
    reg [31:0] dp [0:15];
    reg [31:0] denom [0:7];
    reg [31:0] current_denom;
    reg [4:0] i, j, k;
    reg [31:0] temp;
    reg [31:0] mod_const = 32'd1000000007;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                dp[i] <= 32'd0;
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                denom[i] <= 32'd0;
            end
            
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            current_denom <= 32'd0;
            temp <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= COMPUTE;
                        
                        denom[0] <= 32'd1;
                        for (i = 1; i <= n; i = i + 1) begin
                            denom[i] <= denom[i-1] * a[i-1];
                        end
                        
                        dp[0] <= 32'd1;
                        i <= 5'd0;
                        j <= 5'd0;
                        k <= 5'd0;
                        current_denom <= denom[0];
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        if (i < n + 1) begin
                            if (j <= b[i]) begin
                                if (k <= m / current_denom) begin
                                    if (k >= j * (current_denom / denom[i])) begin
                                        temp <= dp[k - j * (current_denom / denom[i])];
                                        if (j == 0) begin
                                            temp <= 32'd1;
                                        end
                                        
                                        dp[k] <= (dp[k] + temp) % mod_const;
                                        k <= k + 1;
                                    end else begin
                                        k <= k + 1;
                                    end
                                end else begin
                                    k <= 5'd0;
                                    j <= j + 1;
                                end
                            end else begin
                                j <= 5'd0;
                                k <= 5'd0;
                                i <= i + 1;
                                current_denom <= denom[i];
                            end
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    result <= dp[m / denom[n]];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule