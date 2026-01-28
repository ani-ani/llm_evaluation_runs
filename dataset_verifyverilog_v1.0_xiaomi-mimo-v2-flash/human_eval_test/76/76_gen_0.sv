module SimplePowerOfN(
    input clk,
    input rst_n,
    input start,
    input [15:0] x_i,
    input [15:0] n_i,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CHECK_EDGE  = 3'd1;
    localparam [2:0] COMPUTE     = 3'd2;
    localparam [2:0] DONE_STATE  = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] x_reg;
    reg [15:0] n_reg;
    reg [3:0] counter;           // Iteration counter (max 16)
    reg local_result;
    
    // Combinational signals for division
    reg [15:0] quotient;
    reg [15:0] remainder;
    reg [15:0] divisor;
    reg [15:0] dividend;
    reg division_valid;
    
    // Division counter (sequential divider)
    reg [3:0] div_counter;
    reg [31:0] dividend_ext;     // Extended dividend for shifting
    reg div_done;
    
    // Edge case flags
    reg n_is_zero;
    reg x_is_zero;
    reg x_is_one;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE:        next_state = start ? CHECK_EDGE : IDLE;
            CHECK_EDGE:  next_state = COMPUTE;
            COMPUTE:     next_state = (div_done || counter == 4'd15) ? DONE_STATE : COMPUTE;
            DONE_STATE:  next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            x_reg <= 16'd0;
            n_reg <= 16'd0;
            counter <= 4'd0;
            local_result <= 1'b0;
            div_counter <= 4'd0;
            dividend_ext <= 32'd0;
            divisor <= 16'd0;
            div_done <= 1'b0;
            quotient <= 16'd0;
            remainder <= 16'd0;
            division_valid <= 1'b0;
            n_is_zero <= 1'b0;
            x_is_zero <= 1'b0;
            x_is_one <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= x_i;
                        n_reg <= n_i;
                        counter <= 4'd0;
                        local_result <= 1'b0;
                    end
                end
                
                CHECK_EDGE: begin
                    // Set edge case flags
                    n_is_zero <= (n_reg == 16'd0);
                    x_is_zero <= (x_reg == 16'd0);
                    x_is_one <= (x_reg == 16'd1);
                    
                    // Initialize division
                    div_counter <= 4'd0;
                    dividend_ext <= {16'd0, x_reg};
                    divisor <= n_reg;
                    div_done <= 1'b0;
                    quotient <= 16'd0;
                    remainder <= 16'd0;
                    division_valid <= 1'b0;
                    
                    // Determine immediate edge cases
                    if (n_reg == 16'd0) begin
                        // n=0: only true if x=1
                        local_result <= (x_reg == 16'd1);
                        div_done <= 1'b1;
                    end else if (x_reg == 16'd0) begin
                        // x=0: never true (for n>0)
                        local_result <= 1'b0;
                        div_done <= 1'b1;
                    end else if (x_reg == 16'd1) begin
                        // x=1: always true for any n>0
                        local_result <= 1'b1;
                        div_done <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    if (!div_done && divisor != 16'd0) begin
                        // Sequential division (16 cycles per division)
                        if (div_counter < 4'd16) begin
                            dividend_ext <= dividend_ext << 1;
                            div_counter <= div_counter + 4'd1;
                            
                            if (dividend_ext[31:16] >= divisor) begin
                                dividend_ext[31:16] <= dividend_ext[31:16] - divisor;
                                quotient <= (quotient << 1) | 16'd1;
                            end else begin
                                quotient <= quotient << 1;
                            end
                        end else begin
                            // Division complete
                            remainder <= dividend_ext[31:16];
                            division_valid <= 1'b1;
                            
                            // Check division result
                            if (dividend_ext[31:16] != 16'd0) begin
                                // Non-zero remainder, not a power
                                local_result <= 1'b0;
                                div_done <= 1'b1;
                            end else begin
                                // Quotient becomes new x
                                counter <= counter + 4'd1;
                                
                                if (quotient == 16'd1) begin
                                    // Reached 1, valid power
                                    local_result <= 1'b1;
                                    div_done <= 1'b1;
                                end else begin
                                    // Continue with new quotient
                                    x_reg <= quotient;
                                    div_counter <= 4'd0;
                                    dividend_ext <= {16'd0, quotient};
                                    divisor <= n_reg;
                                    quotient <= 16'd0;
                                    remainder <= 16'd0;
                                    division_valid <= 1'b0;
                                end
                            end
                        end
                    end
                end
                
                DONE_STATE: begin
                    result <= local_result;
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
    
    // State update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

endmodule