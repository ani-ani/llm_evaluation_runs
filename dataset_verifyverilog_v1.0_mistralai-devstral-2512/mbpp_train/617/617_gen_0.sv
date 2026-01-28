module JumpCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] step_a,
    input wire [15:0] step_b,
    input wire [15:0] d,
    output reg [31:0] result,
    output reg done
);

    reg [1:0] state;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [15:0] a_reg;
    reg [15:0] b_reg;
    reg [15:0] d_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            d_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        a_reg <= step_a;
                        b_reg <= step_b;
                        d_reg <= d;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    reg [15:0] a = (a_reg < b_reg) ? a_reg : b_reg;
                    reg [15:0] b = (a_reg > b_reg) ? a_reg : b_reg;
                    reg [15:0] distance = d_reg;
                    
                    if (distance == 16'd0) begin
                        result <= 32'd0;
                    end else if (distance == a) begin
                        result <= 32'd1;
                    end else if (distance >= b) begin
                        reg [31:0] numerator = {16'd0, distance} + {16'd0, b} - 32'd1;
                        reg [31:0] denominator = {16'd0, b};
                        reg [31:0] quotient = numerator / denominator;
                        result <= quotient;
                    end else begin
                        result <= 32'd2;
                    end
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