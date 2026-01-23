module powers_game(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    output reg winner,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP = 3'd2;
    localparam [2:0] CALC_L = 3'd3;
    localparam [2:0] UPDATE = 3'd4;
    localparam [2:0] FINAL = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [9:0] i;              // Current base
    reg [9:0] s;              // Sum of chain lengths
    reg [3:0] ans;            // Current XOR value
    reg [3:0] L;              // Current chain length
    reg [31:0] current_power; // For exponentiation
    reg [3:0] exponent;
    reg [9:0] sqrt_n;         // Precomputed sqrt(n)
    reg [7:0] cycle_count;    // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Lookup table for arr[0:15] (Grundy numbers)
    reg [3:0] arr [0:15];
    always @(*) begin
        arr[0] = 4'd0;
        arr[1] = 4'd1;
        arr[2] = 4'd2;
        arr[3] = 4'd1;
        arr[4] = 4'd4;
        arr[5] = 4'd3;
        arr[6] = 4'd2;
        arr[7] = 4'd1;
        arr[8] = 4'd5;
        arr[9] = 4'd6;
        arr[10] = 4'd2;
        arr[11] = 4'd1;
        arr[12] = 4'd8;
        arr[13] = 4'd7;
        arr[14] = 4'd5;
        arr[15] = 4'd9;
    end

    // Perfect power flags for i=3 to 31 (packed into 29 bits)
    // Bit i set if i is a perfect power
    reg [28:0] perfect_flags;
    always @(*) begin
        perfect_flags = 29'd0;
        // 4, 8, 9, 16, 25, 27, 32, 36, 49, 64, 81, 100, ...
        perfect_flags[4-3] = 1'b1;  // 4 = 2^2
        perfect_flags[8-3] = 1'b1;  // 8 = 2^3
        perfect_flags[9-3] = 1'b1;  // 9 = 3^2
        perfect_flags[16-3] = 1'b1; // 16 = 2^4
        perfect_flags[25-3] = 1'b1; // 25 = 5^2
        perfect_flags[27-3] = 1'b1; // 27 = 3^3
        perfect_flags[32-3] = 1'b1; // 32 = 2^5
        perfect_flags[36-3] = 1'b1; // 36 = 6^2
        perfect_flags[49-3] = 1'b1; // 49 = 7^2
        perfect_flags[64-3] = 1'b1; // 64 = 8^2, 4^3, 2^6
        perfect_flags[81-3] = 1'b1; // 81 = 9^2, 3^4
        perfect_flags[100-3] = 1'b1; // 100 = 10^2
        // Note: i max = 31, so we only care about indices 0..28
    end

    // Helper: Find floor of square root (non-restoring algorithm)
    function [9:0] sqrt;
        input [9:0] x;
        integer idx;
        begin
            sqrt = 10'd0;
            for (idx = 14; idx >= 0; idx = idx - 1) begin
                if (((sqrt + (10'd1 << idx)) * (sqrt + (10'd1 << idx))) <= x)
                    sqrt = sqrt + (10'd1 << idx);
            end
        end
    endfunction

    // Helper: Priority encoder for log2
    function [3:0] find_log2;
        input [9:0] val;
        begin
            if (val[9]) find_log2 = 4'd9;
            else if (val[8]) find_log2 = 4'd8;
            else if (val[7]) find_log2 = 4'd7;
            else if (val[6]) find_log2 = 4'd6;
            else if (val[5]) find_log2 = 4'd5;
            else if (val[4]) find_log2 = 4'd4;
            else if (val[3]) find_log2 = 4'd3;
            else if (val[2]) find_log2 = 4'd2;
            else if (val[1]) find_log2 = 4'd1;
            else find_log2 = 4'd0;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            winner <= 1'b0;
            i <= 10'd0;
            s <= 10'd0;
            ans <= 4'd0;
            L <= 4'd0;
            current_power <= 32'd0;
            exponent <= 4'd0;
            sqrt_n <= 10'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute s0 = floor(log2(n))
                    if (n < 10'd2) begin
                        ans <= arr[0];
                        s <= 10'd0;
                    end else begin
                        ans <= arr[find_log2(n)];
                        s <= find_log2(n);
                    end
                    i <= 10'd3;
                    sqrt_n <= sqrt(n);
                    state <= LOOP;
                end

                LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i > sqrt_n) begin
                        state <= FINAL;
                    end else if ((i >= 10'd3) && (i <= 10'd31) && perfect_flags[i-10'd3]) begin
                        i <= i + 10'd1;
                    end else begin
                        L <= 4'd0;
                        current_power <= 32'd1;
                        exponent <= 4'd0;
                        state <= CALC_L;
                    end
                end

                CALC_L: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute current_power = i^(exponent+1)
                    if (exponent == 4'd0) begin
                        current_power <= {22'd0, i};
                        exponent <= 4'd1;
                        // After first cycle, we have i^1
                        if (i > n) begin
                            L <= 4'd0;
                            state <= UPDATE;
                        end
                    end else begin
                        current_power <= current_power * {22'd0, i};
                        exponent <= exponent + 4'd1;
                        // Check after multiplication
                        if (current_power > n) begin
                            L <= exponent - 4'd1;
                            state <= UPDATE;
                        end else if (exponent >= 4'd10) begin
                            // Safety stop
                            L <= exponent;
                            state <= UPDATE;
                        end
                    end
                    // Additional check for immediate termination
                    if ((exponent > 4'd0) && (current_power > n)) begin
                        L <= exponent - 4'd1;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if ((L >= 4'd1) && (L <= 4'd15)) begin
                        ans <= ans ^ arr[L];
                        s <= s + {6'd0, L};
                    end
                    i <= i + 10'd1;
                    state <= LOOP;
                end

                FINAL: begin
                    cycle_count <= cycle_count + 8'd1;
                    // ans = ans XOR ((n - s) % 2)
                    if (((n - s) & 10'd1) != 10'd0) begin
                        ans <= ans ^ 4'd1;
                    end
                    // winner = 1 if ans != 0
                    winner <= (ans != 4'd0);
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety timeout
            if (cycle_count >= MAX_CYCLES) begin
                done <= 1'b1;
                winner <= 1'b0;
                state <= IDLE;
            end
        end
    end
endmodule