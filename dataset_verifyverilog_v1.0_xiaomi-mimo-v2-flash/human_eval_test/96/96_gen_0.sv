module PrimeFinder (
    input clk,
    input rst_n,
    input start,
    input [5:0] n_in,
    output reg [127:0] primes,
    output reg [3:0] prime_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_NUMBER = 3'd1;
    localparam [2:0] FIND_SQRT = 3'd2;
    localparam [3:0] CHECK_DIVISOR = 3'd3;
    localparam [2:0] ADD_PRIME = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;
    
    reg [2:0] state, next_state;
    reg [5:0] current_num;          // Number being checked (2 to n-1)
    reg [5:0] divisor;              // Current divisor for trial division
    reg [5:0] sqrt_limit;           // Square root limit for current_num
    reg [3:0] prime_index;          // Index in primes array (0-15)
    reg is_prime;                   // Flag for primality
    reg [5:0] n_val;                // Stored n_in value
    reg [7:0] cycle_count;          // Cycle counter to prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;  // Sufficient for n=64

    // Temporary storage for result packing
    reg [7:0] temp_primes [0:15];   // Internal array for primes
    
    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            primes <= 128'd0;
            prime_count <= 4'd0;
            done <= 1'b0;
            current_num <= 6'd0;
            divisor <= 6'd0;
            sqrt_limit <= 6'd0;
            prime_index <= 4'd0;
            is_prime <= 1'b1;
            n_val <= 6'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                temp_primes[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    prime_index <= 4'd0;
                    cycle_count <= 8'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        temp_primes[i] <= 8'd0;
                    end
                    if (start) begin
                        n_val <= n_in;
                        if (n_in > 6'd2) begin
                            current_num <= 6'd2;
                            state <= CHECK_NUMBER;
                        end else begin
                            state <= COMPLETE;
                        end
                    end
                end
                
                CHECK_NUMBER: begin
                    if (current_num < n_val && prime_index < 4'd16 && cycle_count < MAX_CYCLES) begin
                        is_prime <= 1'b1;
                        divisor <= 6'd2;
                        state <= FIND_SQRT;
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                FIND_SQRT: begin
                    // Find approximate sqrt limit
                    if (current_num <= 6'd3) begin
                        sqrt_limit <= 6'd2;
                    end else if (current_num <= 6'd9) begin
                        sqrt_limit <= 6'd3;
                    end else if (current_num <= 6'd15) begin
                        sqrt_limit <= 6'd4;
                    end else if (current_num <= 6'd24) begin
                        sqrt_limit <= 6'd5;
                    end else if (current_num <= 6'd35) begin
                        sqrt_limit <= 6'd6;
                    end else if (current_num <= 6'd48) begin
                        sqrt_limit <= 6'd7;
                    end else begin
                        sqrt_limit <= 6'd8;
                    end
                    state <= CHECK_DIVISOR;
                end
                
                CHECK_DIVISOR: begin
                    if (is_prime && divisor < sqrt_limit && divisor < current_num) begin
                        if (current_num % divisor == 6'd0) begin
                            is_prime <= 1'b0;
                            state <= CHECK_NUMBER;  // Skip to next number
                            current_num <= current_num + 6'd1;
                            cycle_count <= cycle_count + 8'd1;
                        end else begin
                            divisor <= divisor + 6'd1;
                            state <= CHECK_DIVISOR;
                        end
                    end else if (is_prime) begin
                        state <= ADD_PRIME;
                    end else begin
                        current_num <= current_num + 6'd1;
                        cycle_count <= cycle_count + 8'd1;
                        state <= CHECK_NUMBER;
                    end
                end
                
                ADD_PRIME: begin
                    temp_primes[prime_index] <= {2'd0, current_num};
                    prime_count <= prime_index + 4'd1;
                    prime_index <= prime_index + 4'd1;
                    current_num <= current_num + 6'd1;
                    cycle_count <= cycle_count + 8'd1;
                    state <= CHECK_NUMBER;
                end
                
                COMPLETE: begin
                    // Pack temp_primes into 128-bit output
                    primes <= {temp_primes[15], temp_primes[14], temp_primes[13], temp_primes[12],
                              temp_primes[11], temp_primes[10], temp_primes[9], temp_primes[8],
                              temp_primes[7], temp_primes[6], temp_primes[5], temp_primes[4],
                              temp_primes[3], temp_primes[2], temp_primes[1], temp_primes[0]};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule