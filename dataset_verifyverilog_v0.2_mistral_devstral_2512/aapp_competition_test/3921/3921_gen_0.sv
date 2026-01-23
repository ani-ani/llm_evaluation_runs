module good_sequence_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] a [0:15],
    output reg [7:0] result,
    output reg done
);

    // Parameters
    parameter MAX_PRIME = 256;
    parameter IDLE = 3'b000;
    parameter READ_PRIMES = 3'b001;
    parameter CALCULATE_DP = 3'b010;
    parameter UPDATE_RESULT = 3'b011;
    parameter DONE = 3'b100;

    // State register
    reg [2:0] state, next_state;

    // DP array: stores max sequence length for each prime factor
    reg [7:0] dp [0:255];

    // Current input index
    reg [3:0] current_idx;

    // Current value and its prime factors
    reg [15:0] current_val;
    reg [7:0] prime_factors [0:15]; // Max 16 prime factors per number
    reg [3:0] num_primes;

    // Max value found during calculation
    reg [7:0] max_val;

    // Prime factor lookup table (simplified for synthesis)
    // This is a simplified version; in practice, you'd use a ROM or combinational logic
    function automatic [7:0] get_prime_factors;
        input [15:0] num;
        reg [7:0] factors;
        integer i, j;
        begin
            factors = 0;
            for (i = 2; i <= 255; i = i + 1) begin
                if (is_prime(i) && (num % i == 0)) begin
                    factors = factors | (1 << i);
                end
            end
            get_prime_factors = factors;
        end
    endfunction

    function automatic is_prime;
        input [7:0] num;
        integer i;
        begin
            if (num <= 1) begin
                is_prime = 0;
            end else if (num == 2) begin
                is_prime = 1;
            end else if (num % 2 == 0) begin
                is_prime = 0;
            end else begin
                is_prime = 1;
                for (i = 3; i * i <= num; i = i + 2) begin
                    if (num % i == 0) begin
                        is_prime = 0;
                        break;
                    end
                end
            end
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_idx <= 0;
            max_val <= 0;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_PRIMES;
                end
            end
            READ_PRIMES: begin
                next_state = CALCULATE_DP;
            end
            CALCULATE_DP: begin
                next_state = UPDATE_RESULT;
            end
            UPDATE_RESULT: begin
                if (current_idx == n - 1) begin
                    next_state = DONE;
                end else begin
                    next_state = READ_PRIMES;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_idx <= 0;
            max_val <= 0;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Reset DP array
                    integer i;
                    for (i = 0; i < 256; i = i + 1) begin
                        dp[i] <= 0;
                    end
                    current_idx <= 0;
                    max_val <= 0;
                    done <= 0;
                    result <= 0;
                end
                READ_PRIMES: begin
                    current_val <= a[current_idx];
                    // Get prime factors (simplified for synthesis)
                    // In practice, use a precomputed LUT
                    integer i, count;
                    count = 0;
                    for (i = 2; i <= 255; i = i + 1) begin
                        if (is_prime(i) && (current_val % i == 0)) begin
                            prime_factors[count] <= i;
                            count = count + 1;
                        end
                    end
                    num_primes <= count;
                end
                CALCULATE_DP: begin
                    // Find max dp[p] for all prime factors p of current_val
                    integer i;
                    max_val <= 0;
                    for (i = 0; i < num_primes; i = i + 1) begin
                        if (dp[prime_factors[i]] > max_val) begin
                            max_val <= dp[prime_factors[i]];
                        end
                    end
                end
                UPDATE_RESULT: begin
                    // Update dp[p] = max_val + 1 for all prime factors p
                    integer i;
                    for (i = 0; i < num_primes; i = i + 1) begin
                        if (max_val + 1 > dp[prime_factors[i]]) begin
                            dp[prime_factors[i]] <= max_val + 1;
                        end
                    end
                    // Update global max
                    if (max_val + 1 > result) begin
                        result <= max_val + 1;
                    end
                    // Move to next input
                    current_idx <= current_idx + 1;
                end
                DONE: begin
                    done <= 1;
                end
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule