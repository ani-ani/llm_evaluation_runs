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
    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] VALIDATE   = 4'd1;
    localparam [3:0] VALIDATE_2 = 4'd2;
    localparam [3:0] VALIDATE_3 = 4'd3;
    localparam [3:0] COMPUTE_S  = 4'd4;
    localparam [3:0] COMPUTE_SA = 4'd5;
    localparam [3:0] COMPUTE_SB = 4'd6;
    localparam [3:0] COMPUTE_SC = 4'd7;
    localparam [3:0] COMPUTE_P1 = 4'd8;
    localparam [3:0] COMPUTE_P2 = 4'd9;
    localparam [3:0] SQRT_START = 4'd10;
    localparam [3:0] SQRT_LOOP  = 4'd11;
    localparam [3:0] DONE       = 4'd12;
    localparam [3:0] INVALID    = 4'd13;
    
    reg [3:0] state, next_state;
    reg [31:0] s, sa, sb, sc, product, operand, guess, next_guess;
    reg [7:0] iteration_counter;
    reg [3:0] val_check_counter;
    reg valid_triangle;
    
    // Constants
    localparam [31:0] SCALE = 32'd65536;
    localparam [7:0] MAX_ITER = 8'd10;
    
    // Multiplier intermediate
    wire [63:0] mult_temp;
    assign mult_temp = guess * operand;
    
    // Divider intermediate (operand/guess)
    wire [63:0] div_temp;
    assign div_temp = {operand, 32'd0} / guess;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            s <= 32'd0;
            sa <= 32'd0;
            sb <= 32'd0;
            sc <= 32'd0;
            product <= 32'd0;
            operand <= 32'd0;
            guess <= 32'd0;
            next_guess <= 32'd0;
            iteration_counter <= 8'd0;
            val_check_counter <= 4'd0;
            valid_triangle <= 1'b0;
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                end
                
                VALIDATE: begin
                    val_check_counter <= 4'd0;
                    valid_triangle <= 1'b1;
                end
                
                VALIDATE_2: begin
                    // Check: a + b > c
                    if (({24'd0, a} + {24'd0, b}) <= {24'd0, c}) begin
                        valid_triangle <= 1'b0;
                    end
                end
                
                VALIDATE_3: begin
                    // Check: a + c > b and b + c > a
                    if (({24'd0, a} + {24'd0, c}) <= {24'd0, b}) begin
                        valid_triangle <= 1'b0;
                    end
                    if (({24'd0, b} + {24'd0, c}) <= {24'd0, a}) begin
                        valid_triangle <= 1'b0;
                    end
                end
                
                COMPUTE_S: begin
                    // s = (a+b+c) * SCALE / 2
                    s <= (({24'd0, a} + {24'd0, b} + {24'd0, c}) * SCALE) >> 1;
                end
                
                COMPUTE_SA: begin
                    // s - a (in Q16.16)
                    sa <= s - ({24'd0, a} * SCALE);
                end
                
                COMPUTE_SB: begin
                    // s - b (in Q16.16)
                    sb <= s - ({24'd0, b} * SCALE);
                end
                
                COMPUTE_SC: begin
                    // s - c (in Q16.16)
                    sc <= s - ({24'd0, c} * SCALE);
                    product <= s;  // Start with s
                end
                
                COMPUTE_P1: begin
                    // product = s * sa
                    product <= product * sa;
                end
                
                COMPUTE_P2: begin
                    // product = product * sb * sc
                    product <= product * sb * sc;
                end
                
                SQRT_START: begin
                    operand <= product;
                    // Initialize guess: if operand > 0, operand >> 1 else 512
                    if (product > 32'd0) begin
                        guess <= product >> 1;
                    end else begin
                        guess <= 32'd512;
                    end
                    iteration_counter <= 8'd0;
                end
                
                SQRT_LOOP: begin
                    // Babylonian: next_guess = (guess + operand/guess) / 2
                    next_guess <= (guess + div_temp[31:0]) >> 1;
                    guess <= next_guess;
                    iteration_counter <= iteration_counter + 8'd1;
                end
                
                DONE: begin
                    // Final result from SQRT_LOOP
                    result <= guess;
                    done <= 1'b1;
                end
                
                INVALID: begin
                    result <= 32'hFFFFFFFF;
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
                    next_state = VALIDATE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            VALIDATE: begin
                next_state = VALIDATE_2;
            end
            
            VALIDATE_2: begin
                next_state = VALIDATE_3;
            end
            
            VALIDATE_3: begin
                if (valid_triangle) begin
                    next_state = COMPUTE_S;
                end else begin
                    next_state = INVALID;
                end
            end
            
            COMPUTE_S: begin
                next_state = COMPUTE_SA;
            end
            
            COMPUTE_SA: begin
                next_state = COMPUTE_SB;
            end
            
            COMPUTE_SB: begin
                next_state = COMPUTE_SC;
            end
            
            COMPUTE_SC: begin
                next_state = COMPUTE_P1;
            end
            
            COMPUTE_P1: begin
                next_state = COMPUTE_P2;
            end
            
            COMPUTE_P2: begin
                if (product == 32'd0) begin
                    next_state = INVALID;
                end else begin
                    next_state = SQRT_START;
                end
            end
            
            SQRT_START: begin
                next_state = SQRT_LOOP;
            end
            
            SQRT_LOOP: begin
                if (iteration_counter < MAX_ITER) begin
                    next_state = SQRT_LOOP;
                end else begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            INVALID: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule