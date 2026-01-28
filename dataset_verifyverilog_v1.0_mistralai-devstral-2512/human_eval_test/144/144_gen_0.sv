module fraction_whole_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] num1,
    input wire [7:0] den1,
    input wire [7:0] num2,
    input wire [7:0] den2,
    output reg is_whole,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALCULATE_PRODUCTS = 3'd1;
    localparam [2:0] CALCULATE_GCD = 3'd2;
    localparam [2:0] CHECK_RESULT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] numerator_product;
    reg [15:0] denominator_product;
    reg [15:0] gcd_a, gcd_b;
    reg [15:0] temp_gcd;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Euclidean GCD calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            numerator_product <= 16'd0;
            denominator_product <= 16'd0;
            gcd_a <= 16'd0;
            gcd_b <= 16'd0;
            temp_gcd <= 16'd0;
            cycle_count <= 8'd0;
            is_whole <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    is_whole <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALCULATE_PRODUCTS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALCULATE_PRODUCTS: begin
                    numerator_product <= num1 * num2;
                    denominator_product <= den1 * den2;
                    next_state <= CALCULATE_GCD;
                end

                CALCULATE_GCD: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count < MAX_CYCLES) begin
                        if (denominator_product == 16'd0) begin
                            next_state <= CHECK_RESULT;
                        end else if (numerator_product == 16'd0) begin
                            next_state <= CHECK_RESULT;
                        end else begin
                            gcd_a <= numerator_product;
                            gcd_b <= denominator_product;
                            
                            // Euclidean algorithm
                            if (gcd_a > gcd_b) begin
                                temp_gcd <= gcd_a % gcd_b;
                                gcd_a <= gcd_b;
                                gcd_b <= temp_gcd;
                            end else begin
                                temp_gcd <= gcd_b % gcd_a;
                                gcd_b <= gcd_a;
                                gcd_a <= temp_gcd;
                            end
                            
                            if (gcd_b == 16'd0) begin
                                next_state <= CHECK_RESULT;
                            end else begin
                                next_state <= CALCULATE_GCD;
                            end
                        end
                    end else begin
                        next_state <= CHECK_RESULT;
                    end
                end

                CHECK_RESULT: begin
                    if (denominator_product / gcd_b == 16'd1) begin
                        is_whole <= 1'b1;
                    end else begin
                        is_whole <= 1'b0;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    is_whole <= 1'b0;
                end
            endcase
            state <= next_state;
        end
    end
endmodule