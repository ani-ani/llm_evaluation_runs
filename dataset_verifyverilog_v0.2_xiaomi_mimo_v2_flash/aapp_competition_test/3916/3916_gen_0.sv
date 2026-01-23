module factorial_path_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] k_value,
    input wire [15:0] fragment_count,
    input wire input_done,
    output reg [31:0] total_distance,
    output reg done
);

parameter MAX_K = 5000;
parameter MAX_PRIMES = 670;
parameter PRIME_LIMIT = 669;

parameter IDLE = 3'b000;
parameter PRELOAD = 3'b001;
parameter COMPUTE_BASE = 3'b010;
parameter OPTIMIZE = 3'b011;
parameter DONE = 3'b100;

reg [2:0] state;
reg [15:0] k_reg;
reg [31:0] count_reg;

reg [31:0] k_counts [0:63];
reg [5:0] input_ptr;

reg [3:0] prime_factors [0:63][0:16];

reg [3:0] current_exponents [0:16];

reg [31:0] base_distance;
reg [5:0] processing_idx;
reg [3:0] prime_idx;

reg [31:0] total_fragments;
reg [31:0] branch_count;
reg [31:0] current_sum;
reg [31:0] best_sum;
reg [3:0] best_prime;
reg [31:0] prime_freq [0:16];
reg [5:0] i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        total_distance <= 0;
        done <= 0;
        input_ptr <= 0;
        base_distance <= 0;
        processing_idx <= 0;
        prime_idx <= 0;
        total_fragments <= 0;
        current_sum <= 0;
        best_sum <= 32'hFFFF_FFFF;
        for (i = 0; i < 64; i = i + 1) k_counts[i] <= 0;
        for (i = 0; i < 17; i = i + 1) begin
            current_exponents[i] <= 0;
            prime_freq[i] <= 0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start && !input_done) begin
                    state <= PRELOAD;
                    input_ptr <= 0;
                    base_distance <= 0;
                    total_fragments <= 0;
                    for (i = 0; i < 64; i = i + 1) k_counts[i] <= 0;
                    for (i = 0; i < 17; i = i + 1) begin
                        current_exponents[i] <= 0;
                        prime_freq[i] <= 0;
                    end
                end
            end
            
            PRELOAD: begin
                if (k_value < 64) begin
                    k_counts[k_value] <= k_counts[k_value] + fragment_count;
                    total_fragments <= total_fragments + fragment_count;
                end
                if (input_done) begin
                    state <= COMPUTE_BASE;
                    processing_idx <= 0;
                    prime_idx <= 0;
                end
            end
            
            COMPUTE_BASE: begin
                if (processing_idx < 64) begin
                    if (k_counts[processing_idx] > 0) begin
                        case (processing_idx)
                            2: base_distance <= base_distance + k_counts[processing_idx];
                            3: base_distance <= base_distance + k_counts[processing_idx] * 2;
                            4: base_distance <= base_distance + k_counts[processing_idx] * 4;
                            5: base_distance <= base_distance + k_counts[processing_idx] * 6;
                            6: base_distance <= base_distance + k_counts[processing_idx] * 8;
                            7: base_distance <= base_distance + k_counts[processing_idx] * 10;
                            8: base_distance <= base_distance + k_counts[processing_idx] * 13;
                            9: base_distance <= base_distance + k_counts[processing_idx] * 15;
                            10: base_distance <= base_distance + k_counts[processing_idx] * 17;
                            default: base_distance <= base_distance + k_counts[processing_idx] * (processing_idx * 2);
                        endcase
                    end
                    processing_idx <= processing_idx + 1;
                end else begin
                    current_sum <= base_distance;
                    best_sum <= base_distance;
                    current_exponents[0] <= 3;
                    current_exponents[1] <= 2;
                    current_exponents[2] <= 1;
                    state <= OPTIMIZE;
                    processing_idx <= 0;
                    prime_idx <= 0;
                end
            end
            
            OPTIMIZE: begin
                if (processing_idx < 64) begin
                    if (k_counts[processing_idx] > 0 && processing_idx >= 2) begin
                        if (processing_idx % 2 == 0) prime_freq[0] <= prime_freq[0] + k_counts[processing_idx];
                        if (processing_idx % 3 == 0) prime_freq[1] <= prime_freq[1] + k_counts[processing_idx];
                        if (processing_idx % 5 == 0) prime_freq[2] <= prime_freq[2] + k_counts[processing_idx];
                        if (processing_idx % 7 == 0) prime_freq[3] <= prime_freq[3] + k_counts[processing_idx];
                    end
                    processing_idx <= processing_idx + 1;
                end else begin
                    if (prime_freq[0] > (total_fragments >> 1) && prime_freq[0] > 0) begin
                        current_sum <= current_sum - prime_freq[0] + (total_fragments - prime_freq[0]);
                        best_sum <= (current_sum - prime_freq[0] + (total_fragments - prime_freq[0])) < best_sum ? 
                                    (current_sum - prime_freq[0] + (total_fragments - prime_freq[0])) : best_sum;
                    end
                    if (prime_freq[1] > (total_fragments >> 1) && prime_freq[1] > 0) begin
                        current_sum <= current_sum - prime_freq[1] + (total_fragments - prime_freq[1]);
                        best_sum <= (current_sum - prime_freq[1] + (total_fragments - prime_freq[1])) < best_sum ? 
                                    (current_sum - prime_freq[1] + (total_fragments - prime_freq[1])) : best_sum;
                    end
                    state <= DONE;
                end
            end
            
            DONE: begin
                total_distance <= best_sum;
                done <= 1;
                if (!start) state <= IDLE;
            end
        endcase
    end
end

endmodule

module factorial_path_wrapper (
    input wire clk,
    input wire rst_n,
    input wire [15:0] k_value,
    input wire [15:0] fragment_count,
    input wire input_done,
    input wire start,
    output wire [31:0] total_distance,
    output wire done
);

factorial_path_optimizer optimizer (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .k_value(k_value),
    .fragment_count(fragment_count),
    .input_done(input_done),
    .total_distance(total_distance),
    .done(done)
);

endmodule