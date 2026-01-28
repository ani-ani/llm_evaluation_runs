module bit_range_checker(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [3:0] l,
    input [3:0] r,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [15:0] mask;
    reg [15:0] masked_n;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            mask <= 16'd0;
            masked_n <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Handle l=0 case (treat as l=1)
                    reg [3:0] adjusted_l = (l == 4'd0) ? 4'd1 : l;
                    
                    // Create mask: ((1 << r) - 1) ^ ((1 << (l-1)) - 1)
                    mask <= ((16'd1 << r) - 16'd1) ^ ((16'd1 << (adjusted_l - 4'd1)) - 16'd1);
                    
                    // Apply mask and check result
                    masked_n <= n & mask;
                    result <= (masked_n == 16'd0) ? 1'b1 : 1'b0;
                    
                    state <= FINISH;
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