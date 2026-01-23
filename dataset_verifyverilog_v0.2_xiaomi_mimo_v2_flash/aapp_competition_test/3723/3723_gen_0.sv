module pokemon_gcd(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] pokemon_strength [0:7],
    output reg [7:0] result,
    output reg done
);

    // Fixed array of primes up to 255 (first 32 primes)
    reg [7:0] prime [0:31];
    // Count register array
    reg [7:0] count [0:31];
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COUNT_FACTORS = 3'b010;
    localparam FIND_MAX = 3'b011;
    localparam DONE = 3'b100;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Counters and temporary registers
    reg [3:0] idx;      // Index for Pokemon array (0-7)
    reg [5:0] p_idx;    // Index for prime array (0-31)
    reg [7:0] temp_strength;
    reg [7:0] temp_quotient;
    reg [7:0] max_count;
    reg [7:0] temp_remainder;
    
    // Initialize primes (compile-time)
    integer i;
    initial begin
        prime[0] = 2; prime[1] = 3; prime[2] = 5; prime[3] = 7;
        prime[4] = 11; prime[5] = 13; prime[6] = 17; prime[7] = 19;
        prime[8] = 23; prime[9] = 29; prime[10] = 31; prime[11] = 37;
        prime[12] = 41; prime[13] = 43; prime[14] = 47; prime[15] = 53;
        prime[16] = 59; prime[17] = 61; prime[18] = 67; prime[19] = 71;
        prime[20] = 73; prime[21] = 79; prime[22] = 83; prime[23] = 89;
        prime[24] = 97; prime[25] = 101; prime[26] = 103; prime[27] = 107;
        prime[28] = 109; prime[29] = 113; prime[30] = 127; prime[31] = 131;
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 8'b0;
            idx <= 4'b0;
            p_idx <= 6'b0;
            max_count <= 8'b0;
            // Reset counts
            for (i = 0; i < 32; i = i + 1) begin
                count[i] <= 8'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        idx <= 4'b0;
                        p_idx <= 6'b0;
                        max_count <= 8'b0;
                        // Reset counts before starting
                        for (i = 0; i < 32; i = i + 1) begin
                            count[i] <= 8'b0;
                        end
                    end
                end

                LOAD: begin
                    // Load current Pokemon strength
                    temp_strength <= pokemon_strength[idx];
                    p_idx <= 6'b0; // Reset prime index for this Pokemon
                end

                COUNT_FACTORS: begin
                    // Check divisibility using subtraction loop (combinational logic emulation)
                    // If temp_strength >= prime[p_idx], decrement and check again
                    if (p_idx < 32) begin
                        if (prime[p_idx] != 0 && temp_strength >= prime[p_idx]) begin
                            // Simple division check logic (modulo emulation)
                            // We calculate remainder via repeated subtraction in this cycle for simulation speed
                            // or just check if it divides evenly. 
                            // For hardware, let's assume we are checking if (temp_strength % prime[p_idx] == 0)
                            // Here we perform a check: if temp_strength is divisible by prime[p_idx]
                            // Since we cannot do division in one cycle easily without DSP, 
                            // we will perform a pseudo-check: (temp_strength / prime[p_idx]) * prime[p_idx] == temp_strength
                            // Note: Real hardware would use a divider or a pre-computed LUT. 
                            // We will use a loop variable logic simulation within the state machine.
                            
                            // Let's use a temporary register to perform subtraction based division check
                            // Optimization: perform check using shift if power of 2, else generic logic.
                            // To keep it simple and robust for synthesis without dividers:
                            // We will calculate the remainder by subtracting prime repeatedly.
                            // Since this is a single state cycle, we need a 'sub_step' counter or 
                            // we can rely on the fact that 8-bit division is fast. 
                            // Let's assume a helper logic: 
                            temp_quotient <= temp_strength / prime[p_idx]; // Combinational divider (inferred)
                            
                            // If remainder is 0, increment count
                            if ((temp_strength / prime[p_idx]) * prime[p_idx] == temp_strength) begin
                                count[p_idx] <= count[p_idx] + 1;
                            end
                            p_idx <= p_idx + 1;
                        end else begin
                            p_idx <= p_idx + 1; // Skip if prime > value or zero
                        end
                    end
                end

                FIND_MAX: begin
                    // Find max in count array
                    if (p_idx < 32) begin
                        if (count[p_idx] > max_count) begin
                            max_count <= count[p_idx];
                        end
                        p_idx <= p_idx + 1;
                    end else begin
                        // Ensure at least 1 if any Pokemon exists, else 0 (though problem implies min 1)
                        if (max_count == 0 && n > 0) result <= 8'd1;
                        else result <= max_count;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD; else next_state = IDLE;
            
            LOAD: next_state = COUNT_FACTORS;
            
            COUNT_FACTORS: begin
                if (p_idx >= 32) begin
                    // Finished primes for this Pokemon
                    if (idx < n - 1) begin
                        next_state = LOAD; // Next Pokemon
                    end else begin
                        next_state = FIND_MAX; // All Pokemon processed
                    end
                end else begin
                    next_state = COUNT_FACTORS;
                end
            end
            
            FIND_MAX: begin
                if (p_idx >= 32) next_state = DONE;
                else next_state = FIND_MAX;
            end
            
            DONE: if (!start) next_state = IDLE; else next_state = DONE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule