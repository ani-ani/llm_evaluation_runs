module triangle_area(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] VALIDATE = 3'd1;
    localparam [2:0] COMPUTE_S = 3'd2;
    localparam [2:0] COMPUTE_P = 3'd3;
    localparam [2:0] SQRT_START = 3'd4;
    localparam [2:0] SQRT_LOOP = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd120;

    // Internal registers for computation
    reg [31:0] a_fp, b_fp, c_fp;  // Q16.16 format
    reg [31:0] s, s_minus_a, s_minus_b, s_minus_c;
    reg [31:0] product;
    reg [31:0] sqrt_operand, sqrt_guess, sqrt_next_guess;
    reg [4:0] sqrt_iteration;
    localparam [4:0] MAX_SQRT_ITER = 5'd10;

    // Convert inputs to Q16.16 format
    always @(*) begin
        a_fp = {16'd0, a};
        b_fp = {16'd0, b};
        c_fp = {16'd0, c};
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sqrt_iteration <= 5'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= VALIDATE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                VALIDATE: begin
                    // Check triangle inequality: a+b > c, a+c > b, b+c > a
                    if ((a + b) > c && (a + c) > b && (b + c) > a) begin
                        next_state <= COMPUTE_S;
                    end else begin
                        result <= 32'hFFFFFFFF;
                        next_state <= DONE_STATE;
                    end
                end

                COMPUTE_S: begin
                    // s = (a + b + c) / 2 in Q16.16 format
                    s <= (a_fp + b_fp + c_fp) >> 1;
                    next_state <= COMPUTE_P;
                end

                COMPUTE_P: begin
                    // Compute product = s*(s-a)*(s-b)*(s-c)
                    s_minus_a <= s - a_fp;
                    s_minus_b <= s - b_fp;
                    s_minus_c <= s - c_fp;
                    
                    // Multiply in stages to avoid overflow
                    reg [31:0] temp1, temp2;
                    temp1 = $signed(s_minus_a) * $signed(s_minus_b);
                    temp2 = $signed(s_minus_c) * $signed(s);
                    product <= $signed(temp1) * $signed(temp2);
                    
                    next_state <= SQRT_START;
                end

                SQRT_START: begin
                    // Initialize sqrt calculation
                    if (product == 32'd0) begin
                        result <= 32'd0;
                        next_state <= DONE_STATE;
                    end else begin
                        sqrt_operand <= product;
                        // Initial guess: operand >> 1 or 512 for small values
                        if (product[31]) begin
                            sqrt_guess <= 32'd512;
                        end else begin
                            sqrt_guess <= product >> 1;
                        end
                        sqrt_iteration <= 5'd0;
                        next_state <= SQRT_LOOP;
                    end
                end

                SQRT_LOOP: begin
                    // Babylonian iteration: next_guess = (guess + operand/guess) / 2
                    reg [31:0] division_result;
                    if (sqrt_guess != 32'd0) begin
                        division_result = sqrt_operand / sqrt_guess;
                    end else begin
                        division_result = 32'd0;
                    end
                    
                    sqrt_next_guess <= (sqrt_guess + division_result) >> 1;
                    sqrt_guess <= sqrt_next_guess;
                    
                    sqrt_iteration <= sqrt_iteration + 5'd1;
                    if (sqrt_iteration >= MAX_SQRT_ITER || cycle_count >= MAX_CYCLES) begin
                        result <= sqrt_next_guess;
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= SQRT_LOOP;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule