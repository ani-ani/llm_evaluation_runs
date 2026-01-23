module special_number_counter (
    input clk,
    input rst_n,
    input start,
    input [1023:0] n_binary,
    input [9:0] k_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'h3B9ACA07; // 10^9 + 7
    localparam MAX_BITS = 1024;
    localparam MAX_M = 1024;

    // State machine
    typedef enum logic [1:0] {
        IDLE,
        PRECOMPUTE,
        COUNTING,
        DONE
    } state_t;
    state_t state, next_state;

    // Precomputed valid m values (bitmask)
    reg [MAX_M-1:0] valid_m_mask;

    // Counting variables
    reg [9:0] bit_pos;
    reg [9:0] ones_count;
    reg [9:0] m_iter;
    reg [31:0] temp_result;

    // Combinatorial nCr calculation
    function automatic [31:0] nCr;
        input [9:0] n;
        input [9:0] r;
        reg [31:0] res;
        integer i;
        begin
            if (r > n) begin
                nCr = 0;
            end else if (r == 0 || r == n) begin
                nCr = 1;
            end else begin
                res = 1;
                if (r > n - r) r = n - r;
                for (i = 1; i <= r; i = i + 1) begin
                    res = (res * (n - r + i)) % MOD;
                    res = (res * mod_inverse(i, MOD)) % MOD;
                end
                nCr = res;
            end
        end
    endfunction

    // Modular inverse using Fermat's little theorem
    function automatic [31:0] mod_inverse;
        input [31:0] a;
        input [31:0] mod;
        reg [31:0] res;
        integer i;
        begin
            res = 1;
            a = a % mod;
            for (i = 1; i < mod - 2; i = i + 1) begin
                res = (res * a) % mod;
            end
            mod_inverse = res;
        end
    endfunction

    // Precompute valid m values
    function automatic [MAX_M-1:0] precompute_valid_m;
        input [9:0] k;
        reg [MAX_M-1:0] mask;
        integer m;
        begin
            mask = '0;
            for (m = 1; m <= MAX_M; m = m + 1) begin
                if (steps_to_one(m) == k - 1) begin
                    mask[m] = 1'b1;
                end
            end
            precompute_valid_m = mask;
        end
    endfunction

    // Calculate steps to reduce m to 1
    function automatic [3:0] steps_to_one;
        input [9:0] m;
        reg [3:0] steps;
        begin
            steps = 0;
            while (m != 1) begin
                m = $clog2(m) + 1; // Popcount
                steps = steps + 1;
            end
            steps_to_one = steps;
        end
    endfunction

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            bit_pos <= 0;
            ones_count <= 0;
            m_iter <= 0;
            temp_result <= 0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PRECOMPUTE;
                end
            end
            PRECOMPUTE: begin
                next_state = COUNTING;
            end
            COUNTING: begin
                if (bit_pos == MAX_BITS) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Precompute state logic
    always @(posedge clk) begin
        if (!rst_n && state == PRECOMPUTE) begin
            valid_m_mask <= precompute_valid_m(k_in);
            bit_pos <= 0;
            ones_count <= 0;
            m_iter <= 0;
            temp_result <= 0;
        end
    end

    // Counting state logic
    always @(posedge clk) begin
        if (!rst_n && state == COUNTING) begin
            if (bit_pos < MAX_BITS) begin
                if (n_binary[bit_pos]) begin
                    ones_count <= ones_count + 1;
                end
                bit_pos <= bit_pos + 1;
            end
        end
    end

    // Result calculation
    always @(posedge clk) begin
        if (!rst_n && state == COUNTING && bit_pos == MAX_BITS) begin
            for (m_iter = 0; m_iter < MAX_M; m_iter = m_iter + 1) begin
                if (valid_m_mask[m_iter]) begin
                    temp_result = (temp_result + nCr(ones_count, m_iter)) % MOD;
                end
            end
            result <= temp_result;
            done <= 1;
        end
    end

endmodule