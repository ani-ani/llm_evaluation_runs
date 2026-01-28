module integer_multiplier (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] x_i,
    input wire signed [15:0] y_i,
    output reg signed [15:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] NEGATE_Y   = 2'd1;
    localparam [1:0] MULTIPLY   = 2'd2;
    localparam [1:0] APPLY_SIGN = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg signed [15:0] x_reg;
    reg signed [15:0] y_reg;
    reg signed [15:0] result_reg;
    reg sign_bit; // Stores original sign of y
    reg [8:0] counter; // Counter for iterations (up to 256)
    
    // Combinatorial signals
    wire y_is_negative;
    wire y_is_zero;
    
    assign y_is_negative = y_reg[15];
    assign y_is_zero = (y_reg == 16'sd0);

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = NEGATE_Y;
                else
                    next_state = IDLE;
            end
            NEGATE_Y: begin
                // One cycle to negate if needed
                next_state = MULTIPLY;
            end
            MULTIPLY: begin
                if (y_is_zero)
                    next_state = APPLY_SIGN;
                else
                    next_state = MULTIPLY;
            end
            APPLY_SIGN: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            busy <= 1'b0;
            x_reg <= 16'sd0;
            y_reg <= 16'sd0;
            result_reg <= 16'sd0;
            sign_bit <= 1'b0;
            counter <= 9'd0;
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    counter <= 9'd0;
                    if (start) begin
                        busy <= 1'b1;
                        x_reg <= x_i;
                        y_reg <= y_i;
                        result_reg <= 16'sd0;
                        sign_bit <= y_i[15]; // Store original sign
                    end
                end
                
                NEGATE_Y: begin
                    // If y was negative, negate it
                    if (y_is_negative) begin
                        y_reg <= -y_reg;
                    end
                    result_reg <= 16'sd0;
                    counter <= 9'd0;
                end
                
                MULTIPLY: begin
                    if (!y_is_zero && counter < 9'd256) begin
                        // result = result + x; y = y - 1
                        result_reg <= result_reg + x_reg;
                        y_reg <= y_reg - 16'sd1;
                        counter <= counter + 9'd1;
                    end
                end
                
                APPLY_SIGN: begin
                    // If original y was negative, negate result
                    if (sign_bit) begin
                        result <= -result_reg;
                    end else begin
                        result <= result_reg;
                    end
                    done <= 1'b1;
                    busy <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    busy <= 1'b0;
                end
            endcase
            
            state <= next_state;
        end
    end

endmodule