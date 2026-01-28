module any_int(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] x,
    input signed [15:0] y,
    input signed [15:0] z,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] CHECK  = 2'd1;
    localparam [1:0] SUM    = 2'd2;
    localparam [1:0] RESULT = 2'd3;

    reg [1:0] state, next_state;
    reg is_int_reg;
    reg sum1_reg, sum2_reg, sum3_reg;
    reg signed [15:0] x_reg, y_reg, z_reg;
    reg signed [16:0] sum_xy, sum_xz, sum_yz;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            is_int_reg <= 1'b0;
            sum1_reg <= 1'b0;
            sum2_reg <= 1'b0;
            sum3_reg <= 1'b0;
            x_reg <= 16'd0;
            y_reg <= 16'd0;
            z_reg <= 16'd0;
            sum_xy <= 17'd0;
            sum_xz <= 17'd0;
            sum_yz <= 17'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= x;
                        y_reg <= y;
                        z_reg <= z;
                    end
                end
                
                CHECK: begin
                    // Check if all are integers (fractional bits are 0)
                    is_int_reg <= (x_reg[7:0] == 16'd0) && (y_reg[7:0] == 16'd0) && (z_reg[7:0] == 16'd0);
                end
                
                SUM: begin
                    // Perform 16-bit signed additions with 17-bit intermediates
                    sum_xy <= x_reg + y_reg;
                    sum_xz <= x_reg + z_reg;
                    sum_yz <= y_reg + z_reg;
                end
                
                RESULT: begin
                    // Check sum conditions (use lower 16 bits for comparison)
                    sum1_reg <= (sum_xy[15:0] == z_reg);
                    sum2_reg <= (sum_xz[15:0] == y_reg);
                    sum3_reg <= (sum_yz[15:0] == x_reg);
                    
                    // Final result
                    result <= is_int_reg && (sum1_reg || sum2_reg || sum3_reg);
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:    next_state = start ? CHECK : IDLE;
            CHECK:   next_state = SUM;
            SUM:     next_state = RESULT;
            RESULT:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule