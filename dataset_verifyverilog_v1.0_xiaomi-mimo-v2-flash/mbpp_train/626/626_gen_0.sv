module TriangleAreaSemicircle (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] radius,
    output reg [15:0] area_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    wire [15:0] radius_squared;
    wire [15:0] area_temp;
    
    // Combinational logic for area calculation
    // Area = (radius * radius) / 2, scaled by 2^8
    // radius^2 gives 16-bit result, shift right by 1 for division by 2
    assign radius_squared = radius * radius;  // 8x8 multiplication
    assign area_temp = radius_squared >> 1;    // Divide by 2
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area_out <= 16'd0;
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
                    // Calculate area and store
                    area_out <= area_temp;
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