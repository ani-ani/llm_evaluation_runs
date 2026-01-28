module DigitCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] L_digits [0:15],
    input wire [3:0] R_digits [0:15],
    input wire [3:0] len_L,
    input wire [3:0] len_R,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [5:0] MAX_DIFF = 6'd32; // -16 to +16
    localparam [5:0] ZERO_DIFF = 6'd16;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PREPROCESS_L = 3'd1;
    localparam [2:0] COMPUTE_R = 3'd2;
    localparam [2:0] COMPUTE_L_MINUS_1 = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // State machine
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd5000;

    // Preprocessing L-1
    reg [3:0] L_minus_1 [0:15];
    reg [3:0] borrow;
    reg [3:0] i;

    // DP state
    reg [3:0] pos;
    reg tight;
    reg lead;
    reg signed [5:0] diff;
    reg [31:0] dp_count;
    reg [31:0] total_R;
    reg [31:0] total_L_minus_1;

    // Temporary variables
    reg [3:0] current_digit;
    reg [3:0] bound;
    reg [3:0] d;
    reg [5:0] new_diff;
    reg new_tight;
    reg new_lead;
    reg [31:0] temp_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            borrow <= 4'd0;
            pos <= 4'd0;
            tight <= 1'b0;
            lead <= 1'b1;
            diff <= 6'd0;
            dp_count <= 32'd0;
            total_R <= 32'd0;
            total_L_minus_1 <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PREPROCESS_L;
                    end
                end

                PREPROCESS_L: begin
                    // Subtract 1 from L
                    if (i == 4'd0) begin
                        borrow <= 4'd1;
                    end
                    if (i < len_L) begin
                        if (borrow) begin
                            if (L_digits[i] == 4'd0) begin
                                L_minus_1[i] <= 4'd9;
                                borrow <= 4'd1;
                            end else begin
                                L_minus_1[i] <= L_digits[i] - 4'd1;
                                borrow <= 4'd0;
                            end
                        end else begin
                            L_minus_1[i] <= L_digits[i];
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        state <= COMPUTE_R;
                    end
                end

                COMPUTE_R: begin
                    // Initialize DP for R
                    if (pos == 4'd0) begin
                        pos <= 4'd0;
                        tight <= 1'b1;
                        lead <= 1'b1;
                        diff <= 6'd0;
                        dp_count <= 32'd0;
                    end

                    // DP transition
                    if (pos < len_R) begin
                        bound <= tight ? R_digits[pos] : 4'd9;
                        temp_count <= 32'd0;
                        for (d = 4'd0; d <= bound; d = d + 4'd1) begin
                            if (d == 4'd4) continue; // Skip digit 4

                            new_tight <= tight && (d == bound);
                            new_lead <= lead && (d == 4'd0);

                            if (new_lead) begin
                                new_diff <= diff;
                            end else begin
                                if (d == 4'd6 || d == 4'd8) begin
                                    new_diff <= diff + 6'd1;
                                end else begin
                                    new_diff <= diff - 6'd1;
                                end
                            end

                            // Check bounds
                            if (new_diff < 6'd0 || new_diff > 6'd32) continue;

                            // Accumulate count
                            temp_count <= temp_count + 32'd1;
                        end

                        dp_count <= (dp_count + temp_count) % MOD;
                        pos <= pos + 4'd1;
                    end else begin
                        // Final state check
                        if (diff == ZERO_DIFF && !lead) begin
                            total_R <= (total_R + 32'd1) % MOD;
                        end
                        total_R <= (total_R + dp_count) % MOD;
                        state <= COMPUTE_L_MINUS_1;
                        pos <= 4'd0;
                    end
                end

                COMPUTE_L_MINUS_1: begin
                    // Initialize DP for L-1
                    if (pos == 4'd0) begin
                        pos <= 4'd0;
                        tight <= 1'b1;
                        lead <= 1'b1;
                        diff <= 6'd0;
                        dp_count <= 32'd0;
                    end

                    // DP transition
                    if (pos < len_L) begin
                        bound <= tight ? L_minus_1[pos] : 4'd9;
                        temp_count <= 32'd0;
                        for (d = 4'd0; d <= bound; d = d + 4'd1) begin
                            if (d == 4'd4) continue; // Skip digit 4

                            new_tight <= tight && (d == bound);
                            new_lead <= lead && (d == 4'd0);

                            if (new_lead) begin
                                new_diff <= diff;
                            end else begin
                                if (d == 4'd6 || d == 4'd8) begin
                                    new_diff <= diff + 6'd1;
                                end else begin
                                    new_diff <= diff - 6'd1;
                                end
                            end

                            // Check bounds
                            if (new_diff < 6'd0 || new_diff > 6'd32) continue;

                            // Accumulate count
                            temp_count <= temp_count + 32'd1;
                        end

                        dp_count <= (dp_count + temp_count) % MOD;
                        pos <= pos + 4'd1;
                    end else begin
                        // Final state check
                        if (diff == ZERO_DIFF && !lead) begin
                            total_L_minus_1 <= (total_L_minus_1 + 32'd1) % MOD;
                        end
                        total_L_minus_1 <= (total_L_minus_1 + dp_count) % MOD;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= (total_R - total_L_minus_1 + MOD) % MOD;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Cycle counter for safety
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end
endmodule