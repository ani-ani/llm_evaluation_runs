module decimal_to_fraction(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] total_digits,
    input wire [3:0] repeat_digits,
    input wire [11:0] scaled_value,
    output reg [31:0] numerator,
    output reg [31:0] denominator,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE_N = 3'd1;
    localparam [2:0] COMPUTE_D = 3'd2;
    localparam [2:0] COMPUTE_GCD = 3'd3;
    localparam [2:0] REDUCE    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Intermediate values
    reg [31:0] N1;
    reg [31:0] N2;
    reg [31:0] temp_numerator;
    reg [31:0] temp_denominator;
    reg [31:0] a;
    reg [31:0] b;
    reg [31:0] gcd_result;

    // GCD computation variables
    reg [31:0] gcd_a;
    reg [31:0] gcd_b;
    reg [31:0] gcd_temp;

    // Compute powers of 10
    reg [31:0] pow10_A;
    reg [31:0] pow10_B;
    reg [31:0] pow10_B_minus_1;

    // Power computation state
    reg [3:0] power_state;
    reg [31:0] power_result;
    reg [31:0] power_base;
    reg [4:0] power_exponent;
    reg [31:0] power_temp;

    // Extract N1 and N2
    reg [31:0] integer_part;
    reg [31:0] fractional_part;
    reg [31:0] non_repeating_part;
    reg [31:0] repeating_part;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            N1 <= 32'd0;
            N2 <= 32'd0;
            temp_numerator <= 32'd0;
            temp_denominator <= 32'd0;
            a <= 32'd0;
            b <= 32'd0;
            gcd_result <= 32'd0;
            gcd_a <= 32'd0;
            gcd_b <= 32'd0;
            pow10_A <= 32'd0;
            pow10_B <= 32'd0;
            pow10_B_minus_1 <= 32'd0;
            power_state <= 4'd0;
            power_result <= 32'd0;
            power_base <= 32'd0;
            power_exponent <= 5'd0;
            integer_part <= 32'd0;
            fractional_part <= 32'd0;
            non_repeating_part <= 32'd0;
            repeating_part <= 32'd0;
            numerator <= 32'd0;
            denominator <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_N;
                    end
                end

                COMPUTE_N: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Extract integer and fractional parts
                    integer_part <= scaled_value[11:4];
                    fractional_part <= scaled_value[3:0];
                    
                    // Compute non-repeating and repeating parts
                    non_repeating_part <= fractional_part >> repeat_digits;
                    repeating_part <= fractional_part & ((1 << repeat_digits) - 1);
                    
                    // Compute N1 = integer_part * 10^A + non_repeating_part
                    // Compute N2 = repeating_part
                    N2 <= repeating_part;
                    
                    // Compute 10^A
                    power_base <= 32'd10;
                    power_exponent <= total_digits;
                    power_state <= 4'd1;
                    state <= COMPUTE_D;
                end

                COMPUTE_D: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute power of 10
                    case (power_state)
                        4'd1: begin
                            power_result <= 32'd1;
                            power_temp <= 32'd1;
                            power_state <= 4'd2;
                        end
                        4'd2: begin
                            if (power_exponent > 5'd0) begin
                                power_temp <= power_temp * power_base;
                                power_exponent <= power_exponent - 5'd1;
                            end else begin
                                power_result <= power_temp;
                                power_state <= 4'd0;
                                pow10_A <= power_result;
                                
                                // Compute 10^B
                                power_base <= 32'd10;
                                power_exponent <= repeat_digits;
                                power_state <= 4'd1;
                                state <= COMPUTE_D;
                            end
                        end
                        default: begin
                            power_state <= 4'd0;
                            pow10_B <= power_result;
                            pow10_B_minus_1 <= pow10_B - 32'd1;
                            
                            // Compute N1
                            N1 <= (integer_part * pow10_A) + non_repeating_part;
                            
                            // Compute temp_numerator and temp_denominator
                            temp_numerator <= (N1 * pow10_B_minus_1) + N2;
                            temp_denominator <= pow10_A * pow10_B_minus_1;
                            
                            state <= COMPUTE_GCD;
                        end
                    endcase
                end

                COMPUTE_GCD: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Initialize GCD computation
                    gcd_a <= temp_numerator;
                    gcd_b <= temp_denominator;
                    
                    if (gcd_b == 32'd0) begin
                        gcd_result <= gcd_a;
                        state <= REDUCE;
                    end else begin
                        state <= REDUCE;
                    end
                end

                REDUCE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Iterative GCD computation
                    if (gcd_b == 32'd0) begin
                        gcd_result <= gcd_a;
                        state <= FINISH;
                    end else if (gcd_a > gcd_b) begin
                        gcd_a <= gcd_a - gcd_b;
                    end else begin
                        gcd_temp <= gcd_a;
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_temp;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Reduce fraction by GCD
                    numerator <= temp_numerator / gcd_result;
                    denominator <= temp_denominator / gcd_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule