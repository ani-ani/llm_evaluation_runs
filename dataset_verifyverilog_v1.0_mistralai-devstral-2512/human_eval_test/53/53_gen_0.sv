module add(
    input clk,
    input rst_n,
    input start,
    input [15:0] x,
    input [15:0] y,
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    
    reg [1:0] state;
    reg [15:0] x_reg;
    reg [15:0] y_reg;
    reg [15:0] sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            x_reg <= 16'd0;
            y_reg <= 16'd0;
            sum <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= x;
                        y_reg <= y;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    sum <= x_reg + y_reg;
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule