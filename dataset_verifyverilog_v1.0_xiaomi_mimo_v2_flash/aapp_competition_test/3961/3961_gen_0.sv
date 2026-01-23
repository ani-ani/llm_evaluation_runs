module maze_solver #(
    parameter MOD = 32'd1000000007,
    parameter MAX_N = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,           // Number of rooms (1 to 8)
    input wire [3:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    output reg [31:0] result,
    output reg done
);
    // State machine states
    reg [1:0] state;
    localparam [1:0] S_IDLE = 2'b00;
    localparam [1:0] S_COMPUTE = 2'b01;
    localparam [1:0] S_DONE = 2'b10;
    
    // Data registers
    reg [3:0] i;  // Counter from 1 to n
    reg [31:0] dp_0, dp_1, dp_2, dp_3, dp_4, dp_5, dp_6, dp_7, dp_8;
    
    // Helper: select current p value
    wire [3:0] p_val;
    assign p_val = (i == 4'd1) ? p_0 :
                   (i == 4'd2) ? p_1 :
                   (i == 4'd3) ? p_2 :
                   (i == 4'd4) ? p_3 :
                   (i == 4'd5) ? p_4 :
                   (i == 4'd6) ? p_5 :
                   (i == 4'd7) ? p_6 : p_7;
    
    // Intermediate computations
    wire [31:0] dp_im1;
    wire [31:0] dp_pvalm1;
    
    assign dp_im1 = (i == 4'd1) ? dp_0 :
                    (i == 4'd2) ? dp_1 :
                    (i == 4'd3) ? dp_2 :
                    (i == 4'd4) ? dp_3 :
                    (i == 4'd5) ? dp_4 :
                    (i == 4'd6) ? dp_5 :
                    (i == 4'd7) ? dp_6 : dp_7;
    
    assign dp_pvalm1 = (p_val == 4'd1) ? dp_0 :
                       (p_val == 4'd2) ? dp_1 :
                       (p_val == 4'd3) ? dp_2 :
                       (p_val == 4'd4) ? dp_3 :
                       (p_val == 4'd5) ? dp_4 :
                       (p_val == 4'd6) ? dp_5 :
                       (p_val == 4'd7) ? dp_6 : dp_7;
    
    wire [31:0] next_dp;
    assign next_dp = (2 * dp_im1 + 2 + MOD - dp_pvalm1) % MOD;
    
    // State machine and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            i <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            dp_0 <= 32'd0;
            dp_1 <= 32'd0;
            dp_2 <= 32'd0;
            dp_3 <= 32'd0;
            dp_4 <= 32'd0;
            dp_5 <= 32'd0;
            dp_6 <= 32'd0;
            dp_7 <= 32'd0;
            dp_8 <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start && n != 0) begin
                        state <= S_COMPUTE;
                        i <= 4'd1;
                    end
                end
                
                S_COMPUTE: begin
                    if (i == 4'd1) dp_1 <= next_dp;
                    else if (i == 4'd2) dp_2 <= next_dp;
                    else if (i == 4'd3) dp_3 <= next_dp;
                    else if (i == 4'd4) dp_4 <= next_dp;
                    else if (i == 4'd5) dp_5 <= next_dp;
                    else if (i == 4'd6) dp_6 <= next_dp;
                    else if (i == 4'd7) dp_7 <= next_dp;
                    else dp_8 <= next_dp;
                    
                    if (i == n) begin
                        state <= S_DONE;
                        result <= next_dp;
                        done <= 1'b1;
                    end else begin
                        i <= i + 4'd1;
                    end
                end
                
                S_DONE: begin
                    if (!start) begin
                        state <= S_IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
    
endmodule