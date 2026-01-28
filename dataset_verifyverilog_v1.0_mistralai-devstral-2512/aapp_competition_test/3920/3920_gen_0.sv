module TriangleCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a1,
    input wire [15:0] a2,
    input wire [15:0] a3,
    input wire [15:0] a4,
    input wire [15:0] a5,
    input wire [15:0] a6,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [15:0] a1_reg, a2_reg, a3_reg, a4_reg, a5_reg, a6_reg;
    reg [31:0] sum_sq, a1_sq, a3_sq, a5_sq;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            a1_reg <= 16'd0;
            a2_reg <= 16'd0;
            a3_reg <= 16'd0;
            a4_reg <= 16'd0;
            a5_reg <= 16'd0;
            a6_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Register inputs on start pulse
                        a1_reg <= a1;
                        a2_reg <= a2;
                        a3_reg <= a3;
                        a4_reg <= a4;
                        a5_reg <= a5;
                        a6_reg <= a6;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Compute squares
                    sum_sq <= (a1_reg + a2_reg + a3_reg) * (a1_reg + a2_reg + a3_reg);
                    a1_sq <= a1_reg * a1_reg;
                    a3_sq <= a3_reg * a3_reg;
                    a5_sq <= a5_reg * a5_reg;
                    
                    // Final result
                    result <= sum_sq - a1_sq - a3_sq - a5_sq;
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