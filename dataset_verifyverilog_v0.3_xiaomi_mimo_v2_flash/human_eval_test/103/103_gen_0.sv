module rounded_avg(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [15:0] result,
    output reg error,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] CALC = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [16:0] sum_reg; // 17-bit for n+m (max 65535)
    reg [15:0] avg_reg;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            error <= 1'b0;
            done <= 1'b0;
            sum_reg <= 17'd0;
            avg_reg <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0; // Clear done when idle
                    if (start) begin
                        // Check condition immediately
                        if (n > m) begin
                            error <= 1'b1;
                            result <= 16'd0; // Don't care value
                        end else begin
                            error <= 1'b0;
                            sum_reg <= {1'b0, n} + {1'b0, m}; // Zero extend to 17 bits
                        end
                    end
                end
                
                CALC: begin
                    // Shift sum right by 1 (divide by 2)
                    // sum_reg[16:1] is integer part
                    // sum_reg[0] is remainder for rounding
                    avg_reg <= sum_reg[16:1] + sum_reg[0];
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (!error) begin
                        result <= avg_reg;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK;
                else next_state = IDLE;
            end
            
            CHECK: begin
                if (error) begin
                    next_state = DONE_STATE; // n > m, skip calculation
                end else begin
                    next_state = CALC;
                end
            end
            
            CALC: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE; // Return to idle after 1 cycle
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule