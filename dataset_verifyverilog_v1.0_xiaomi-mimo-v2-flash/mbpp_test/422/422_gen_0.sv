module AverageOfCubes (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] COMPUTE  = 3'd1;
    localparam [2:0] DIVIDE   = 3'd2;
    localparam [2:0] ROUND    = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    // FSM registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Computation registers
    reg [7:0] counter;          // i from 1 to n
    reg [23:0] cube;           // i³ (max 24 bits)
    reg [35:0] sum;            // Σ(i³) (max 35 bits)
    reg [35:0] sum_latched;    // Latched sum for division
    reg [15:0] quotient;       // Q16.16 result
    reg [15:0] remainder;      // For division
    reg [7:0] shift_count;     // For shift-based division
    reg [35:0] dividend;       // Dividend for division
    reg [7:0] n_latched;       // Latched n value
    
    // Counter for i³ computation (i² needed)
    reg [15:0] i_squared;      // i² (max 255² = 65025, fits in 16 bits)
    
    // Cycle counter for safety
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd500;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? COMPUTE : IDLE;
            COMPUTE:    next_state = (counter == n_latched) ? DIVIDE : COMPUTE;
            DIVIDE:     next_state = (shift_count == 8'd16) ? ROUND : DIVIDE;
            ROUND:      next_state = FINISH;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            counter <= 8'd0;
            cube <= 24'd0;
            sum <= 36'd0;
            sum_latched <= 36'd0;
            quotient <= 16'd0;
            remainder <= 16'd0;
            shift_count <= 8'd0;
            dividend <= 36'd0;
            n_latched <= 8'd0;
            i_squared <= 16'd0;
            cycle_count <= 9'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 9'd0;
                    if (start) begin
                        // Latch n value
                        n_latched <= n;
                        // Initialize computation
                        counter <= 8'd1;       // Start from i=1
                        i_squared <= 16'd1;    // 1² = 1
                        sum <= 36'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    // Compute i³ = i * i²
                    // i_squared is i², need to multiply by i (counter)
                    cube <= counter * i_squared;
                    
                    // Accumulate sum
                    sum <= sum + (counter * i_squared);
                    
                    // Update i_squared for next iteration
                    // (i+1)² = i² + 2i + 1
                    i_squared <= i_squared + ((counter << 1) + 16'd1);
                    
                    // Increment counter
                    counter <= counter + 8'd1;
                    
                    // Check for completion
                    if (counter == n_latched) begin
                        sum_latched <= sum + (counter * i_squared);
                    end
                    
                    // Safety: prevent infinite loop
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DIVIDE;
                    end
                end
                
                DIVIDE: begin
                    // Binary division: result = (sum << 16) / n
                    // First cycle: set up dividend and initialize
                    if (shift_count == 8'd0) begin
                        dividend <= {sum_latched[35:0], 16'd0};  // sum * 2^16
                        quotient <= 16'd0;
                        remainder <= 16'd0;
                        shift_count <= 8'd1;
                    end else begin
                        // Shift divisor (n_latched) to align with current bit
                        // We're doing: dividend / n
                        // Using repeated subtraction algorithm
                        shift_count <= shift_count + 8'd1;
                        
                        // Current bit position (from MSB)
                        // quotient << 1, then possibly add 1
                        quotient <= quotient << 1;
                        
                        // Subtract n_latched from current dividend remainder
                        // Use remaining dividend bits
                        remainder <= remainder << 1;
                        dividend <= dividend << 1;
                        
                        // Check if we can subtract
                        // This is simplified: using remainder
                        // For Q16.16, we do 16 iterations
                        
                        // Alternative: direct calculation for 16-bit quotient
                        // quotient = dividend[51:16] / n_latched (but dividend is 52 bits)
                    end
                    
                    // For this implementation, use combinational division
                    // since we have explicit cycle count
                    if (shift_count == 8'd15) begin
                        // Final division result
                        quotient <= dividend[51:16] / n_latched;
                        shift_count <= 8'd16;
                    end
                end
                
                ROUND: begin
                    // Already computed exact division in DIVIDE state
                    // Rounding is truncation (round to nearest with truncation)
                    state <= FINISH;
                end
                
                FINISH: begin
                    // Output result in Q16.16 format
                    result <= {16'd0, quotient};  // 32-bit: 16 integer, 16 fractional
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Combinational logic for division (simpler approach)
    // Using combinational division to avoid complex iterative logic
    reg [51:0] div_temp;
    reg [15:0] div_result;
    
    always @(*) begin
        // Compute: (sum_latched << 16) / n_latched
        div_temp = {sum_latched, 16'd0};  // 52 bits
        if (n_latched != 8'd0) begin
            div_result = div_temp[51:16] / n_latched;
        end else begin
            div_result = 16'd0;
        end
    end
    
    // Override division state logic to use combinational result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == DIVIDE && shift_count == 8'd1) begin
                quotient <= div_result;
                shift_count <= 8'd16;  // Mark as complete
            end
        end
    end

endmodule