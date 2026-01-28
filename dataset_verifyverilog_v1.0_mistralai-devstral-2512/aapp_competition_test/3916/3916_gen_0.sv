module factorial_median_path(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] k_i [0:199],
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PREPROCESS = 3'd1;
    localparam [2:0] PRIME_LOOP = 3'd2;
    localparam [2:0] MERGE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Precomputed primes (first 16 primes)
    localparam [15:0] primes [0:15] = '{16'd2, 16'd3, 16'd5, 16'd7, 16'd11, 16'd13, 16'd17, 16'd19, 16'd23, 16'd29, 16'd31, 16'd37, 16'd41, 16'd43, 16'd47, 16'd53};

    // Exponent storage (5-bit per exponent, 16 primes, 200 nodes)
    reg [4:0] exponents [0:15][0:199];
    reg [4:0] median_exponents [0:15];

    // Loop counters
    reg [7:0] prime_idx;
    reg [7:0] node_idx;
    reg [7:0] merge_idx;
    reg [7:0] cycle_count;

    // Temporary registers
    reg [15:0] current_k;
    reg [4:0] current_exp;
    reg [15:0] temp_k;
    reg [4:0] temp_exp;
    reg [15:0] temp_prime;

    // Distance calculation
    reg [31:0] total_distance;
    reg [4:0] exp_diff;

    // Cycle limit
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            prime_idx <= 8'd0;
            node_idx <= 8'd0;
            merge_idx <= 8'd0;
            cycle_count <= 8'd0;
            current_k <= 16'd0;
            current_exp <= 5'd0;
            temp_k <= 16'd0;
            temp_exp <= 5'd0;
            temp_prime <= 16'd0;
            total_distance <= 32'd0;
            exp_diff <= 5'd0;
            result <= 32'd0;
            done <= 1'b0;

            // Initialize exponent arrays
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 200; j = j + 1) begin
                    exponents[i][j] <= 5'd0;
                end
                median_exponents[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PREPROCESS;
                        node_idx <= 8'd0;
                        prime_idx <= 8'd0;
                        cycle_count <= 8'd0;
                    end
                end

                PREPROCESS: begin
                    // Compute exponents for current node
                    if (node_idx < n) begin
                        current_k <= k_i[node_idx];
                        prime_idx <= 8'd0;
                        next_state <= PRIME_LOOP;
                    end else begin
                        next_state <= MERGE;
                        merge_idx <= 8'd0;
                    end
                end

                PRIME_LOOP: begin
                    if (prime_idx < 16) begin
                        temp_prime <= primes[prime_idx];
                        temp_k <= current_k;
                        temp_exp <= 5'd0;

                        // Compute exponent of prime in k!
                        // Using Legendre's formula: sum floor(k/p^i)
                        integer i;
                        reg [15:0] p_power;
                        reg [15:0] p_power_next;
                        reg [4:0] exp_accum;

                        exp_accum = 5'd0;
                        p_power = temp_prime;
                        p_power_next = p_power * temp_prime;

                        for (i = 0; i < 16; i = i + 1) begin
                            if (p_power > temp_k) begin
                                break;
                            end
                            exp_accum = exp_accum + (temp_k / p_power);
                            p_power = p_power_next;
                            p_power_next = p_power * temp_prime;
                        end

                        exponents[prime_idx][node_idx] <= exp_accum;
                        prime_idx <= prime_idx + 8'd1;
                    end else begin
                        node_idx <= node_idx + 8'd1;
                        next_state <= PREPROCESS;
                    end
                end

                MERGE: begin
                    if (merge_idx < 16) begin
                        // Find median exponent for current prime
                        integer i, j;
                        reg [4:0] freq [0:31];
                        reg [4:0] max_freq_exp;
                        reg [7:0] max_freq;

                        // Initialize frequency array
                        for (i = 0; i < 32; i = i + 1) begin
                            freq[i] = 8'd0;
                        end

                        // Count frequencies
                        for (i = 0; i < n; i = i + 1) begin
                            temp_exp = exponents[merge_idx][i];
                            freq[temp_exp] = freq[temp_exp] + 8'd1;
                        end

                        // Find exponent with max frequency
                        max_freq = 8'd0;
                        max_freq_exp = 5'd0;
                        for (i = 0; i < 32; i = i + 1) begin
                            if (freq[i] > max_freq) begin
                                max_freq = freq[i];
                                max_freq_exp = i;
                            end
                        end

                        // If majority, use it; else use middle value
                        if (max_freq > (n >> 1)) begin
                            median_exponents[merge_idx] <= max_freq_exp;
                        end else begin
                            // Simple approximation: use average
                            reg [8:0] sum;
                            sum = 9'd0;
                            for (i = 0; i < n; i = i + 1) begin
                                sum = sum + exponents[merge_idx][i];
                            end
                            median_exponents[merge_idx] <= sum / n;
                        end

                        merge_idx <= merge_idx + 8'd1;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Calculate total distance
                    integer i, j;
                    reg [31:0] dist;

                    dist = 32'd0;
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            exp_diff = exponents[j][i] - median_exponents[j];
                            if (exp_diff[4]) begin
                                dist = dist + (~exp_diff + 5'd1);
                            end else begin
                                dist = dist + exp_diff;
                            end
                        end
                    end

                    result <= dist;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule