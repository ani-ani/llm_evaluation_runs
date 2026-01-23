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
    
    // State Definition
    localparam IDLE = 3'b000;
    localparam READ_PRIMES = 3'b001;
    localparam CALCULATE_DP = 3'b010;
    localparam UPDATE_RESULT = 3'b011;
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state;
    reg [3:0] i; // Index for input array
    reg [7:0] dp [0:255]; // DP array for primes
    reg [7:0] current_max;
    reg [7:0] temp_max;
    
    // LUT for Prime Factors (Simplified for Synthesis)
    // Maps value 0-255 to a bitmask of primes (Primes 2, 3, 5, 7, 11, 13, 17, 19)
    // Bit 0: 2, Bit 1: 3, Bit 2: 5, etc.
    wire [7:0] prime_mask [0:255];
    
    // Combinational Logic to generate prime masks
    // This is a simplified combinational block representing the LUT requirement
    genvar k;
    generate
        for (k = 0; k < 256; k = k + 1) begin : prime_mask_gen
            assign prime_mask[k] = (
                ((k % 2 == 0) ? 8'h01 : 8'h00) |
                ((k % 3 == 0) ? 8'h02 : 8'h00) |
                ((k % 5 == 0) ? 8'h04 : 8'h00) |
                ((k % 7 == 0) ? 8'h08 : 8'h00) |
                ((k % 11 == 0) ? 8'h10 : 8'h00) |
                ((k % 13 == 0) ? 8'h20 : 8'h00) |
                ((k % 17 == 0) ? 8'h40 : 8'h00) |
                ((k % 19 == 0) ? 8'h80 : 8'h00)
            );
        end
    endgenerate

    // Helper variables for combinational logic
    reg [7:0] current_mask;
    reg [7:0] current_prime;
    reg [7:0] found_max;
    integer p;
    
    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'b0;
            result <= 8'b0;
            done <= 1'b0;
            current_max <= 8'b0;
            temp_max <= 8'b0;
            // Reset DP array
            for (integer idx = 0; idx < 256; idx = idx + 1) begin
                dp[idx] <= 8'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'b0;
                    result <= 8'b0;
                    current_max <= 8'b0;
                    // Only reset DP if starting a new sequence to keep history if needed, 
                    // but problem implies fresh computation per start. We reset DP on start.
                    // Actually, standard practice is to reset DP on IDLE start or keep it if processing stream.
                    // Given "wait for start", we will clear DP here.
                    for (integer idx = 0; idx < 256; idx = idx + 1) begin
                        dp[idx] <= 8'b0;
                    end
                    if (start) begin
                        state <= READ_PRIMES;
                    end
                end

                READ_PRIMES: begin
                    // Get mask for current input value (clamped to 255 as per inputs a_i <= 256)
                    // If a[i] is 0 or 1, mask is 0 (no prime factors)
                    current_mask <= prime_mask[a[i][7:0]]; 
                    state <= CALCULATE_DP;
                    temp_max <= 8'b0; // Initialize max finder
                    current_prime <= 8'h01; // Start checking prime 2 (bit 0)
                    p <= 0; // Bit index
                end

                CALCULATE_DP: begin
                    // Find max(dp[p]) for all prime factors p of a[i]
                    // We iterate through 8 possible primes (bits in mask)
                    if (p < 8) begin
                        if (current_mask[p]) begin
                            // This is a prime factor
                            // Map bit index p to actual prime value for DP index
                            // Simple map: p=0->2, p=1->3, p=2->5, p=3->7, p=4->11, p=5->13, p=6->17, p=7->19
                            // For simplicity in this generic code, we use the bit index shifted as address or map it.
                            // Let's use a mapping logic:
                            case (p)
                                0: if (dp[2] > temp_max) temp_max <= dp[2];
                                1: if (dp[3] > temp_max) temp_max <= dp[3];
                                2: if (dp[5] > temp_max) temp_max <= dp[5];
                                3: if (dp[7] > temp_max) temp_max <= dp[7];
                                4: if (dp[11] > temp_max) temp_max <= dp[11];
                                5: if (dp[13] > temp_max) temp_max <= dp[13];
                                6: if (dp[17] > temp_max) temp_max <= dp[17];
                                7: if (dp[19] > temp_max) temp_max <= dp[19];
                            endcase
                        end
                        p <= p + 1;
                    end else begin
                        state <= UPDATE_RESULT;
                        p <= 0; // Reset p for update phase
                    end
                end

                UPDATE_RESULT: begin
                    // Update dp[p] = max + 1 for all prime factors p of a[i]
                    // Update global max if needed
                    if (p < 8) begin
                        if (current_mask[p]) begin
                            case (p)
                                0: dp[2] <= temp_max + 1;
                                1: dp[3] <= temp_max + 1;
                                2: dp[5] <= temp_max + 1;
                                3: dp[7] <= temp_max + 1;
                                4: dp[11] <= temp_max + 1;
                                5: dp[13] <= temp_max + 1;
                                6: dp[17] <= temp_max + 1;
                                7: dp[19] <= temp_max + 1;
                            endcase
                        end
                        p <= p + 1;
                    end else begin
                        // Update global result
                        if (temp_max + 1 > current_max) begin
                            current_max <= temp_max + 1;
                            result <= temp_max + 1;
                        end
                        
                        // Check if we processed all inputs
                        if (i < n - 1) begin
                            i <= i + 1;
                            state <= READ_PRIMES;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Stay here until reset or start goes low (implied behavior, usually wait for reset)
                    // If we want to handle restart without reset, we could check !start.
                    // But let's stick to holding done high until reset.
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
