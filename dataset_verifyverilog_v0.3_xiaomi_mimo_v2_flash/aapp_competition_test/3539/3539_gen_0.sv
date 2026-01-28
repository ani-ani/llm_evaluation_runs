module BipartiteBattle (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [7:0] a_i [0:7],
    input [7:0] b_i [0:7],
    output reg [31:0] result,
    output reg done
);
    localparam [31:0] MOD = 32'd1000000007;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_EDGES = 3'd1;
    localparam [2:0] CHECK_CONDITION = 3'd2;
    localparam [2:0] POWER_CYCLE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [31:0] total_edges;
    reg [31:0] cnt;
    reg [2:0] idx;
    reg [31:0] power;
    reg [31:0] exponent;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            total_edges <= 32'd0;
            cnt <= 32'd0;
            idx <= 3'd0;
            power <= 32'd0;
            exponent <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        total_edges <= 32'd0;
                        cnt <= 32'd0;
                        idx <= 3'd0;
                        state <= COMPUTE_EDGES;
                    end
                end
                
                COMPUTE_EDGES: begin
                    if (idx < N) begin
                        total_edges <= (total_edges + a_i[idx] * b_i[idx]) % MOD;
                        if (a_i[idx][0] && b_i[idx][0]) begin
                            cnt <= cnt + 32'd1;
                        end
                        idx <= idx + 3'd1;
                    end else begin
                        state <= CHECK_CONDITION;
                    end
                end
                
                CHECK_CONDITION: begin
                    if (cnt[0]) begin
                        exponent <= (total_edges + MOD - 32'd1) % MOD;
                        power <= 32'd1;
                        state <= POWER_CYCLE;
                    end else begin
                        result <= 32'd0;
                        state <= FINISH;
                    end
                end
                
                POWER_CYCLE: begin
                    if (exponent > 32'd0) begin
                        power <= (power * 32'd2) % MOD;
                        exponent <= exponent - 32'd1;
                    end else begin
                        result <= power;
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