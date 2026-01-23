module mta_rock_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [15:0] n,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK_LAWN,
        COMPUTE_SEQUENCE,
        VERIFY_RECTANGLE,
        UPDATE_COUNT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] current_F, prev_F, prev_prev_F;
    reg [15:0] n_current;
    reg [7:0] p, q;
    reg [7:0] p_index;
    reg [15:0] sqrt_F;
    reg is_prime_p, is_prime_q;
    reg found_factor;

    // Prime lookup table (primes up to 256)
    localparam [7:0] PRIMES [0:61] = '{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            n_current <= 0;
            current_F <= 0;
            prev_F <= 0;
            prev_prev_F <= 0;
            p_index <= 0;
            found_factor <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_LAWN;
                    n_current = 1;
                    result = 0;
                    done = 0;
                    current_F = 42;
                    prev_F = 42;
                    prev_prev_F = 42;
                end
            end
            CHECK_LAWN: begin
                if (n_current > n) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPUTE_SEQUENCE;
                end
            end
            COMPUTE_SEQUENCE: begin
                next_state = VERIFY_RECTANGLE;
            end
            VERIFY_RECTANGLE: begin
                if (found_factor) begin
                    next_state = UPDATE_COUNT;
                end else if (p_index >= 61 || PRIMES[p_index] > sqrt_F) begin
                    next_state = CHECK_LAWN;
                    n_current = n_current + 1;
                    p_index = 0;
                end else begin
                    next_state = VERIFY_RECTANGLE;
                end
            end
            UPDATE_COUNT: begin
                next_state = CHECK_LAWN;
                n_current = n_current + 1;
                p_index = 0;
            end
            DONE: begin
                done = 1;
            end
        endcase
    end

    // Compute sequence
    always @(posedge clk) begin
        if (current_state == COMPUTE_SEQUENCE) begin
            if (n_current == 1) begin
                current_F <= 42;
            end else if (n_current == 2) begin
                current_F <= 11 * k + 77;
            end else begin
                current_F <= 2 * prev_F - prev_prev_F + 10 * k;
            end
            prev_prev_F <= prev_F;
            prev_F <= current_F;
        end
    end

    // Verify rectangle
    always @(posedge clk) begin
        if (current_state == VERIFY_RECTANGLE) begin
            if (!found_factor) begin
                p = PRIMES[p_index];
                if (current_F % p == 0) begin
                    q = current_F / p;
                    is_prime_p = 1;
                    is_prime_q = 0;
                    for (int i = 0; i < 62; i++) begin
                        if (PRIMES[i] == q) begin
                            is_prime_q = 1;
                            break;
                        end
                    end
                    if (is_prime_p && is_prime_q) begin
                        found_factor = 1;
                    end
                end
                p_index = p_index + 1;
            end
        end else begin
            found_factor = 0;
        end
    end

    // Update count
    always @(posedge clk) begin
        if (current_state == UPDATE_COUNT) begin
            result <= result + 1;
        end
    end

    // Compute sqrt_F
    always @(posedge clk) begin
        if (current_state == COMPUTE_SEQUENCE) begin
            sqrt_F = 0;
            for (int i = 15; i >= 0; i = i - 1) begin
                if ((sqrt_F + (1 << i)) * (sqrt_F + (1 << i)) <= current_F) begin
                    sqrt_F = sqrt_F + (1 << i);
                end
            end
        end
    end

endmodule