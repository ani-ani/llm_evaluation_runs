module xorbonacci (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire query,
    input wire [7:0] a0, a1, a2, a3,
    input wire [15:0] l, r,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOADING = 3'd1;
    localparam [2:0] READY = 3'd2;
    localparam [2:0] COMPUTING = 3'd3;
    localparam [2:0] RESULT = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg [7:0] P0, P1, P2, P3, P4;  // Prefix XOR table elements
    reg [15:0] l_reg, r_reg;        // Stored query indices
    reg [2:0] rem_l, rem_r;         // Remainders modulo 5

    // Helper function: compute 16-bit value modulo 5
    function [2:0] mod5;
        input [15:0] val;
        reg [4:0] sum_low, sum_high;
        reg [4:0] rlow, rhigh;
        begin
            // Low byte: split into two 4-bit parts
            sum_low = val[7:4] + val[3:0];
            // Compute remainder by subtracting multiples of 5
            if (sum_low >= 25) rlow = sum_low - 25;
            else if (sum_low >= 20) rlow = sum_low - 20;
            else if (sum_low >= 15) rlow = sum_low - 15;
            else if (sum_low >= 10) rlow = sum_low - 10;
            else if (sum_low >= 5)  rlow = sum_low - 5;
            else rlow = sum_low;
            // High byte: split into two 4-bit parts
            sum_high = val[15:12] + val[11:8];
            if (sum_high >= 25) rhigh = sum_high - 25;
            else if (sum_high >= 20) rhigh = sum_high - 20;
            else if (sum_high >= 15) rhigh = sum_high - 15;
            else if (sum_high >= 10) rhigh = sum_high - 10;
            else if (sum_high >= 5)  rhigh = sum_high - 5;
            else rhigh = sum_high;
            // Combine
            mod5 = rhigh + rlow;
            if (mod5 >= 5) mod5 = mod5 - 5;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            P0 <= 8'd0;
            P1 <= 8'd0;
            P2 <= 8'd0;
            P3 <= 8'd0;
            P4 <= 8'd0;
            l_reg <= 16'd0;
            r_reg <= 16'd0;
            rem_l <= 3'd0;
            rem_r <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Compute prefix XOR table P[0..4]
                        P0 <= 8'd0;
                        P1 <= a0;
                        P2 <= a0 ^ a1;
                        P3 <= a0 ^ a1 ^ a2;
                        P4 <= a0 ^ a1 ^ a2 ^ a3;
                        state <= LOADING;
                    end
                end

                LOADING: begin
                    // One cycle to let P settle
                    state <= READY;
                end

                READY: begin
                    if (query) begin
                        l_reg <= l;
                        r_reg <= r;
                        state <= COMPUTING;
                    end
                end

                COMPUTING: begin
                    // Compute remainders using the function
                    rem_l <= mod5(l_reg);
                    rem_r <= mod5(r_reg);
                    state <= RESULT;
                end

                RESULT: begin
                    // XOR the two prefix values
                    case (rem_r)
                        3'd0: result <= P0;
                        3'd1: result <= P1;
                        3'd2: result <= P2;
                        3'd3: result <= P3;
                        3'd4: result <= P4;
                        default: result <= 8'd0;
                    endcase
                    case (rem_l)
                        3'd0: result <= result ^ P0;
                        3'd1: result <= result ^ P1;
                        3'd2: result <= result ^ P2;
                        3'd3: result <= result ^ P3;
                        3'd4: result <= result ^ P4;
                        default: result <= result ^ 8'd0;
                    endcase
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b0;
                    state <= READY;  // Ready for next query
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule