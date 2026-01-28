module iterative_multiplier(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] x_i,
    input signed [15:0] y_i,
    output reg signed [15:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] NEGATE_Y   = 3'd1;
    localparam [2:0] MULTIPLY   = 3'd2;
    localparam [2:0] APPLY_SIGN = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg signed [15:0] x_reg, y_reg;
    reg signed [15:0] temp_result;
    reg sign_flag;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            temp_result <= 16'd0;
            x_reg <= 16'd0;
            y_reg <= 16'd0;
            sign_flag <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= x_i;
                        y_reg <= y_i;
                        temp_result <= 16'd0;
                        sign_flag <= 1'b0;
                        cycle_count <= 8'd0;
                        next_state <= NEGATE_Y;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                NEGATE_Y: begin
                    busy <= 1'b1;
                    if (y_reg[15]) begin
                        y_reg <= -y_reg;
                        sign_flag <= 1'b1;
                    end
                    next_state <= MULTIPLY;
                end

                MULTIPLY: begin
                    busy <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (y_reg > 16'd0 && cycle_count < MAX_CYCLES) begin
                        temp_result <= temp_result + x_reg;
                        y_reg <= y_reg - 16'd1;
                        next_state <= MULTIPLY;
                    end else begin
                        next_state <= APPLY_SIGN;
                    end
                end

                APPLY_SIGN: begin
                    busy <= 1'b1;
                    if (sign_flag) begin
                        result <= -temp_result;
                    end else begin
                        result <= temp_result;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule