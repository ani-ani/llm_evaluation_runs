module pythagorean_triple_counter (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] count,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [15:0] count_reg, next_count;
    reg [4:0] a, next_a;
    reg [4:0] b, next_b;
    reg [4:0] c, next_c;
    
    // Intermediate computation registers
    reg [15:0] a_sq, b_sq, c_sq;
    reg [15:0] sum_ab_sq;
    reg match;
    
    // Combinational logic for square and modulo calculation
    always @(*) begin
        // Compute squares (max 15*15=225 < 2^16)
        if (a != 0)
            a_sq = a * a;
        else
            a_sq = 0;
            
        if (b != 0)
            b_sq = b * b;
        else
            b_sq = 0;
            
        if (c != 0)
            c_sq = c * c;
        else
            c_sq = 0;
            
        // Compute sum
        sum_ab_sq = a_sq + b_sq;
    end
    
    // Combinational modulo reduction using subtraction-based method
    reg [15:0] a_sq_mod, b_sq_mod, c_sq_mod, sum_mod;
    
    always @(*) begin
        // a_sq % n
        a_sq_mod = a_sq;
        while (a_sq_mod >= n) begin
            a_sq_mod = a_sq_mod - n;
        end
        
        // b_sq % n
        b_sq_mod = b_sq;
        while (b_sq_mod >= n) begin
            b_sq_mod = b_sq_mod - n;
        end
        
        // c_sq % n
        c_sq_mod = c_sq;
        while (c_sq_mod >= n) begin
            c_sq_mod = c_sq_mod - n;
        end
        
        // (a_sq + b_sq) % n
        sum_mod = sum_ab_sq;
        while (sum_mod >= n) begin
            sum_mod = sum_mod - n;
        end
    end
    
    // Match condition
    always @(*) begin
        match = (sum_mod == c_sq_mod);
    end
    
    // Next state and output logic
    always @(*) begin
        // Default values
        next_state = state;
        next_count = count_reg;
        next_a = a;
        next_b = b;
        next_c = c;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    next_count = 0;
                    next_a = 1;
                    next_b = 1;
                    next_c = 1;
                end
            end
            
            COMPUTE: begin
                // Check if triple is valid and increment count
                if (match) begin
                    next_count = count_reg + 1;
                end
                
                // Iterate c (innermost loop)
                if (c < n - 1) begin
                    next_c = c + 1;
                end else begin
                    next_c = 1;
                    
                    // Iterate b (middle loop)
                    if (b < n - 1) begin
                        next_b = b + 1;
                    end else begin
                        next_b = a; // Reset b to a for next a (ensuring a <= b)
                        
                        // Iterate a (outermost loop)
                        if (a < n - 1) begin
                            next_a = a + 1;
                        end else begin
                            // All iterations complete
                            next_state = DONE;
                        end
                    end
                end
            end
            
            DONE: begin
                // Stay in DONE state until reset
                next_state = DONE;
            end
            
            default: begin
                next_state = IDLE;
                next_count = 0;
                next_a = 1;
                next_b = 1;
                next_c = 1;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count_reg <= 0;
            a <= 1;
            b <= 1;
            c <= 1;
            count <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            count_reg <= next_count;
            a <= next_a;
            b <= next_b;
            c <= next_c;
            
            // Output assignments
            if (next_state == DONE) begin
                count <= next_count;
                done <= 1;
            end else if (next_state == IDLE) begin
                count <= 0;
                done <= 0;
            end else begin
                done <= 0;
            end
        end
    end

endmodule