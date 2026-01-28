module ModularProduct(
    input clk,
    input rst_n,
    input start,
    input [15:0] arr_in,
    input valid_in,
    input [3:0] len,
    input [15:0] n,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] RECEIVE  = 3'd2;
    localparam [2:0] COMPUTE  = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] product_reg;
    reg [15:0] current_element;
    reg [3:0] element_count;
    reg [7:0] cycle_counter;
    reg [15:0] remainder_reg;
    reg [15:0] temp_mult;
    reg [31:0] mult_result;
    reg [15:0] mod_result;
    reg [15:0] divisor_reg;
    reg [15:0] dividend_reg;
    reg [15:0] quotient_reg;
    reg [15:0] subtract_count;
    reg [15:0] temp_remainder;
    reg [15:0] temp_dividend;
    reg [15:0] temp_divisor;
    reg [15:0] temp_quotient;
    reg [15:0] temp_product;
    reg [15:0] temp_n;
    reg [15:0] temp_element;
    reg [15:0] temp_remainder_reg;
    reg [15:0] temp_product_reg;
    reg [15:0] temp_mult_reg;
    reg [15:0] temp_mod_result;
    reg [15:0] temp_dividend_reg;
    reg [15:0] temp_divisor_reg;
    reg [15:0] temp_quotient_reg;
    reg [15:0] temp_subtract_count;
    reg [15:0] temp_temp_remainder;
    reg [15:0] temp_temp_dividend;
    reg [15:0] temp_temp_divisor;
    reg [15:0] temp_temp_quotient;
    reg [15:0] temp_temp_product;
    reg [15:0] temp_temp_n;
    reg [15:0] temp_temp_element;
    reg [15:0] temp_temp_remainder_reg;
    reg [15:0] temp_temp_product_reg;
    reg [15:0] temp_temp_mult_reg;
    reg [15:0] temp_temp_mod_result;
    reg [15:0] temp_temp_dividend_reg;
    reg [15:0] temp_temp_divisor_reg;
    reg [15:0] temp_temp_quotient_reg;
    reg [15:0] temp_temp_subtract_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            product_reg <= 16'd0;
            current_element <= 16'd0;
            element_count <= 4'd0;
            cycle_counter <= 8'd0;
            remainder_reg <= 16'd0;
            temp_mult <= 16'd0;
            mult_result <= 32'd0;
            mod_result <= 16'd0;
            divisor_reg <= 16'd0;
            dividend_reg <= 16'd0;
            quotient_reg <= 16'd0;
            subtract_count <= 16'd0;
            temp_remainder <= 16'd0;
            temp_dividend <= 16'd0;
            temp_divisor <= 16'd0;
            temp_quotient <= 16'd0;
            temp_product <= 16'd0;
            temp_n <= 16'd0;
            temp_element <= 16'd0;
            temp_remainder_reg <= 16'd0;
            temp_product_reg <= 16'd0;
            temp_mult_reg <= 16'd0;
            temp_mod_result <= 16'd0;
            temp_dividend_reg <= 16'd0;
            temp_divisor_reg <= 16'd0;
            temp_quotient_reg <= 16'd0;
            temp_subtract_count <= 16'd0;
            temp_temp_remainder <= 16'd0;
            temp_temp_dividend <= 16'd0;
            temp_temp_divisor <= 16'd0;
            temp_temp_quotient <= 16'd0;
            temp_temp_product <= 16'd0;
            temp_temp_n <= 16'd0;
            temp_temp_element <= 16'd0;
            temp_temp_remainder_reg <= 16'd0;
            temp_temp_product_reg <= 16'd0;
            temp_temp_mult_reg <= 16'd0;
            temp_temp_mod_result <= 16'd0;
            temp_temp_dividend_reg <= 16'd0;
            temp_temp_divisor_reg <= 16'd0;
            temp_temp_quotient_reg <= 16'd0;
            temp_temp_subtract_count <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            result <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && ready) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                next_state = RECEIVE;
            end
            RECEIVE: begin
                if (valid_in) begin
                    if (element_count == len - 1) begin
                        next_state = COMPUTE;
                    end
                end
            end
            COMPUTE: begin
                if (cycle_counter >= 8'd255) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Ready signal
    always @(*) begin
        ready = 1'b1;
        if (state != IDLE) begin
            ready = 1'b0;
        end
    end

    // Load state: initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else if (state == LOAD) begin
            product_reg <= 16'd1;  // Start with multiplicative identity
            element_count <= 4'd0;
            cycle_counter <= 8'd0;
            temp_n <= n;
        end
    end

    // Receive state: capture array elements
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else if (state == RECEIVE && valid_in) begin
            current_element <= arr_in;
            element_count <= element_count + 4'd1;
        end
    end

    // Compute state: process each element
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else if (state == COMPUTE) begin
            // Compute current_element % n using sequential subtraction
            if (subtract_count < 16'd256) begin
                if (temp_dividend >= temp_divisor) begin
                    temp_dividend <= temp_dividend - temp_divisor;
                    temp_quotient <= temp_quotient + 16'd1;
                end else begin
                    temp_remainder <= temp_dividend;
                    subtract_count <= 16'd0;
                    temp_quotient <= 16'd0;
                    temp_dividend <= 16'd0;
                    temp_divisor <= 16'd0;
                    // Multiply with accumulated product
                    temp_mult <= product_reg * temp_remainder;
                    // Compute temp_mult % n
                    if (temp_subtract_count < 16'd256) begin
                        if (temp_temp_dividend >= temp_temp_divisor) begin
                            temp_temp_dividend <= temp_temp_dividend - temp_temp_divisor;
                            temp_temp_quotient <= temp_temp_quotient + 16'd1;
                        end else begin
                            temp_temp_remainder <= temp_temp_dividend;
                            temp_subtract_count <= 16'd0;
                            temp_temp_quotient <= 16'd0;
                            temp_temp_dividend <= 16'd0;
                            temp_temp_divisor <= 16'd0;
                            product_reg <= temp_temp_remainder;
                            // Move to next element
                            if (element_count == len - 1) begin
                                cycle_counter <= 8'd255;
                            end else begin
                                element_count <= element_count + 4'd1;
                                temp_dividend <= current_element;
                                temp_divisor <= n;
                            end
                        end
                    end else begin
                        temp_temp_dividend <= temp_mult;
                        temp_temp_divisor <= n;
                        temp_subtract_count <= temp_subtract_count + 16'd1;
                    end
                end
            end else begin
                temp_dividend <= current_element;
                temp_divisor <= n;
                subtract_count <= subtract_count + 16'd1;
            end
        end
    end

    // Done state: output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else if (state == DONE) begin
            result <= product_reg;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Sequential subtraction for modulus
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else if (state == COMPUTE) begin
            if (subtract_count < 16'd256) begin
                if (temp_dividend >= temp_divisor) begin
                    temp_dividend <= temp_dividend - temp_divisor;
                    temp_quotient <= temp_quotient + 16'd1;
                end else begin
                    temp_remainder <= temp_dividend;
                    subtract_count <= 16'd0;
                    temp_quotient <= 16'd0;
                    temp_dividend <= 16'd0;
                    temp_divisor <= 16'd0;
                    // Multiply with accumulated product
                    temp_mult <= product_reg * temp_remainder;
                    // Compute temp_mult % n
                    if (temp_subtract_count < 16'd256) begin
                        if (temp_temp_dividend >= temp_temp_divisor) begin
                            temp_temp_dividend <= temp_temp_dividend - temp_temp_divisor;
                            temp_temp_quotient <= temp_temp_quotient + 16'd1;
                        end else begin
                            temp_temp_remainder <= temp_temp_dividend;
                            temp_subtract_count <= 16'd0;
                            temp_temp_quotient <= 16'd0;
                            temp_temp_dividend <= 16'd0;
                            temp_temp_divisor <= 16'd0;
                            product_reg <= temp_temp_remainder;
                            // Move to next element
                            if (element_count == len - 1) begin
                                cycle_counter <= 8'd255;
                            end else begin
                                element_count <= element_count + 4'd1;
                                temp_dividend <= current_element;
                                temp_divisor <= n;
                            end
                        end
                    end else begin
                        temp_temp_dividend <= temp_mult;
                        temp_temp_divisor <= n;
                        temp_subtract_count <= temp_subtract_count + 16'd1;
                    end
                end
            end else begin
                temp_dividend <= current_element;
                temp_divisor <= n;
                subtract_count <= subtract_count + 16'd1;
            end
        end
    end

endmodule