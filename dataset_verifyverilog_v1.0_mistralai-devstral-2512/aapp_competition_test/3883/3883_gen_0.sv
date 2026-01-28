module PolylineSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Fixed-point conversion constants
    localparam [31:0] FIXED_SCALE = 32'd65536; // 2^16

    // Registers
    reg [1:0] state;
    reg [31:0] a_fixed, b_fixed;
    reg [31:0] min_x;
    reg [5:0] k;
    reg [31:0] x1, x2;
    reg [31:0] temp_numerator;
    reg [31:0] temp_denominator;
    reg [31:0] div_result;
    reg [7:0] div_cycle;
    reg [31:0] remainder;
    reg [31:0] quotient;
    reg [31:0] abs_diff;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            k <= 6'd0;
            min_x <= 32'd4294967295; // -1 in Q16.16
            div_cycle <= 8'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Convert inputs to Q16.16
                        a_fixed <= a_in * FIXED_SCALE;
                        b_fixed <= b_in * FIXED_SCALE;
                        
                        // Check special cases
                        if (b_fixed > a_fixed) begin
                            min_x <= 32'd4294967295; // -1
                            state <= DONE_STATE;
                        end else if (a_fixed == b_fixed) begin
                            min_x <= a_fixed;
                            state <= DONE_STATE;
                        end else begin
                            state <= COMPUTE;
                            k <= 6'd1;
                            min_x <= 32'd4294967295; // Initialize to -1
                        end
                    end
                end

                COMPUTE: begin
                    // Check if we've found a valid x
                    if (k >= 6'd64) begin
                        state <= DONE_STATE;
                    end else begin
                        // Check x1 condition: k*2*b <= a - b
                        if (k * 2 * b_fixed <= a_fixed - b_fixed) begin
                            // Calculate x1 = (a - b) / (2*k)
                            temp_numerator <= a_fixed - b_fixed;
                            temp_denominator <= k * 2;
                            
                            // Start division
                            div_cycle <= 8'd0;
                            quotient <= 32'd0;
                            remainder <= temp_numerator;
                            state <= COMPUTE;
                        end
                        // Check x2 condition: k*2*b <= a + b
                        else if (k * 2 * b_fixed <= a_fixed + b_fixed) begin
                            // Calculate x2 = (a + b) / (2*k)
                            temp_numerator <= a_fixed + b_fixed;
                            temp_denominator <= k * 2;
                            
                            // Start division
                            div_cycle <= 8'd0;
                            quotient <= 32'd0;
                            remainder <= temp_numerator;
                            state <= COMPUTE;
                        end
                        
                        // If neither condition met, increment k
                        if (k * 2 * b_fixed > a_fixed - b_fixed && 
                            k * 2 * b_fixed > a_fixed + b_fixed) begin
                            k <= k + 6'd1;
                        end
                    end
                    
                    // Division algorithm (sequential)
                    if (div_cycle < 8'd16 && temp_denominator != 32'd0) begin
                        if (div_cycle == 8'd0) begin
                            remainder <= temp_numerator;
                            quotient <= 32'd0;
                        end else begin
                            // Shift remainder left
                            remainder <= remainder << 1;
                            
                            // Set LSB from numerator
                            if (div_cycle <= 8'd16) begin
                                remainder[0] <= temp_numerator[32 - div_cycle];
                            end
                            
                            // Subtract if possible
                            if (remainder >= temp_denominator) begin
                                remainder <= remainder - temp_denominator;
                                quotient[31 - (div_cycle - 1)] <= 1'b1;
                            end
                        end
                        
                        div_cycle <= div_cycle + 8'd1;
                        
                        // When division complete, update min_x
                        if (div_cycle == 8'd16) begin
                            div_result <= quotient;
                            
                            // Update min_x if this is smaller
                            if (div_result < min_x) begin
                                min_x <= div_result;
                            end
                            
                            // Increment k for next iteration
                            k <= k + 6'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= min_x;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule