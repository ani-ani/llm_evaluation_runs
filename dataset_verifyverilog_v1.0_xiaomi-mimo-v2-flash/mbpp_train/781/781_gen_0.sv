module divisor_parity_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] COUNTING   = 2'd1;
    localparam [1:0] COMPLETE   = 2'd2;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] i;              // Loop counter (1 to sqrt(n))
    reg [15:0] divisor_count;  // Count of divisors
    reg [15:0] n_reg;          // Store input n
    reg [15:0] sqrt_n;         // Pre-calculated sqrt(n)
    reg [15:0] remainder;      // n % i
    reg [15:0] quotient;       // n / i
    reg computing_remainder;
    reg remainder_ready;
    reg [2:0] calc_stage;      // For remainder computation

    // Wire for computation
    wire [15:0] current_i;
    assign current_i = i;

    // Always block for sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            i <= 16'd0;
            divisor_count <= 16'd0;
            n_reg <= 16'd0;
            sqrt_n <= 16'd0;
            remainder <= 16'd0;
            quotient <= 16'd0;
            computing_remainder <= 1'b0;
            remainder_ready <= 1'b0;
            calc_stage <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 16'd0;
                    divisor_count <= 16'd0;
                    n_reg <= n;
                    computing_remainder <= 1'b0;
                    remainder_ready <= 1'b0;
                    calc_stage <= 3'd0;
                    
                    // Calculate sqrt(n) using integer square root approximation
                    // For 16-bit, max sqrt is 256, so we use simple loop or lookup
                    // Here we'll compute it in IDLE or hardcode the check
                    // To save cycles, we'll use a simple comparison method
                    // Start with i=1
                    if (start) begin
                        sqrt_n <= 16'd256; // Conservative upper bound for 16-bit n
                        i <= 16'd1;
                        state <= COUNTING;
                    end
                end
                
                COUNTING: begin
                    remainder_ready <= 1'b0;
                    
                    if (!computing_remainder && i <= n_reg) begin
                        // Check if i <= sqrt(n) (using i*i <= n to avoid sqrt calc)
                        // For efficiency, check i <= 256 and i*i <= n
                        // Since n <= 65535, max i is 256
                        if (i <= 16'd256 && (i * i) <= n_reg) begin
                            computing_remainder <= 1'b1;
                            calc_stage <= 3'd0;
                        end else begin
                            // Done counting
                            state <= COMPLETE;
                        end
                    end
                    
                    // Remainder computation pipeline
                    if (computing_remainder) begin
                        calc_stage <= calc_stage + 3'd1;
                        
                        case (calc_stage)
                            3'd0: begin
                                // Start division: compute n % i
                                // Use repeated subtraction or built-in division
                                // Verilog synthesis supports integer division
                                remainder <= n_reg % i;
                                quotient <= n_reg / i;
                            end
                            3'd1: begin
                                // Check result
                                if (remainder == 16'd0) begin
                                    // i divides n evenly
                                    if (quotient == i) begin
                                        // Perfect square: count 1
                                        divisor_count <= divisor_count + 16'd1;
                                    end else begin
                                        // Not perfect square: count 2
                                        divisor_count <= divisor_count + 16'd2;
                                    end
                                end
                            end
                            3'd2: begin
                                // Done with this i
                                computing_remainder <= 1'b0;
                                remainder_ready <= 1'b1;
                            end
                            default: begin
                                computing_remainder <= 1'b0;
                            end
                        endcase
                    end
                    
                    if (remainder_ready) begin
                        i <= i + 16'd1;
                        remainder_ready <= 1'b0;
                    end
                end
                
                COMPLETE: begin
                    // Compute result: 1 if even, 0 if odd
                    result <= (divisor_count[0] == 1'b0) ? 1'b1 : 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule