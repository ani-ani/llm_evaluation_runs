module circle_circumference(
    input clk,
    input rst_n,
    input start,
    input [7:0] radius,
    output reg [23:0] circumference,
    output reg done
);

    // Fixed-point PI constant in Q16.16 format
    localparam [23:0] PI_FIXED = 24'd205887;  // 0x3243F

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;

    reg [1:0] state;
    reg [7:0] radius_reg;
    reg [23:0] temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            radius_reg <= 8'd0;
            temp <= 24'd0;
            circumference <= 24'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        radius_reg <= radius;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate temp = radius * PI_FIXED (24-bit result)
                    temp <= radius_reg * PI_FIXED;
                    
                    // Calculate circumference = temp << 1 (multiply by 2)
                    circumference <= temp << 1;
                    
                    // Assert done for 1 cycle
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule