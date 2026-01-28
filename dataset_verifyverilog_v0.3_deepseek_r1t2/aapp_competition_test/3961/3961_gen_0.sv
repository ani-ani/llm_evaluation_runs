module maze_solver #(
    parameter MOD = 32'd1000000007,
    parameter MAX_N = 8
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] p_0,
    input [3:0] p_1,
    input [3:0] p_2,
    input [3:0] p_3,
    input [3:0] p_4,
    input [3:0] p_5,
    input [3:0] p_6,
    input [3:0] p_7,
    output reg [31:0] result,
    output reg done
);
    localparam [1:0] S_IDLE    = 2'd0;
    localparam [1:0] S_COMPUTE = 2'd1;
    localparam [1:0] S_DONE    = 2'd2;
    
    reg [1:0] state;
    reg [3:0] i;
    reg [31:0] dp [0:MAX_N];
    
    wire [3:0] p_val;
    assign p_val = (i == 4'd1) ? p_0 :
                   (i == 4'd2) ? p_1 :
                   (i == 4'd3) ? p_2 :
                   (i == 4'd4) ? p_3 :
                   (i == 4'd5) ? p_4 :
                   (i == 4'd6) ? p_5 :
                   (i == 4'd7) ? p_6 : p_7;
    
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 32'd0;
            i <= 4'd0;
            
            for (j = 0; j <= MAX_N; j = j + 1) begin
                dp[j] <= 32'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start && (n != 4'd0)) begin
                        state <= S_COMPUTE;
                        i <= 4'd1;
                    end
                end
                
                S_COMPUTE: begin
                    dp[i] <= (2 * dp[i-1] + 32'd2 + MOD - dp[p_val-1]) % MOD;
                    
                    if (i == n) begin
                        result <= (2 * dp[i-1] + 32'd2 + MOD - dp[p_val-1]) % MOD;
                        state <= S_DONE;
                    end else begin
                        i <= i + 4'd1;
                    end
                end
                
                S_DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= S_IDLE;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule