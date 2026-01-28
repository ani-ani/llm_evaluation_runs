module FractionProductCheck (
    input clk,
    input rst_n,
    input start,
    input [7:0] num1,
    input [7:0] den1,
    input [7:0] num2,
    input [7:0] den2,
    output reg is_whole,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CALC_PRODUCTS  = 3'd1;
    localparam [2:0] CALC_GCD       = 3'd2;
    localparam [2:0] CHECK_RESULT   = 3'd3;
    localparam [2:0] DONE_STATE     = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] numerator_product;
    reg [15:0] denominator_product;
    reg [15:0] gcd_a, gcd_b;
    reg [15:0] gcd_temp;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // GCD computation registers
    reg gcd_done;
    wire [15:0] gcd_result;
    
    // GCD Module (combinational)
    // Euclidean algorithm using subtraction (simpler for Verilog)
    reg [15:0] gcd_a_reg, gcd_b_reg;
    wire [15:0] gcd_diff;
    assign gcd_diff = gcd_a_reg - gcd_b_reg;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            numerator_product <= 16'd0;
            denominator_product <= 16'd0;
            gcd_a <= 16'd0;
            gcd_b <= 16'd0;
            gcd_a_reg <= 16'd0;
            gcd_b_reg <= 16'd0;
            cycle_counter <= 8'd0;
            is_whole <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        // Start calculation
                        cycle_counter <= 8'd1;
                    end
                end
                
                CALC_PRODUCTS: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Calculate products (16-bit max)
                    numerator_product <= num1 * num2;
                    denominator_product <= den1 * den2;
                    // Initialize GCD registers
                    gcd_a_reg <= num1 * num2;
                    gcd_b_reg <= den1 * den2;
                end
                
                CALC_GCD: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Euclidean algorithm using subtraction
                    if (gcd_a_reg == 16'd1 || gcd_b_reg == 16'd1) begin
                        // GCD is 1
                        gcd_a_reg <= 16'd1;
                        gcd_b_reg <= 16'd1;
                    end else if (gcd_a_reg > gcd_b_reg) begin
                        gcd_a_reg <= gcd_diff;
                    end else if (gcd_b_reg > gcd_a_reg) begin
                        gcd_b_reg <= gcd_b_reg - gcd_a_reg;
                    end else begin
                        // Equal (GCD found)
                        // Result is in gcd_a_reg
                    end
                end
                
                CHECK_RESULT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Check if denominator_product / gcd == 1
                    // Equivalent to denominator_product == gcd
                    if (gcd_a_reg == denominator_product && denominator_product != 16'd0) begin
                        // When gcd == denominator, the ratio is 1 (whole number)
                        is_whole <= 1'b1;
                    end else begin
                        is_whole <= 1'b0;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_PRODUCTS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CALC_PRODUCTS: begin
                // Products computed in one cycle
                next_state = CALC_GCD;
            end
            
            CALC_GCD: begin
                // Terminate when:
                // 1. GCD found (both equal)
                // 2. One value becomes 1
                // 3. Cycle limit reached (safety)
                if (cycle_counter >= 8'd150) begin
                    next_state = CHECK_RESULT; // Timeout
                end else if (gcd_a_reg == gcd_b_reg) begin
                    next_state = CHECK_RESULT;
                end else if (gcd_a_reg == 16'd1 || gcd_b_reg == 16'd1) begin
                    next_state = CHECK_RESULT;
                end else begin
                    next_state = CALC_GCD;
                end
            end
            
            CHECK_RESULT: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                // Single cycle done pulse, then back to IDLE
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule