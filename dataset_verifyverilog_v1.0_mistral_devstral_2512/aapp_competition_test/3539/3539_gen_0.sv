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
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [2:0] idx;
    reg [31:0] total_edges;
    reg [31:0] cnt;
    reg [31:0] power;
    reg [31:0] exponent;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            idx <= 3'd0;
            total_edges <= 32'd0;
            cnt <= 32'd0;
            power <= 32'd0;
            exponent <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        idx <= 3'd0;
                        total_edges <= 32'd0;
                        cnt <= 32'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (idx < N) begin
                        total_edges <= total_edges + (a_i[idx] * b_i[idx]);
                        if (a_i[idx][0] && b_i[idx][0]) begin
                            cnt <= cnt + 32'd1;
                        end
                        idx <= idx + 3'd1;
                    end else if (idx == N) begin
                        if (cnt[0]) begin
                            exponent <= total_edges - 32'd1;
                            power <= 32'd1;
                            idx <= idx + 3'd1;
                        end else begin
                            result <= 32'd0;
                            done <= 1'b1;
                            state <= FINISH;
                        end
                    end else if (idx > N) begin
                        if (exponent > 32'd0) begin
                            power <= (power * 32'd2) % 32'd1000000007;
                            exponent <= exponent - 32'd1;
                        end else begin
                            result <= power;
                            done <= 1'b1;
                            state <= FINISH;
                        end
                    end
                    
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