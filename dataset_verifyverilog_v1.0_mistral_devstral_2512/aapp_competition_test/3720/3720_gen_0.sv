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

    // Lookup table for arr[0:15] (Grundy numbers)
    reg [3:0] arr [0:15];
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arr[0] <= 4'd0;
            arr[1] <= 4'd1;
            arr[2] <= 4'd2;
            arr[3] <= 4'd1;
            arr[4] <= 4'd4;
            arr[5] <= 4'd3;
            arr[6] <= 4'd2;
            arr[7] <= 4'd1;
            arr[8] <= 4'd5;
            arr[9] <= 4'd6;
            arr[10] <= 4'd2;
            arr[11] <= 4'd1;
            arr[12] <= 4'd8;
            arr[13] <= 4'd7;
            arr[14] <= 4'd5;
            arr[15] <= 4'd9;
        end
    end

    // Perfect power flags for i=3 to 31
    reg is_perfect [3:31];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 3; idx <= 31; idx = idx + 1) begin
                is_perfect[idx] <= 1'b0;
            end
            is_perfect[4] <= 1'b1;  // 2^2
            is_perfect[8] <= 1'b1;  // 2^3
            is_perfect[9] <= 1'b1;  // 3^2
            is_perfect[16] <= 1'b1; // 2^4
            is_perfect[25] <= 1'b1; // 5^2
            is_perfect[27] <= 1'b1; // 3^3
        end
    end

    // Helper: Find floor of square root
    function [9:0] sqrt;
        input [9:0] x;
        integer i;
        begin
            sqrt = 10'd0;
            for (i = 15; i >= 0; i = i - 1) begin
                if ((sqrt + (1 << i)) * (sqrt + (1 << i)) <= x)
                    sqrt = sqrt + (1 << i);
            end
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
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Compute s0 = floor(log2(n))
                    if (n < 2) begin
                        ans <= arr[0];
                        s <= 10'd0;
                    end else begin
                        // Priority encoder for highest bit
                        if (n[9]) ans <= arr[9];
                        else if (n[8]) ans <= arr[8];
                        else if (n[7]) ans <= arr[7];
                        else if (n[6]) ans <= arr[6];
                        else if (n[5]) ans <= arr[5];
                        else if (n[4]) ans <= arr[4];
                        else if (n[3]) ans <= arr[3];
                        else if (n[2]) ans <= arr[2];
                        else if (n[1]) ans <= arr[1];
                        else ans <= arr[0];
                        s <= (n[9]?10'd9:(n[8]?10'd8:(n[7]?10'd7:(n[6]?10'd6:(n[5]?10'd5:(n[4]?10'd4:(n[3]?10'd3:(n[2]?10'd2:(n[1]?10'd1:10'd0))))))));
                    end
                    i <= 10'd3;
                    sqrt_n <= sqrt(n);
                    state <= LOOP;
                end

                LOOP: begin
                    if (i > sqrt_n) begin
                        state <= FINAL;
                    end else if (i <= 31 && is_perfect[i]) begin
                        i <= i + 10'd1;
                    end else begin
                        L <= 4'd0;
                        current_power <= 32'd1;
                        exponent <= 4'd0;
                        state <= CALC_L;
                    end
                end

                CALC_L: begin
                    // Compute current_power = i^(exponent+1)
                    if (exponent == 4'd0) begin
                        current_power <= i;
                    end else begin
                        current_power <= current_power * i;
                    end
                    // Check after one cycle delay
                    if (exponent > 4'd0 && current_power > n) begin
                        // If current_power (i^exponent) > n, then L is exponent-1
                        L <= exponent - 4'd1;
                        state <= UPDATE;
                    end else if (exponent > 4'd0 && current_power <= n) begin
                        L <= exponent;
                    end
                    exponent <= exponent + 4'd1;
                    // Terminate if exponent too large or power exceeds n
                    if (exponent >= 10'd10 || (exponent > 4'd0 && current_power > n)) begin
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    if (L >= 4'd1 && L <= 4'd15) begin
                        ans <= ans ^ arr[L];
                        s <= s + L;
                    end
                    i <= i + 10'd1;
                    state <= LOOP;
                end

                FINAL: begin
                    // ans = ans XOR ((n - s) % 2)
                    if ((n - s) & 1'b1) ans <= ans ^ 4'd1;
                    // winner = 1 if ans != 0
                    winner <= (ans != 4'd0);
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule