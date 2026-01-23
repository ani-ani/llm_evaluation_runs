module rectangular_sum (
    input clk,
    input rst_n,
    input start,
    input [31:0] a,
    input [3:0] length,
    input [15:0][3:0] digits,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam IDLE = 4'd0;
    localparam PHASE1_GEN_SUBARRAYS = 4'd1;
    localparam PHASE1_STORE = 4'd2;
    localparam PHASE2_COUNT = 4'd3;
    localparam PHASE3_CALC = 4'd4;
    localparam DONE = 4'd5;

    // State machine
    reg [3:0] state = IDLE;

    // Phase 1: Subarray Sum Computation
    reg [3:0] i = 0, j = 0;
    reg [31:0] subarray_sum = 0;
    reg [31:0] subarray_sums [0:135]; // Max 136 subarrays
    reg [7:0] subarray_count = 0;

    // Phase 2: Frequency Counting
    reg [7:0] freq [0:144]; // Frequency array for sums 0-144
    reg [7:0] freq_index = 0;

    // Phase 3: Rectangle Counting
    reg [7:0] s = 0;
    reg [31:0] target = 0;
    reg [31:0] temp_result = 0;

    // Control signals
    reg phase1_done = 0;
    reg phase2_done = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            phase1_done <= 0;
            phase2_done <= 0;
            subarray_count <= 0;
            i <= 0;
            j <= 0;
            subarray_sum <= 0;
            freq_index <= 0;
            s <= 0;
            temp_result <= 0;
            for (integer k = 0; k < 136; k = k + 1) begin
                subarray_sums[k] <= 0;
            end
            for (integer k = 0; k < 145; k = k + 1) begin
                freq[k] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PHASE1_GEN_SUBARRAYS;
                        done <= 0;
                        result <= 0;
                        phase1_done <= 0;
                        phase2_done <= 0;
                        subarray_count <= 0;
                        i <= 0;
                        j <= 0;
                        subarray_sum <= 0;
                        freq_index <= 0;
                        s <= 0;
                        temp_result <= 0;
                        for (integer k = 0; k < 136; k = k + 1) begin
                            subarray_sums[k] <= 0;
                        end
                        for (integer k = 0; k < 145; k = k + 1) begin
                            freq[k] <= 0;
                        end
                    end
                end

                PHASE1_GEN_SUBARRAYS: begin
                    if (i < length) begin
                        if (j < length) begin
                            if (i <= j) begin
                                subarray_sum <= subarray_sum + digits[j];
                            end
                            j <= j + 1;
                        end else begin
                            if (i <= j - 1) begin
                                subarray_sums[subarray_count] <= subarray_sum;
                                subarray_count <= subarray_count + 1;
                            end
                            subarray_sum <= 0;
                            i <= i + 1;
                            j <= 0;
                        end
                    end else begin
                        phase1_done <= 1;
                        state <= PHASE1_STORE;
                    end
                end

                PHASE1_STORE: begin
                    if (phase1_done) begin
                        state <= PHASE2_COUNT;
                        phase1_done <= 0;
                    end
                end

                PHASE2_COUNT: begin
                    if (freq_index < subarray_count) begin
                        if (subarray_sums[freq_index] <= 144) begin
                            freq[subarray_sums[freq_index]] <= freq[subarray_sums[freq_index]] + 1;
                        end
                        freq_index <= freq_index + 1;
                    end else begin
                        phase2_done <= 1;
                        state <= PHASE3_CALC;
                    end
                end

                PHASE3_CALC: begin
                    if (a == 0) begin
                        temp_result <= (freq[0] * freq[0]) + (2 * freq[0] * (subarray_count - freq[0]));
                        state <= DONE;
                    end else begin
                        if (s < 144) begin
                            if (a % s == 0) begin
                                target <= a / s;
                                if (target <= 144 && target >= 1) begin
                                    if (s == target) begin
                                        temp_result <= temp_result + (freq[s] * freq[s]);
                                    end else if (s < target) begin
                                        temp_result <= temp_result + (2 * freq[s] * freq[target]);
                                    end
                                end
                            end
                            s <= s + 1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    result <= temp_result;
                    done <= 1;
                    if (start) begin
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule