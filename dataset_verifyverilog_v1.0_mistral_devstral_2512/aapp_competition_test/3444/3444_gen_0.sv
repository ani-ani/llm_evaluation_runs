module ski_probability(
    input clk,
    input rst_n,
    input start,
    input [31:0] ski_prob_01,
    input [31:0] ski_prob_02,
    input [31:0] ski_prob_03,
    input [31:0] ski_prob_12,
    input [31:0] ski_prob_13,
    input [31:0] ski_prob_23,
    input walk_edge_01,
    input walk_edge_02,
    input walk_edge_03,
    input walk_edge_12,
    input walk_edge_13,
    input walk_edge_23,
    output reg [31:0] prob_k0,
    output reg [31:0] prob_k1,
    output reg [31:0] prob_k2,
    output reg [31:0] prob_k3,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    reg [31:0] dp [0:3][0:3];
    reg [31:0] best0, best1, best2, best3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            prob_k0 <= 32'd0;
            prob_k1 <= 32'd0;
            prob_k2 <= 32'd0;
            prob_k3 <= 32'd0;
            
            integer i, j;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    dp[i][j] <= 32'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        dp[0][0] <= 32'd65536;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    integer k, i, j;
                    reg [63:0] mult_temp;
                    reg [31:0] product;
                    
                    for (k = 0; k < 4; k = k + 1) begin
                        if (k < 3) begin
                            if (ski_prob_01 != 32'd0) begin
                                mult_temp = dp[0][k] * ski_prob_01;
                                product = mult_temp[47:16];
                                if (product > dp[1][k]) begin
                                    dp[1][k] <= product;
                                end
                            end
                            
                            if (ski_prob_02 != 32'd0) begin
                                mult_temp = dp[0][k] * ski_prob_02;
                                product = mult_temp[47:16];
                                if (product > dp[2][k]) begin
                                    dp[2][k] <= product;
                                end
                            end
                            
                            if (ski_prob_03 != 32'd0) begin
                                mult_temp = dp[0][k] * ski_prob_03;
                                product = mult_temp[47:16];
                                if (product > dp[3][k]) begin
                                    dp[3][k] <= product;
                                end
                            end
                            
                            if (ski_prob_12 != 32'd0) begin
                                mult_temp = dp[1][k] * ski_prob_12;
                                product = mult_temp[47:16];
                                if (product > dp[2][k]) begin
                                    dp[2][k] <= product;
                                end
                            end
                            
                            if (ski_prob_13 != 32'd0) begin
                                mult_temp = dp[1][k] * ski_prob_13;
                                product = mult_temp[47:16];
                                if (product > dp[3][k]) begin
                                    dp[3][k] <= product;
                                end
                            end
                            
                            if (ski_prob_23 != 32'd0) begin
                                mult_temp = dp[2][k] * ski_prob_23;
                                product = mult_temp[47:16];
                                if (product > dp[3][k]) begin
                                    dp[3][k] <= product;
                                end
                            end
                        end
                        
                        if (k < 3) begin
                            if (walk_edge_01) begin
                                if (dp[0][k] > dp[1][k+1]) begin
                                    dp[1][k+1] <= dp[0][k];
                                end
                                if (dp[1][k] > dp[0][k+1]) begin
                                    dp[0][k+1] <= dp[1][k];
                                end
                            end
                            
                            if (walk_edge_02) begin
                                if (dp[0][k] > dp[2][k+1]) begin
                                    dp[2][k+1] <= dp[0][k];
                                end
                                if (dp[2][k] > dp[0][k+1]) begin
                                    dp[0][k+1] <= dp[2][k];
                                end
                            end
                            
                            if (walk_edge_03) begin
                                if (dp[0][k] > dp[3][k+1]) begin
                                    dp[3][k+1] <= dp[0][k];
                                end
                                if (dp[3][k] > dp[0][k+1]) begin
                                    dp[0][k+1] <= dp[3][k];
                                end
                            end
                            
                            if (walk_edge_12) begin
                                if (dp[1][k] > dp[2][k+1]) begin
                                    dp[2][k+1] <= dp[1][k];
                                end
                                if (dp[2][k] > dp[1][k+1]) begin
                                    dp[1][k+1] <= dp[2][k];
                                end
                            end
                            
                            if (walk_edge_13) begin
                                if (dp[1][k] > dp[3][k+1]) begin
                                    dp[3][k+1] <= dp[1][k];
                                end
                                if (dp[3][k] > dp[1][k+1]) begin
                                    dp[1][k+1] <= dp[3][k];
                                end
                            end
                            
                            if (walk_edge_23) begin
                                if (dp[2][k] > dp[3][k+1]) begin
                                    dp[3][k+1] <= dp[2][k];
                                end
                                if (dp[3][k] > dp[2][k+1]) begin
                                    dp[2][k+1] <= dp[3][k];
                                end
                            end
                        end
                    end
                    
                    best0 = dp[3][0];
                    best1 = (dp[3][1] > best0) ? dp[3][1] : best0;
                    best2 = (dp[3][2] > best1) ? dp[3][2] : best1;
                    best3 = (dp[3][3] > best2) ? dp[3][3] : best2;
                    
                    prob_k0 <= best0;
                    prob_k1 <= best1;
                    prob_k2 <= best2;
                    prob_k3 <= best3;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
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