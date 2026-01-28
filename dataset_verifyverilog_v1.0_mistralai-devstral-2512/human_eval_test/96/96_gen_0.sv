module prime_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n_in,
    output reg [7:0] primes [0:15],
    output reg [3:0] prime_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] STORE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [5:0] current_num;  // Number being checked (2 to n-1)
    reg [5:0] divisor;      // Divisor for trial division
    reg [5:0] sqrt_val;     // Square root of current_num
    reg is_prime;          // Flag indicating if current_num is prime
    reg [3:0] prime_idx;    // Index for storing primes
    reg [7:0] cycle_count; // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 6'd0;
            divisor <= 6'd0;
            sqrt_val <= 6'd0;
            is_prime <= 1'b0;
            prime_idx <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            prime_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                primes[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK;
                        current_num <= 6'd2;  // Start checking from 2
                        prime_idx <= 4'd0;
                        prime_count <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if current_num is prime
                    if (current_num < n_in) begin
                        // Calculate sqrt_val (approximate)
                        sqrt_val <= 6'd0;
                        if (current_num >= 4) begin
                            sqrt_val <= current_num >> 1;
                        end
                        divisor <= 6'd2;  // Start divisor from 2
                        is_prime <= 1'b1;
                        next_state <= CHECK;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                STORE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Store prime if it's valid and we have space
                    if (is_prime && prime_idx < 16) begin
                        primes[prime_idx] <= current_num;
                        prime_idx <= prime_idx + 4'd1;
                        prime_count <= prime_count + 4'd1;
                    end
                    // Move to next number
                    current_num <= current_num + 6'd1;
                    next_state <= CHECK;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Combinational logic for prime checking
    always @(*) begin
        case (state)
            CHECK: begin
                if (divisor <= sqrt_val) begin
                    if (current_num % divisor == 0) begin
                        is_prime = 1'b0;
                        next_state = STORE;
                    end else begin
                        divisor = divisor + 6'd1;
                        next_state = CHECK;
                    end
                end else begin
                    next_state = STORE;
                end
            end
            default: begin
                is_prime = 1'b0;
                next_state = state;
            end
        endcase
    end

endmodule