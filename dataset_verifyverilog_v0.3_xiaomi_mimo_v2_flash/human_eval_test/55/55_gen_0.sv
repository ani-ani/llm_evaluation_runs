module fibonacci (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] counter_reg;
    reg [4:0] target_reg;
    reg [15:0] a_reg;          // Q16.16 fractional part only
    reg [15:0] b_reg;          // Q16.16 fractional part only
    reg [15:0] next_fib;       // Temporary for next Fibonacci number
    reg [7:0] cycle_count;     // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State transition and next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: next_state = CALCULATE;
            CALCULATE: begin
                if (counter_reg >= target_reg - 5'd1 || cycle_count >= MAX_CYCLES - 8'd1) begin
                    next_state = DONE;
                end else begin
                    next_state = CALCULATE;
                end
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            counter_reg <= 5'd0;
            target_reg <= 5'd0;
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            next_fib <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                end
                
                INIT: begin
                    counter_reg <= 5'd0;
                    target_reg <= n;
                    a_reg <= 16'd0;          // F(0) = 0
                    b_reg <= 16'd1;          // F(1) = 1 (in Q16.16: 1 << 16 = 65536, so fractional part is 16'd0)
                    // Actually, for F(1)=1, we need integer part 1, fractional part 0
                    // In Q16.16, value 1 = 0x00010000, so a_reg/b_reg store only fractional part
                    // We need to store the full Q16.16 value, but only fractional part is used
                    // Let's re-think: For F(0)=0, a_reg=16'd0, integer=0
                    // For F(1)=1, b_reg should be 0x00010000, but we only have 16 bits
                    // We need to store full 32-bit values or use a different approach
                    // Actually, let's store the integer values and multiply at the end
                    // Reset values: a_reg=0 (integer), b_reg=1 (integer)
                    a_reg <= 16'd0;
                    b_reg <= 16'd1;
                    cycle_count <= 8'd0;
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute next Fibonacci number
                    next_fib <= a_reg + b_reg;
                    
                    // Update registers
                    a_reg <= b_reg;
                    b_reg <= next_fib;
                    
                    // Increment counter
                    counter_reg <= counter_reg + 5'd1;
                end
                
                DONE: begin
                    // Convert to Q16.16 format: result = b << 16
                    // b_reg holds the integer Fibonacci number
                    result <= {b_reg, 16'd0};
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule