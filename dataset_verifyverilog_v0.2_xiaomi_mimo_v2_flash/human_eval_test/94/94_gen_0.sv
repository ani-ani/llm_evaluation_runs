module prime_digit_sum (
    input clk,
    input rst_n,
    input start,
    input [4:0] list_size,
    input [15:0] list_data [0:7],
    output reg [7:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam FIND_PRIME = 3'b010;
    localparam CHECK_PRIME = 3'b011;
    localparam CALCULATE_DIGITS = 3'b100;
    localparam DONE = 3'b101;

    // Registers
    reg [2:0] current_state, next_state;
    reg [3:0] index;               // Index for iterating list (0-7)
    reg [15:0] current_val;        // The number currently being checked
    reg [15:0] max_prime;          // The largest prime found so far
    reg [15:0] divisor;            // Divisor for primality test
    reg [7:0] digit_sum;           // Accumulator for digit sum
    reg [31:0] delay_counter;      // Timer for 100 cycle latency

    // Helper logic for primality check
    // Check condition: divisor * divisor <= current_val
    // We use pre-computed square to avoid complex sqrt logic in combinational path
    wire [31:0] divisor_sq;
    assign divisor_sq = divisor * divisor;
    wire is_prime_candidate;
    assign is_prime_candidate = (current_val > 1) && (divisor > current_val || divisor_sq > current_val);

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: begin
                // Proceed immediately to finding primes
                next_state = FIND_PRIME;
            end
            FIND_PRIME: begin
                if (index >= list_size) begin
                    // All numbers checked, move to digit calculation
                    next_state = CALCULATE_DIGITS;
                end else if (current_val <= 1 || (current_val != 2 && current_val[0] == 1'b0)) begin
                    // Skip non-prime candidates (<=1 or even > 2)
                    next_state = LOAD; // Loads next value immediately
                end else if (current_val == 2) begin
                    // 2 is prime, update and skip detailed check
                    next_state = LOAD;
                end else begin
                    // Need to check odd divisors
                    next_state = CHECK_PRIME;
                end
            end
            CHECK_PRIME: begin
                if (current_val % divisor == 0) begin
                    // Found a divisor, composite
                    next_state = LOAD;
                end else if (is_prime_candidate) begin
                    // Continue checking next odd divisor
                    next_state = CHECK_PRIME;
                end else begin
                    // No divisor found, it is prime
                    next_state = LOAD;
                end
            end
            CALCULATE_DIGITS: begin
                if (max_prime == 0) begin
                    // Done summing digits
                    next_state = DONE;
                end else begin
                    // Continue dividing by 10
                    next_state = CALCULATE_DIGITS;
                end
            end
            DONE: begin
                // Wait for reset or new start (handled in IDLE transition or specific logic)
                // To satisfy latency requirement, we rely on the delay counter logic below
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'b0;
            done <= 1'b0;
            index <= 4'b0;
            max_prime <= 16'b0;
            current_val <= 16'b0;
            divisor <= 16'b0;
            digit_sum <= 8'b0;
            delay_counter <= 32'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        index <= 4'b0;
                        max_prime <= 16'b0;
                        done <= 1'b0;
                        delay_counter <= 32'b0;
                    end
                end
                LOAD: begin
                    // Load next value from array
                    current_val <= list_data[index];
                    // Pre-calculate next index here or in FIND_PRIME. 
                    // We update index in FIND_PRIME to sync with loading.
                end
                FIND_PRIME: begin
                    // Increment index since we just loaded/processed current_val
                    index <= index + 1;
                    if (index >= list_size) begin
                        digit_sum <= 0;
                    end
                    // Check if current_val is a candidate
                    // Logic branched in next_state, so we perform updates here based on simple checks
                    if (current_val <= 1) begin
                        // Do nothing
                    end else if (current_val == 2) begin
                        if (current_val > max_prime) max_prime <= current_val;
                    end else if (current_val[0] == 1'b0) begin
                        // Even > 2, do nothing
                    end else begin
                        // Odd candidate, prepare divisor for CHECK_PRIME
                        divisor <= 3; // Start checking from 3
                        // If it's 3, we need to handle it, but CHECK_PRIME will handle logic
                    end
                end
                CHECK_PRIME: begin
                    if (current_val % divisor == 0) begin
                        // Composite, do nothing to max_prime
                    end else begin
                        // Check next divisor
                        if (is_prime_candidate) begin
                            divisor <= divisor + 2;
                        end else begin
                            // Prime confirmed
                            if (current_val > max_prime) begin
                                max_prime <= current_val;
                            end
                        end
                    end
                end
                CALCULATE_DIGITS: begin
                    if (max_prime != 0) begin
                        digit_sum <= digit_sum + (max_prime % 10);
                        max_prime <= max_prime / 10;
                    end
                    // Logic for state transition handles the stop.
                end
                DONE: begin
                    // Keep 'done' high and result valid.
                    done <= 1'b1;
                    result <= digit_sum;
                end
            endcase
            // Separate Counter Logic (inside always block, alongside state logic)
            if (current_state != IDLE) begin
                if (delay_counter < 100) begin
                    delay_counter <= delay_counter + 1;
                end
            end
        end
    end

    // Combinational Output Logic
    always @(*) begin
        // Default outputs
        // done = 0; result = 0;
        // We assign them in the sequential block or via continuous assignment.
        // Let's do it via continuous assignment for clean separation.
    end
    
    // Continuous assignments for output timing
    assign done = (delay_counter >= 100);
    assign result = (delay_counter >= 100) ? digit_sum : 8'b0;

endmodule

module top_module_wrapper (
    input clk,
    input rst_n,
    input start,
    input [4:0] list_size,
    input [15:0] list_data [0:7],
    output [7:0] result,
    output done
);
    prime_digit_sum u_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .list_size(list_size),
        .list_data(list_data),
        .result(result),
        .done(done)
    );
endmodule