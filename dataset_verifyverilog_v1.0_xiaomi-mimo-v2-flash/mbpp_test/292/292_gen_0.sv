module Div16 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [15:0] m,
    output reg [15:0] q,
    output reg [15:0] r,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [1:0] next_state;
    
    // Shift-subtract algorithm registers
    reg [15:0] dividend_reg;      // Current remainder/dividend
    reg [15:0] quotient_reg;      // Accumulated quotient
    reg [4:0] counter;            // 0 to 16 (16 cycles max)
    
    // Combinational signals for next state logic
    wire [15:0] shifted_divisor;
    wire [16:0] sub_result;       // 17-bit for borrow detection
    wire can_subtract;
    
    // Shift divisor by counter positions
    // Since counter goes 0 to 16, shift right by (15-counter) is equivalent to shift left by counter
    // Actually for binary long division, we shift divisor left by counter
    // Simplified: we check if divisor shifted left by (15-counter) fits
    // Better approach: standard shift-subtract
    assign shifted_divisor = m << (15 - counter);
    assign sub_result = {1'b0, dividend_reg} - {1'b0, shifted_divisor};
    assign can_subtract = !sub_result[16]; // No borrow if MSB is 0

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (m == 16'd0) begin
                        // Division by zero detected immediately
                        next_state = FINISH;
                    end else begin
                        next_state = CALC;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            CALC: begin
                // Continue for 16 iterations
                if (counter >= 5'd16) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALC;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic for registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 16'd0;
            r <= 16'd0;
            done <= 1'b0;
            dividend_reg <= 16'd0;
            quotient_reg <= 16'd0;
            counter <= 5'd0;
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 5'd0;
                    
                    if (start) begin
                        if (m == 16'd0) begin
                            // Division by zero: return 0,0
                            q <= 16'd0;
                            r <= 16'd0;
                        end else begin
                            // Initialize for division
                            dividend_reg <= n;
                            quotient_reg <= 16'd0;
                            counter <= 5'd0;
                        end
                    end
                end
                
                CALC: begin
                    // Shift-subtract algorithm iteration
                    if (counter < 5'd16) begin
                        // Shift quotient left (we build it bitwise)
                        quotient_reg <= quotient_reg << 1;
                        
                        // Try subtraction
                        if (can_subtract) begin
                            // Subtraction succeeds
                            dividend_reg <= sub_result[15:0];
                            quotient_reg[0] <= 1'b1; // Set bit 0 of quotient
                        end else begin
                            // Subtraction fails, just shift
                            // quotient_reg[0] is already 0 from shift
                        end
                        
                        counter <= counter + 5'd1;
                    end
                end
                
                FINISH: begin
                    // Finalize result
                    if (m == 16'd0) begin
                        // Division by zero case already handled in IDLE
                        q <= 16'd0;
                        r <= 16'd0;
                    end else begin
                        // Normal completion
                        q <= quotient_reg;
                        r <= dividend_reg;
                    end
                    done <= 1'b1;
                    
                    // Return to IDLE next cycle
                end
                
                default: begin
                    q <= 16'd0;
                    r <= 16'd0;
                    done <= 1'b0;
                    dividend_reg <= 16'd0;
                    quotient_reg <= 16'd0;
                    counter <= 5'd0;
                end
            endcase
        end
    end

endmodule