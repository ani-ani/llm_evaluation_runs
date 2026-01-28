module fuel_calculator (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [9:0] m,
    input [9:0] a_i_0,
    input [9:0] a_i_1,
    input [9:0] a_i_2,
    input [9:0] a_i_3,
    input [9:0] a_i_4,
    input [9:0] a_i_5,
    input [9:0] a_i_6,
    input [9:0] a_i_7,
    input [9:0] b_i_0,
    input [9:0] b_i_1,
    input [9:0] b_i_2,
    input [9:0] b_i_3,
    input [9:0] b_i_4,
    input [9:0] b_i_5,
    input [9:0] b_i_6,
    input [9:0] b_i_7,
    output reg [63:0] fuel,
    output reg done,
    output reg impossible
);

    // Fixed-point constants
    localparam [63:0] FIXED_ONE = 64'd1 << 32;
    localparam [63:0] MAX_ITER = 64'd1000;
    
    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] CHECK_COEFF = 4'd1;
    localparam [3:0] SETUP_DIV   = 4'd2;
    localparam [3:0] DIVIDING    = 4'd3;
    localparam [3:0] MULTIPLY    = 4'd4;
    localparam [3:0] SUBTRACT    = 4'd5;
    localparam [3:0] FINISHED    = 4'd6;
    
    reg [3:0] state, next_state;
    reg [3:0] planet_idx;
    reg [3:0] operation_idx; // 0=a, 1=b
    reg [63:0] product;
    reg [63:0] multiplier;
    reg [63:0] temp_result;
    
    // Divider signals
    reg div_start;
    reg [63:0] dividend;
    reg [9:0] divisor;
    wire [63:0] div_result;
    wire div_done;
    wire div_divisible;
    
    // Coefficient storage (packed for Icarus compatibility)
    reg [9:0] coeff_a [0:7];
    reg [9:0] coeff_b [0:7];
    integer i;
    
    // Instantiate fixed-point divider
    fixed_point_divider #(.WIDTH(64)) divider (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .dividend(dividend),
        .divisor(divisor),
        .result(div_result),
        .done(div_done),
        .divisible(div_divisible)
    );
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            planet_idx <= 4'd0;
            operation_idx <= 4'd0;
            product <= 64'd0;
            multiplier <= 64'd0;
            temp_result <= 64'd0;
            fuel <= 64'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            div_start <= 1'b0;
            dividend <= 64'd0;
            divisor <= 10'd0;
            // Initialize coefficient arrays
            coeff_a[0] <= 10'd0; coeff_a[1] <= 10'd0; coeff_a[2] <= 10'd0; coeff_a[3] <= 10'd0;
            coeff_a[4] <= 10'd0; coeff_a[5] <= 10'd0; coeff_a[6] <= 10'd0; coeff_a[7] <= 10'd0;
            coeff_b[0] <= 10'd0; coeff_b[1] <= 10'd0; coeff_b[2] <= 10'd0; coeff_b[3] <= 10'd0;
            coeff_b[4] <= 10'd0; coeff_b[5] <= 10'd0; coeff_b[6] <= 10'd0; coeff_b[7] <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        // Load coefficients
                        coeff_a[0] <= a_i_0; coeff_a[1] <= a_i_1; coeff_a[2] <= a_i_2; coeff_a[3] <= a_i_3;
                        coeff_a[4] <= a_i_4; coeff_a[5] <= a_i_5; coeff_a[6] <= a_i_6; coeff_a[7] <= a_i_7;
                        coeff_b[0] <= b_i_0; coeff_b[1] <= b_i_1; coeff_b[2] <= b_i_2; coeff_b[3] <= b_i_3;
                        coeff_b[4] <= b_i_4; coeff_b[5] <= b_i_5; coeff_b[6] <= b_i_6; coeff_b[7] <= b_i_7;
                        product <= FIXED_ONE; // Start with 1.0 in Q32.32
                        planet_idx <= 4'd0;
                        operation_idx <= 4'd0;
                        state <= CHECK_COEFF;
                    end
                end
                
                CHECK_COEFF: begin
                    if (planet_idx < n) begin
                        // Check current coefficient
                        if (operation_idx == 4'd0) begin
                            // Checking a_i
                            if (coeff_a[planet_idx] <= 10'd1) begin
                                impossible <= 1'b1;
                                state <= FINISHED;
                            end else begin
                                operation_idx <= 4'd1; // Check b next
                            end
                        end else begin
                            // Checking b_i
                            if (coeff_b[planet_idx] <= 10'd1) begin
                                impossible <= 1'b1;
                                state <= FINISHED;
                            end else begin
                                operation_idx <= 4'd0; // Reset for next planet
                                planet_idx <= planet_idx + 4'd1;
                            end
                        end
                    end else begin
                        // All coefficients checked
                        planet_idx <= 4'd0;
                        operation_idx <= 4'd0;
                        state <= SETUP_DIV;
                    end
                end
                
                SETUP_DIV: begin
                    if (planet_idx < n) begin
                        if (operation_idx == 4'd0) begin
                            // Setup a_i / (a_i - 1)
                            dividend <= FIXED_ONE;
                            divisor <= coeff_a[planet_idx] - 10'd1;
                            div_start <= 1'b1;
                        end else begin
                            // Setup b_i / (b_i - 1)
                            dividend <= FIXED_ONE;
                            divisor <= coeff_b[planet_idx] - 10'd1;
                            div_start <= 1'b1;
                        end
                        state <= DIVIDING;
                    end else begin
                        // Done with all multiplications
                        state <= SUBTRACT;
                    end
                end
                
                DIVIDING: begin
                    div_start <= 1'b0;
                    if (div_done) begin
                        multiplier <= div_result;
                        state <= MULTIPLY;
                    end
                end
                
                MULTIPLY: begin
                    // product = product * multiplier >> 32
                    temp_result <= (product * multiplier) >> 32;
                    // Next operation
                    if (operation_idx == 4'd0) begin
                        operation_idx <= 4'd1; // Process b next
                    end else begin
                        operation_idx <= 4'd0; // Move to next planet
                        planet_idx <= planet_idx + 4'd1;
                    end
                    state <= SETUP_DIV;
                    // Update product after multiplication completes
                    product <= (product * multiplier) >> 32;
                end
                
                SUBTRACT: begin
                    // fuel = product - m
                    fuel <= product - {m, 32'd0}; // m in integer part
                    state <= FINISHED;
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

// Fixed-point divider module using restoring division
module fixed_point_divider #(
    parameter WIDTH = 64
) (
    input clk,
    input rst_n,
    input start,
    input [WIDTH-1:0] dividend,
    input [9:0] divisor,
    output reg [WIDTH-1:0] result,
    output reg done,
    output reg divisible
);

    localparam [4:0] DIV_IDLE = 5'd0;
    localparam [4:0] DIV_INIT = 5'd1;
    localparam [4:0] DIV_LOOP = 5'd2;
    localparam [4:0] DIV_DONE  = 5'd3;
    
    reg [4:0] div_state;
    reg [WIDTH-1:0] remainder;
    reg [WIDTH-1:0] quotient;
    reg [9:0] divisor_reg;
    reg [6:0] bit_count; // 64 bits
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_state <= DIV_IDLE;
            result <= 64'd0;
            done <= 1'b0;
            divisible <= 1'b0;
            remainder <= 64'd0;
            quotient <= 64'd0;
            divisor_reg <= 10'd0;
            bit_count <= 7'd0;
        end else begin
            case (div_state)
                DIV_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        div_state <= DIV_INIT;
                    end
                end
                
                DIV_INIT: begin
                    remainder <= dividend;
                    quotient <= 64'd0;
                    divisor_reg <= divisor;
                    bit_count <= 7'd64;
                    div_state <= DIV_LOOP;
                end
                
                DIV_LOOP: begin
                    if (bit_count > 7'd0) begin
                        // Shift left
                        remainder <= remainder << 1;
                        quotient <= quotient << 1;
                        
                        // Check if remainder >= divisor
                        if (remainder[WIDTH-1:0] >= {54'd0, divisor_reg}) begin
                            remainder <= remainder - {54'd0, divisor_reg};
                            quotient <= quotient | 64'd1;
                        end
                        bit_count <= bit_count - 7'd1;
                    end else begin
                        div_state <= DIV_DONE;
                    end
                end
                
                DIV_DONE: begin
                    result <= quotient;
                    divisible <= (quotient > 64'd0);
                    done <= 1'b1;
                    div_state <= DIV_IDLE;
                end
                
                default: div_state <= DIV_IDLE;
            endcase
        end
    end

endmodule