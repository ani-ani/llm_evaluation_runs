module JonSnowProbability(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] f_in,
    input wire [3:0] w_in,
    input wire [3:0] h_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MOD_MINUS_2 = 32'd1000000005;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_TOTAL = 3'd1;
    localparam [2:0] CALC_VALID = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] f, w, h;
    reg [31:0] total_count, valid_count;
    reg [31:0] temp_a, temp_b, temp_c;
    reg [31:0] factorial, inv_factorial;
    reg [3:0] k, i, j;
    reg [31:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            total_count <= 32'd0;
            valid_count <= 32'd0;
            f <= 4'd0;
            w <= 4'd0;
            h <= 4'd0;
            k <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            factorial <= 32'd0;
            inv_factorial <= 32'd0;
            temp_a <= 32'd0;
            temp_b <= 32'd0;
            temp_c <= 32'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        f <= f_in;
                        w <= w_in;
                        h <= h_in;
                        next_state <= CALC_TOTAL;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_TOTAL: begin
                    // Calculate total arrangements
                    total_count <= 32'd0;
                    k <= 4'd1;
                    next_state <= CALC_TOTAL;

                    // Iterate over possible stack counts
                    if (k <= (f + w)) begin
                        // Calculate combinations for total arrangements
                        // Total ways to arrange f food and w wine into k stacks
                        // This is a simplified approach for small numbers
                        temp_a <= 32'd1;
                        temp_b <= 32'd1;
                        
                        // Calculate factorial for (f + w - 1) choose (k - 1)
                        // Using iterative multiplication
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < (f + w)) begin
                                temp_a <= (temp_a * (i + 1)) % MOD;
                            end
                        end
                        
                        // Calculate factorial for (k - 1)
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < k) begin
                                temp_b <= (temp_b * (i + 1)) % MOD;
                            end
                        end
                        
                        // Calculate factorial for (f + w - k)
                        temp_c <= 32'd1;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < (f + w - k)) begin
                                temp_c <= (temp_c * (i + 1)) % MOD;
                            end
                        end
                        
                        // Calculate combinations: C(f + w - 1, k - 1)
                        // Using modular inverse
                        inv_factorial <= mod_inverse(temp_b * temp_c % MOD, MOD, MOD_MINUS_2);
                        total_count <= (total_count + (temp_a * inv_factorial % MOD)) % MOD;
                        
                        k <= k + 1;
                    end else begin
                        next_state <= CALC_VALID;
                    end
                end

                CALC_VALID: begin
                    // Calculate valid arrangements
                    valid_count <= 32'd0;
                    k <= 4'd1;
                    next_state <= CALC_VALID;

                    // Iterate over possible stack counts
                    if (k <= (f + w)) begin
                        // Check if wine can be split into k stacks with each > h
                        if (w > (k * (h + 1))) begin
                            // Calculate combinations for valid wine arrangements
                            // C(w - k*(h+1) + k - 1, k - 1) = C(w - k*h - 1, k - 1)
                            temp_a <= 32'd1;
                            temp_b <= 32'd1;
                            
                            // Calculate factorial for (w - k*h - 1)
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < (w - k * h - 1)) begin
                                    temp_a <= (temp_a * (i + 1)) % MOD;
                                end
                            end
                            
                            // Calculate factorial for (k - 1)
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < k) begin
                                    temp_b <= (temp_b * (i + 1)) % MOD;
                                end
                            end
                            
                            // Calculate factorial for (w - k*h - 1 - (k - 1))
                            temp_c <= 32'd1;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < (w - k * h - k)) begin
                                    temp_c <= (temp_c * (i + 1)) % MOD;
                                end
                            end
                            
                            // Calculate combinations: C(w - k*h - 1, k - 1)
                            inv_factorial <= mod_inverse(temp_b * temp_c % MOD, MOD, MOD_MINUS_2);
                            valid_count <= (valid_count + (temp_a * inv_factorial % MOD)) % MOD;
                        end
                        
                        k <= k + 1;
                    end else begin
                        next_state <= COMPUTE_RESULT;
                    end
                end

                COMPUTE_RESULT: begin
                    // Compute result = valid_count * mod_inverse(total_count) % MOD
                    if (total_count != 0) begin
                        inv_factorial <= mod_inverse(total_count, MOD, MOD_MINUS_2);
                        result <= (valid_count * inv_factorial) % MOD;
                    end else begin
                        result <= 32'd0;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Modular inverse function using Fermat's Little Theorem
    function [31:0] mod_inverse;
        input [31:0] a;
        input [31:0] mod;
        input [31:0] mod_minus_2;
        reg [31:0] result;
        reg [31:0] base;
        reg [31:0] exponent;
        reg [31:0] temp;
        integer i;

        begin
            result = 32'd1;
            base = a % mod;
            exponent = mod_minus_2;

            for (i = 0; i < 32; i = i + 1) begin
                if (exponent[i]) begin
                    result = (result * base) % mod;
                end
                base = (base * base) % mod;
            end

            mod_inverse = result;
        end
    endfunction

endmodule