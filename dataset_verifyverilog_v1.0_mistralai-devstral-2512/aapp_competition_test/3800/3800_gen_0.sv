module rectangle_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] target_a,
    input wire [5:0] len,
    input wire [0:63][3:0] s,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_SUM = 3'd1;
    localparam [2:0] COUNT_PAIRS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Internal signals
    reg [5:0] i, j, k;
    reg [11:0] current_sum;
    reg [11:0] subarray_sums [0:2079];
    reg [15:0] freq [0:1023];
    reg [31:0] pair_count;
    reg [11:0] divisor;
    reg [11:0] quotient;
    reg [11:0] max_sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 6'd0;
            j <= 6'd0;
            k <= 6'd0;
            current_sum <= 12'd0;
            pair_count <= 32'd0;
            divisor <= 12'd0;
            quotient <= 12'd0;
            max_sum <= 12'd0;
            for (k = 0; k < 2080; k = k + 1) begin
                subarray_sums[k] <= 12'd0;
            end
            for (k = 0; k < 1024; k = k + 1) begin
                freq[k] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_SUM;
                        i <= 6'd0;
                        j <= 6'd0;
                        k <= 6'd0;
                        current_sum <= 12'd0;
                        pair_count <= 32'd0;
                        max_sum <= 12'd0;
                        for (k = 0; k < 2080; k = k + 1) begin
                            subarray_sums[k] <= 12'd0;
                        end
                        for (k = 0; k < 1024; k = k + 1) begin
                            freq[k] <= 16'd0;
                        end
                    end
                end

                COMPUTE_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < len) begin
                        if (j < len) begin
                            current_sum <= current_sum + s[i][3:0];
                            if (i <= j) begin
                                subarray_sums[k] <= current_sum;
                                if (current_sum > max_sum) begin
                                    max_sum <= current_sum;
                                end
                                k <= k + 1;
                            end
                            j <= j + 1;
                        end else begin
                            i <= i + 1;
                            j <= i;
                            current_sum <= s[i][3:0];
                        end
                    end else begin
                        state <= COUNT_PAIRS;
                        i <= 6'd0;
                        j <= 6'd0;
                        k <= 6'd0;
                    end
                end

                COUNT_PAIRS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < k) begin
                        if (j < k) begin
                            if (subarray_sums[i] == subarray_sums[j]) begin
                                freq[subarray_sums[i]] <= freq[subarray_sums[i]] + 16'd1;
                            end
                            j <= j + 1;
                        end else begin
                            i <= i + 1;
                            j <= i + 1;
                        end
                    end else begin
                        if (target_a == 32'd0) begin
                            for (i = 0; i < 1024; i = i + 1) begin
                                if (freq[i] > 0) begin
                                    pair_count <= pair_count + (freq[i] * (k - freq[i])) + (freq[i] * (freq[i] - 16'd1)) / 16'd2;
                                end
                            end
                        end else begin
                            for (i = 0; i < k; i = i + 1) begin
                                if (subarray_sums[i] > 0 && target_a % subarray_sums[i] == 0) begin
                                    quotient <= target_a / subarray_sums[i];
                                    if (quotient <= max_sum) begin
                                        pair_count <= pair_count + freq[quotient];
                                    end
                                end
                            end
                        end
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= pair_count;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule