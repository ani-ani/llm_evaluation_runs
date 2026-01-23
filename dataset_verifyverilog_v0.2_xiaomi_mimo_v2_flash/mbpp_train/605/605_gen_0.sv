module prime_checker (
    input clk,
    input rst_n,
    input start,
    input [31:0] num_in,
    output reg is_prime,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK = 3'b010;
    localparam ITERATE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state, next_state;
    reg [31:0] i;              // Divisor
    reg [31:0] i_plus_1;       // Pre-calculated i+1 for comparison
    reg [31:0] num_in_reg;     // Stored input number
    reg is_prime_reg;          // Internal flag
    
    // Combinational signals
    wire [63:0] i_squared;     // 64-bit to prevent overflow
    wire [31:0] remainder;
    wire [31:0] i_next;
    
    // Combinational calculations
    assign i_squared = {32'b0, i} * {32'b0, i};
    assign remainder = num_in_reg % i;
    assign i_next = i + 1;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        // Default next state to current to avoid latches
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            
            INIT: begin
                next_state = CHECK;
            end
            
            CHECK: begin
                if (remainder == 0) begin
                    next_state = DONE; // Found divisor
                end else begin
                    next_state = ITERATE;
                end
            end
            
            ITERATE: begin
                if (i_next > 32'd128 || i_squared > {32'b0, num_in_reg}) begin
                    next_state = DONE; // Limit reached or passed sqrt
                end else begin
                    next_state = CHECK; // Continue checking
                end
            end
            
            DONE: begin
                // Hold state until reset or new start
                // Only exit if reset is asserted (handled by reset logic)
                if (start) next_state = INIT; // Allow restart
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_prime <= 1'b0;
            done <= 1'b0;
            i <= 32'd0;
            num_in_reg <= 32'd0;
            is_prime_reg <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    is_prime <= 1'b0;
                end
                
                INIT: begin
                    // Handle special cases immediately
                    if (num_in < 2) begin
                        is_prime_reg <= 1'b0;
                        is_prime <= 1'b0;
                    end else if (num_in == 2 || num_in == 3) begin
                        is_prime_reg <= 1'b1;
                        is_prime <= 1'b1;
                    end else begin
                        // Start checking from 2
                        i <= 32'd2;
                        is_prime_reg <= 1'b1; // Assume prime until proven otherwise
                        num_in_reg <= num_in;
                        is_prime <= 1'b1; // Default high, will be cleared if composite
                    end
                end
                
                CHECK: begin
                    // Remainder calculated combinationally
                    if (remainder == 0 && num_in_reg >= 2 && num_in_reg != 2 && num_in_reg != 3) begin
                        is_prime_reg <= 1'b0;
                        is_prime <= 1'b0;
                    end
                end
                
                ITERATE: begin
                    // Increment divisor
                    i <= i_next;
                    // Update output if still prime
                    if (is_prime_reg) begin
                        is_prime <= 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    // Final determination
                    if (num_in_reg < 2) begin
                        is_prime <= 1'b0;
                    end else if (num_in_reg == 2 || num_in_reg == 3) begin
                        is_prime <= 1'b1;
                    end else begin
                        is_prime <= is_prime_reg;
                    end
                end
            endcase
        end
    end

endmodule