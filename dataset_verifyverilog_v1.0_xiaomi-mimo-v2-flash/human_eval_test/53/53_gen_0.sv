module add(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x,
    input wire [15:0] y,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    
    reg [1:0] state;
    reg [15:0] x_reg;
    reg [15:0] y_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            x_reg <= 16'd0;
            y_reg <= 16'd0;
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
                    // Combinational addition, registered in next cycle
                    result <= x_reg + y_reg;  // Truncates automatically to 16 bits
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule