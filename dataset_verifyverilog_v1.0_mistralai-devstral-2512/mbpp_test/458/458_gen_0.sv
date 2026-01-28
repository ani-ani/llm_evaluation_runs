module rectangle_area_calculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] length,
    input [7:0] width,
    output reg [15:0] area,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    
    reg [1:0] state;
    reg [15:0] area_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area <= 16'd0;
            area_reg <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    area_reg <= length * width;
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    area <= area_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule