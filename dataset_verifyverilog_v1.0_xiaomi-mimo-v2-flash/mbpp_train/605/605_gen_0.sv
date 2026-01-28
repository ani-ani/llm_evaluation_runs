module prime_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] num_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_SPECIAL = 3'd1;
    localparam [2:0] ITERATE = 3'd2;
    localparam [2:0] CALC_MOD = 3'd3;
    localparam [2:0] CHECK_MOD = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    localparam [2:0] UPDATE_DIVISOR = 3'd6;
    
    // Register declarations
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] num_reg;
    reg [7:0] divisor;
    reg [7:0] remainder;
    reg [7:0] subtraction_count;
    reg [7:0] cycle_count;
    reg is_prime_flag;
    
    // Constants
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_SPECIAL;
                end
            end
            CHECK_SPECIAL: begin
                // Check if num < 2 or num == 2
                if (num_reg < 2) begin
                    next_state = DONE_STATE;
                end else if (num_reg == 2) begin
                    next_state = DONE_STATE;
                end else if (num_reg[0] == 0) begin
                    // Even number > 2
                    next_state = DONE_STATE;
                end else begin
                    // Odd number >= 3
                    divisor = 8'd3;
                    is_prime_flag = 1'b1;
                    next_state = ITERATE;
                end
            end
            ITERATE: begin
                // Check if divisor > num/2 (num_reg >> 1)
                if ({1'b0, divisor[7:1]} >= num_reg) begin
                    next_state = DONE_STATE;
                end else begin
                    // Start division by subtraction
                    remainder = num_reg;
                    subtraction_count = 8'd0;
                    next_state = CALC_MOD;
                end
            end
            CALC_MOD: begin
                // Subtract divisor from remainder
                if (remainder >= divisor) begin
                    remainder = remainder - divisor;
                    subtraction_count = subtraction_count + 8'd1;
                    next_state = CALC_MOD;
                end else begin
                    next_state = CHECK_MOD;
                end
            end
            CHECK_MOD: begin
                // Check if remainder is 0 (divisible)
                if (remainder == 8'd0) begin
                    is_prime_flag = 1'b0;
                    next_state = DONE_STATE;
                end else begin
                    next_state = UPDATE_DIVISOR;
                end
            end
            UPDATE_DIVISOR: begin
                // Increment divisor by 2 (skip even numbers)
                divisor = divisor + 8'd2;
                next_state = ITERATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            num_reg <= 8'd0;
            divisor <= 8'd0;
            remainder <= 8'd0;
            subtraction_count <= 8'd0;
            cycle_count <= 8'd0;
            is_prime_flag <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        num_reg <= num_in;
                        cycle_count <= 8'd0;
                    end
                end
                CHECK_SPECIAL: begin
                    cycle_count <= cycle_count + 8'd1;
                end
                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                end
                CALC_MOD: begin
                    cycle_count <= cycle_count + 8'd1;
                end
                CHECK_MOD: begin
                    cycle_count <= cycle_count + 8'd1;
                end
                UPDATE_DIVISOR: begin
                    cycle_count <= cycle_count + 8'd1;
                end
                DONE_STATE: begin
                    // Set result based on special cases
                    if (num_reg < 2) begin
                        result <= 1'b0;
                    end else if (num_reg == 2) begin
                        result <= 1'b1;
                    end else if (num_reg[0] == 0) begin
                        result <= 1'b0;
                    end else begin
                        result <= is_prime_flag;
                    end
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule