module find_modulus(
    input clk,
    input rst_n,
    input start,
    input [79:0] num_data,
    input [3:0] N,
    output reg [9:0] result_M,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_DIFFS = 3'd1;
    localparam [2:0] COMPUTE_GCD = 3'd2;
    localparam [2:0] ENUMERATE_DIVISORS = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [9:0] scaled_data [0:7];
    reg [10:0] diffs [0:27];
    reg [9:0] gcd_result;
    reg [9:0] current_d;
    reg [9:0] max_g;
    reg [7:0] diff_count;
    reg [7:0] pair_idx;
    reg [3:0] i, j;
    reg [9:0] temp_gcd;
    reg [9:0] a, b;
    reg [9:0] temp_diff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_M <= 10'd0;
            valid <= 1'b0;
            done <= 1'b0;
            pair_idx <= 8'd0;
            diff_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            current_d <= 10'd0;
            max_g <= 10'd0;
            temp_gcd <= 10'd0;
            a <= 10'd0;
            b <= 10'd0;
            temp_diff <= 10'd0;
            for (i = 0; i < 8; i = i + 1) begin
                scaled_data[i] <= 10'd0;
            end
            for (i = 0; i < 28; i = i + 1) begin
                diffs[i] <= 11'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_DIFFS;
                        i <= 4'd0;
                        j <= 4'd0;
                        pair_idx <= 8'd0;
                        diff_count <= 8'd0;
                        // Scale input data
                        for (i = 0; i < 8; i = i + 1) begin
                            scaled_data[i] <= num_data[(i+1)*10-1:i*10];
                        end
                    end
                end

                COMPUTE_DIFFS: begin
                    if (pair_idx < (N * (N - 1'b1)) / 2) begin
                        i <= pair_idx[3:0];
                        j <= pair_idx[7:4];
                        if (j < N) begin
                            if (scaled_data[i] > scaled_data[j]) begin
                                temp_diff <= scaled_data[i] - scaled_data[j];
                            end else begin
                                temp_diff <= scaled_data[j] - scaled_data[i];
                            end
                            diffs[pair_idx] <= temp_diff;
                            pair_idx <= pair_idx + 1'b1;
                        end else begin
                            pair_idx <= pair_idx + 1'b1;
                        end
                    end else begin
                        state <= COMPUTE_GCD;
                        diff_count <= 8'd0;
                        temp_gcd <= 10'd0;
                        max_g <= 10'd0;
                    end
                end

                COMPUTE_GCD: begin
                    if (diff_count < (N * (N - 1'b1)) / 2) begin
                        if (diffs[diff_count] != 11'd0) begin
                            if (temp_gcd == 10'd0) begin
                                temp_gcd <= diffs[diff_count];
                            end else begin
                                a <= temp_gcd;
                                b <= diffs[diff_count];
                                while (b != 10'd0) begin
                                    if (a > b) begin
                                        a <= a - b;
                                    end else begin
                                        b <= b - a;
                                    end
                                end
                                temp_gcd <= a;
                            end
                        end
                        diff_count <= diff_count + 1'b1;
                    end else begin
                        if (temp_gcd != 10'd0) begin
                            max_g <= temp_gcd;
                        end else begin
                            max_g <= 10'd1;
                        end
                        state <= ENUMERATE_DIVISORS;
                        current_d <= 10'd2;
                    end
                end

                ENUMERATE_DIVISORS: begin
                    if (current_d <= max_g) begin
                        if (max_g % current_d == 10'd0) begin
                            result_M <= current_d;
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                        current_d <= current_d + 10'd1;
                    end else begin
                        state <= FINISH;
                        valid <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule