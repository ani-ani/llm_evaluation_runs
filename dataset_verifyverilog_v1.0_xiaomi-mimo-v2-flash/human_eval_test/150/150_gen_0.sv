module PrimeNumberConditionalSelector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_i,
    input wire [15:0] x_i,
    input wire [15:0] y_i,
    output reg [15:0] result_o,
    output reg done_o
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK      = 3'd1;
    localparam [2:0] DIVIDE     = 3'd2;
    localparam [2:0] PRIME      = 3'd3;
    localparam [2:0] NOT_PRIME  = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] n_reg;
    reg [15:0] divisor;
    reg [15:0] remainder;
    reg [15:0] dividend;
    reg [7:0] cycle_count;  // To prevent infinite loops
    reg prime_flag;  // Flag to track primality
    reg [7:0] sqrt_limit;  // Pre-calculated sqrt limit
    
    // Division logic registers
    reg div_start;
    reg div_done;
    reg [15:0] div_result;
    
    // State transition and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_o <= 16'd0;
            done_o <= 1'b0;
            n_reg <= 16'd0;
            divisor <= 16'd0;
            remainder <= 16'd0;
            dividend <= 16'd0;
            cycle_count <= 8'd0;
            prime_flag <= 1'b0;
            sqrt_limit <= 8'd0;
            div_start <= 1'b0;
            div_done <= 1'b0;
            div_result <= 16'd0;
        end else begin
            // Default outputs
            done_o <= 1'b0;
            div_start <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    prime_flag <= 1'b0;
                    div_done <= 1'b0;
                    div_result <= 16'd0;
                    if (start) begin
                        n_reg <= n_i;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Handle edge cases first
                    if (n_i <= 16'd1) begin
                        // n <= 1: not prime
                        state <= NOT_PRIME;
                    end else if (n_i == 16'd2 || n_i == 16'd3) begin
                        // n = 2 or 3: prime
                        state <= PRIME;
                    end else begin
                        // For n >= 4, prepare to check divisors
                        state <= DIVIDE;
                        divisor <= 16'd2;
                        // Calculate sqrt limit (floor(sqrt(n))) using approximation
                        // Since max n = 65535, max sqrt = 255
                        if (n_i > 16'd4225) sqrt_limit <= 8'd255;   // sqrt(4225)=65
                        else if (n_i > 16'd1296) sqrt_limit <= 8'd127; // sqrt(1296)=36
                        else if (n_i > 16'd361) sqrt_limit <= 8'd63;   // sqrt(361)=19
                        else if (n_i > 16'd64) sqrt_limit <= 8'd31;    // sqrt(64)=8
                        else sqrt_limit <= 8'd15;                      // sqrt(16)=4, handles up to 225
                        dividend <= n_i;
                    end
                end
                
                DIVIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if divisor exceeds sqrt limit or max iterations
                    if (divisor > sqrt_limit || cycle_count >= 8'd200) begin
                        // No divisor found up to sqrt(n): prime
                        state <= PRIME;
                    end else begin
                        // Perform modulo: dividend % divisor
                        if (dividend < divisor) begin
                            remainder <= dividend;
                            if (remainder == 16'd0) begin
                                // Found divisor! Not prime
                                state <= NOT_PRIME;
                            end else begin
                                // Move to next divisor
                                divisor <= divisor + 16'd1;
                                dividend <= n_reg;  // Reset dividend for next check
                            end
                        end else begin
                            dividend <= dividend - divisor;
                        end
                    end
                end
                
                PRIME: begin
                    result_o <= x_i;
                    done_o <= 1'b1;
                    state <= DONE_STATE;
                end
                
                NOT_PRIME: begin
                    result_o <= y_i;
                    done_o <= 1'b1;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done_o <= 1'b0;  // Pulse done only for one cycle
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule