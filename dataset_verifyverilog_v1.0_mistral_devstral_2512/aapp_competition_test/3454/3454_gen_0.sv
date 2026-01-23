module pokenom_painter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] M,          // 1..8
    input wire [3:0] N,          // 1..8
    input wire [3:0] c_0, c_1, c_2, c_3, c_4, c_5, c_6, c_7,
    output reg done,
    output reg [31:0] X,         // exponent of 100003 (always 0 for scaled inputs)
    output reg [31:0] Y_m        // Y mod 100003
);

    parameter MOD = 100003;

    // Internal registers and state machine
    reg [5:0] state;
    reg [3:0] i, j, k;
    reg [7:0] S, T, T_minus_2;
    reg [31:0] fact, H_blue, H_red, numerator, denominator, inv_denom;
    reg [3:0] c_reg [0:7];
    reg [3:0] B_cols, R_cols;
    reg [3:0] red_col_heights [0:7];

    // State definitions
    localparam [5:0] IDLE = 6'd0;
    localparam [5:0] READ_C = 6'd1;
    localparam [5:0] COMPUTE_T = 6'd2;
    localparam [5:0] SETUP_FACT = 6'd3;
    localparam [5:0] COMPUTE_FACT = 6'd4;
    localparam [5:0] SETUP_BLUE = 6'd5;
    localparam [5:0] COMPUTE_BLUE = 6'd6;
    localparam [5:0] SETUP_RED = 6'd7;
    localparam [5:0] COMPUTE_RED = 6'd8;
    localparam [5:0] COMPUTE_NUMERATOR = 6'd9;
    localparam [5:0] COMPUTE_DENOMINATOR = 6'd10;
    localparam [5:0] COMPUTE_INV = 6'd11;
    localparam [5:0] COMPUTE_RESULT = 6'd12;
    localparam [5:0] DONE = 6'd13;

    // Algorithm:
    // 1. On start, read c_i into c_reg and compute sum S.
    // 2. Compute T = M*N, T_minus_2 = T-2.
    // 3. Compute fact = (T_minus_2)! mod MOD.
    // 4. Compute blue hook product H_blue by iterating over blue cells.
    // 5. Compute red hook product H_red by iterating over red cells (reversed columns).
    // 6. numerator = fact * S % MOD * (T-S) % MOD.
    // 7. denominator = H_blue * H_red % MOD.
    // 8. inv_denom = modular inverse of denominator (using extended Euclid or Fermat).
    // 9. Y_m = numerator * inv_denom % MOD; X = 0.
    // 10. Assert done.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            X <= 32'd0;
            Y_m <= 32'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            S <= 8'd0;
            T <= 8'd0;
            T_minus_2 <= 8'd0;
            fact <= 32'd0;
            H_blue <= 32'd0;
            H_red <= 32'd0;
            numerator <= 32'd0;
            denominator <= 32'd0;
            inv_denom <= 32'd0;
            B_cols <= 4'd0;
            R_cols <= 4'd0;
            for (integer idx = 0; idx < 8; idx = idx + 1) begin
                c_reg[idx] <= 4'd0;
                red_col_heights[idx] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= READ_C;
                        i <= 4'd0;
                        S <= 8'd0;
                    end
                end

                READ_C: begin
                    if (i < N) begin
                        // Read c_i from the individual ports
                        case (i)
                            4'd0: c_reg[i] <= c_0;
                            4'd1: c_reg[i] <= c_1;
                            4'd2: c_reg[i] <= c_2;
                            4'd3: c_reg[i] <= c_3;
                            4'd4: c_reg[i] <= c_4;
                            4'd5: c_reg[i] <= c_5;
                            4'd6: c_reg[i] <= c_6;
                            4'd7: c_reg[i] <= c_7;
                        endcase
                        S <= S + c_reg[i];
                        i <= i + 4'd1;
                    end else begin
                        state <= COMPUTE_T;
                    end
                end

                COMPUTE_T: begin
                    T <= M * N;
                    T_minus_2 <= M * N - 2;
                    state <= SETUP_FACT;
                    fact <= 32'd1;
                    i <= 4'd1;
                end

                SETUP_FACT: begin
                    if (i <= T_minus_2) begin
                        fact <= (fact * i) % MOD;
                        i <= i + 4'd1;
                    end else begin
                        state <= SETUP_BLUE;
                    end
                end

                SETUP_BLUE: begin
                    // Determine number of blue columns (c_i > 0)
                    B_cols <= 4'd0;
                    for (integer idx = 0; idx < N; idx = idx + 1) begin
                        if (c_reg[idx] > 4'd0) begin
                            B_cols <= idx + 4'd1;
                        end
                    end
                    H_blue <= 32'd1;
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= COMPUTE_BLUE;
                end

                COMPUTE_BLUE: begin
                    if (i < B_cols) begin
                        if (j < c_reg[i]) begin
                            // count columns to the right with height > j
                            integer count_right;
                            count_right = 0;
                            for (integer col = i+1; col < B_cols; col = col + 1) begin
                                if (c_reg[col] > j) begin
                                    count_right = count_right + 1;
                                end
                            end
                            H_blue <= (H_blue * (j + count_right + 4'd1)) % MOD;
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        state <= SETUP_RED;
                    end
                end

                SETUP_RED: begin
                    // Compute reversed red column heights: red_col_heights[k] = M - c_reg[N-1-k]
                    for (integer idx = 0; idx < N; idx = idx + 1) begin
                        red_col_heights[idx] <= M - c_reg[N - 4'd1 - idx];
                    end
                    // Determine R_cols (non-zero heights)
                    R_cols <= 4'd0;
                    for (integer idx = 0; idx < N; idx = idx + 1) begin
                        if (red_col_heights[idx] > 4'd0) begin
                            R_cols <= idx + 4'd1;
                        end
                    end
                    H_red <= 32'd1;
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= COMPUTE_RED;
                end

                COMPUTE_RED: begin
                    if (i < R_cols) begin
                        if (j < red_col_heights[i]) begin
                            integer count_right;
                            count_right = 0;
                            for (integer col = i+1; col < R_cols; col = col + 1) begin
                                if (red_col_heights[col] > j) begin
                                    count_right = count_right + 1;
                                end
                            end
                            H_red <= (H_red * (j + count_right + 4'd1)) % MOD;
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        state <= COMPUTE_NUMERATOR;
                    end
                end

                COMPUTE_NUMERATOR: begin
                    numerator <= (((fact * S) % MOD) * (T - S)) % MOD;
                    state <= COMPUTE_DENOMINATOR;
                end

                COMPUTE_DENOMINATOR: begin
                    denominator <= (H_blue * H_red) % MOD;
                    state <= COMPUTE_INV;
                    // Initialize extended Euclidean algorithm variables
                    a <= denominator;
                    b <= MOD;
                    x0 <= 32'd1;
                    x1 <= 32'd0;
                end

                COMPUTE_INV: begin
                    // Extended Euclidean algorithm to compute inverse of denominator mod MOD
                    if (b != 32'd0) begin
                        integer quotient;
                        integer remainder;
                        integer new_x1;
                        quotient = a / b;
                        remainder = a % b;
                        new_x1 = x0 - quotient * x1;
                        a <= b;
                        b <= remainder;
                        x0 <= x1;
                        x1 <= new_x1;
                    end else begin
                        // Inverse is x0 mod MOD (handle negative)
                        if (x0 < 32'd0) begin
                            inv_denom <= x0 + MOD;
                        end else begin
                            inv_denom <= x0 % MOD;
                        end
                        state <= COMPUTE_RESULT;
                    end
                end

                COMPUTE_RESULT: begin
                    Y_m <= (numerator * inv_denom) % MOD;
                    X <= 32'd0;  // No factor of MOD for scaled inputs
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule