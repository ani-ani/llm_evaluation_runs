module PermutationCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] N,
    input wire [31:0] K,
    output reg [30:0] result,
    output reg done
);

    // Constants
    localparam [31:0] P = 32'd2147483647;  // 2^31 - 1
    localparam [31:0] MAX_CYCLES = 32'd200;

    // Precomputed factorials (1! to 16!)
    localparam [31:0] fact [0:16] = '{32'd1, 32'd1, 32'd2, 32'd6, 32'd24, 32'd120, 32'd720, 32'd5040, 32'd40320, 32'd362880, 32'd3628800, 32'd39916800, 32'd479001600, 32'd6227020800, 32'd87178291200, 32'd1307674368000, 32'd20922789888000};

    // Precomputed modular inverses for primes 2,3,5,7,11,13
    localparam [31:0] inv_2 = 32'd1073741824;  // 2^-1 mod P
    localparam [31:0] inv_3 = 32'd1431655766;  // 3^-1 mod P
    localparam [31:0] inv_5 = 32'd858993459;   // 5^-1 mod P
    localparam [31:0] inv_7 = 32'd1255082259;  // 7^-1 mod P
    localparam [31:0] inv_11 = 32'd1952346343; // 11^-1 mod P
    localparam [31:0] inv_13 = 32'd1652838670; // 13^-1 mod P

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;

    // Internal registers
    reg [30:0] total;
    reg [30:0] current_term;
    reg [30:0] denominator;
    reg [30:0] temp_mult;
    reg [30:0] temp_add;

    // Partition and cycle tracking
    reg [3:0] current_partition;
    reg [3:0] max_partitions = 4'd233;
    reg [3:0] cycle_lengths [0:15];
    reg [3:0] cycle_counts [0:15];

    // LCM computation
    reg [31:0] lcm_result;
    reg [31:0] temp_lcm;
    reg [31:0] prime_powers [0:5];  // For primes 2,3,5,7,11,13

    // Modular arithmetic
    function [30:0] mod_add;
        input [30:0] a, b;
        begin
            mod_add = (a + b) % P;
        end
    endfunction

    function [30:0] mod_mult;
        input [30:0] a, b;
        reg [63:0] product;
        begin
            product = a * b;
            mod_mult = product[63:32] ? (product % P) : product[31:0];
        end
    endfunction

    // Modular inverse using precomputed values
    function [30:0] mod_inv;
        input [30:0] a;
        begin
            case (a)
                2: mod_inv = inv_2;
                3: mod_inv = inv_3;
                5: mod_inv = inv_5;
                7: mod_inv = inv_7;
                11: mod_inv = inv_11;
                13: mod_inv = inv_13;
                default: mod_inv = 31'd0;
            endcase
        end
    endfunction

    // LCM computation
    always @(*) begin
        temp_lcm = 1;
        for (integer i = 0; i < 6; i = i + 1) begin
            if (prime_powers[i] > 0) begin
                temp_lcm = mod_mult(temp_lcm, prime_powers[i]);
            end
        end
        lcm_result = temp_lcm;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 31'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            total <= 31'd0;
            current_partition <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state = COMPUTE;
                    end else begin
                        next_state = IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if all partitions processed
                    if (current_partition >= max_partitions) begin
                        next_state = FINISH;
                    end else begin
                        // Process current partition
                        // (In a real implementation, this would involve:
                        //  1. Loading partition data
                        //  2. Computing LCM
                        //  3. Checking if LCM == K
                        //  4. Computing multinomial coefficient
                        //  5. Adding to total)
                        
                        // Simplified for synthesis
                        current_term = 31'd0;
                        denominator = 31'd1;
                        
                        // Compute denominator: product of (length^count * count!)
                        for (integer i = 0; i < 16; i = i + 1) begin
                            if (cycle_counts[i] > 0) begin
                                // Compute length^count
                                temp_mult = 1;
                                for (integer j = 0; j < cycle_counts[i]; j = j + 1) begin
                                    temp_mult = mod_mult(temp_mult, i + 1);
                                end
                                
                                // Multiply by count!
                                temp_mult = mod_mult(temp_mult, fact[cycle_counts[i]]);
                                
                                // Add to denominator
                                denominator = mod_mult(denominator, temp_mult);
                            end
                        end
                        
                        // Compute multinomial coefficient: N! / denominator
                        current_term = mod_mult(fact[N], mod_inv(denominator));
                        
                        // Add to total if LCM matches K
                        if (lcm_result == K) begin
                            total = mod_add(total, current_term);
                        end
                        
                        current_partition <= current_partition + 4'd1;
                        
                        if (cycle_count >= MAX_CYCLES) begin
                            next_state = FINISH;
                        end else begin
                            next_state = COMPUTE;
                        end
                    end
                end

                FINISH: begin
                    result <= total;
                    done <= 1'b1;
                    next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

    // Initialize arrays (simplified for synthesis)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                cycle_lengths[i] <= 4'd0;
                cycle_counts[i] <= 4'd0;
            end
        end
    end

endmodule