module HopscotchPaths(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire [7:0] X,
    input wire [7:0] Y,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    // Registers
    reg [2:0] state, next_state;
    reg [7:0] k;
    reg [7:0] max_k;
    reg [31:0] comb_x, comb_y;
    reg [31:0] product;
    reg [31:0] accumulator;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            k <= 8'd0;
            max_k <= 8'd0;
            comb_x <= 32'd0;
            comb_y <= 32'd0;
            product <= 32'd0;
            accumulator <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    // Calculate max_k = floor(N / min(X, Y))
                    if (X < Y) begin
                        max_k <= N / X;
                    end else begin
                        max_k <= N / Y;
                    end
                    k <= 8'd1;
                    accumulator <= 32'd0;
                    next_state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if k is valid
                    if (k * X <= N && k * Y <= N) begin
                        // Compute comb_x = C(N - k*X + k - 1, k - 1)
                        comb_x <= compute_binomial(N - k * X + k - 1, k - 1);
                        
                        // Compute comb_y = C(N - k*Y + k - 1, k - 1)
                        comb_y <= compute_binomial(N - k * Y + k - 1, k - 1);
                        
                        // Multiply comb_x and comb_y mod MOD
                        product <= mod_mult(comb_x, comb_y);
                        
                        // Accumulate result
                        accumulator <= mod_add(accumulator, product);
                    end
                    
                    // Move to next k
                    if (k == max_k) begin
                        next_state <= FINISH;
                    end else begin
                        k <= k + 8'd1;
                        next_state <= COMPUTE;
                    end
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    // Binomial coefficient calculator
    function [31:0] compute_binomial;
        input [7:0] n, k;
        reg [31:0] result;
        integer i;
        
        begin
            if (k == 0 || k == n) begin
                result = 1;
            end else if (k > n) begin
                result = 0;
            end else begin
                result = 1;
                for (i = 1; i <= k; i = i + 1) begin
                    result = mod_mult(result, mod_add(n - i + 1, 0));
                    result = mod_mult(result, mod_inverse(i, MOD));
                end
            end
            compute_binomial = result;
        end
    endfunction

    // Modular multiplication
    function [31:0] mod_mult;
        input [31:0] a, b;
        reg [31:0] result;
        reg [31:0] temp;
        integer i;
        
        begin
            result = 0;
            for (i = 0; i < 32; i = i + 1) begin
                if (b[i]) begin
                    temp = result;
                    result = (result << 1) + a;
                    if (result >= MOD) begin
                        result = result - MOD;
                    end
                end else begin
                    result = result << 1;
                    if (result >= MOD) begin
                        result = result - MOD;
                    end
                end
            end
            mod_mult = result;
        end
    endfunction

    // Modular addition
    function [31:0] mod_add;
        input [31:0] a, b;
        reg [31:0] result;
        
        begin
            result = a + b;
            if (result >= MOD) begin
                result = result - MOD;
            end
            mod_add = result;
        end
    endfunction

    // Modular inverse using Fermat's little theorem
    function [31:0] mod_inverse;
        input [31:0] a;
        input [31:0] mod;
        reg [31:0] result;
        reg [31:0] base;
        reg [31:0] exp;
        integer i;
        
        begin
            if (a == 0) begin
                result = 0;
            end else begin
                base = a;
                exp = mod - 2;
                result = 1;
                while (exp > 0) begin
                    if (exp[0]) begin
                        result = mod_mult(result, base);
                    end
                    base = mod_mult(base, base);
                    exp = exp >> 1;
                end
            end
            mod_inverse = result;
        end
    endfunction

endmodule