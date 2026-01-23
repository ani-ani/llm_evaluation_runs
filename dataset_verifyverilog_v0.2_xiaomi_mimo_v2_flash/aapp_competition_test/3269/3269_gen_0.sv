module digit_distance_sum(
    input clk,
    input rst_n,
    input start,
    input [31:0] A,
    input [31:0] B,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter MOD = 32'd1000000007;
    parameter MAX_ITER = 32'd10000; // Limit iterations for testability

    // State definitions
    localparam IDLE = 3'b000;
    localparam SETUP_COUNT = 3'b001;
    localparam COUNT_LOOP = 3'b010;
    localparam SETUP_DIST = 3'b011;
    localparam CALC_DIST = 3'b100;
    localparam COMPLETE = 3'b101;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    reg [31:0] current_num;
    reg [31:0] current_pos;
    reg [31:0] d1;
    reg [31:0] d2;
    
    reg [31:0] total_sum;
    reg [31:0] partial_sum;
    reg [31:0] temp_mult;
    
    // Digit counters: 8 positions x 10 digits (flattened)
    // index = pos * 10 + digit
    reg [19:0] digit_counts [0:79];
    integer i;

    // Helper variables
    reg [31:0] count_d1;
    reg [31:0] count_d2;
    reg [31:0] abs_diff;
    reg [31:0] mul1;
    reg [31:0] mul2;

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: next_state = start ? SETUP_COUNT : IDLE;
            
            SETUP_COUNT: next_state = COUNT_LOOP;
            
            COUNT_LOOP: begin
                if (current_num > B || current_num - A >= MAX_ITER) begin
                    // Check if we need to move to next position
                    if (current_pos < 7) next_state = SETUP_COUNT; // Next position
                    else next_state = SETUP_DIST; // Done counting
                end else begin
                    next_state = COUNT_LOOP;
                end
            end
            
            SETUP_DIST: next_state = CALC_DIST;
            
            CALC_DIST: begin
                if (current_pos >= 8) next_state = COMPLETE;
                else if (d1 > 9) next_state = SETUP_DIST; // Move to next pos
                else if (d2 > 9) next_state = CALC_DIST; // Next d1 (implicitly waits for d2 reset)
                else next_state = CALC_DIST;
            end
            
            COMPLETE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            total_sum <= 0;
            current_num <= 0;
            current_pos <= 0;
            d1 <= 0;
            d2 <= 0;
            // Reset counters
            for (i = 0; i < 80; i = i + 1) begin
                digit_counts[i] <= 20'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        total_sum <= 0;
                        current_pos <= 0;
                        // Clear counters for fresh start
                        for (i = 0; i < 80; i = i + 1) begin
                            digit_counts[i] <= 20'd0;
                        end
                    end
                end

                SETUP_COUNT: begin
                    current_num <= A;
                end

                COUNT_LOOP: begin
                    if (current_num <= B && (current_num - A) < MAX_ITER) begin
                        // Extract digit at current_pos
                        // digit = (current_num / 10^pos) % 10
                        // Optimized extraction logic
                        case (current_pos)
                            0: begin
                                // Units digit
                                if (digit_counts[current_num[3:0] + 0] < 20'hFFFFF)
                                    digit_counts[current_num[3:0]] <= digit_counts[current_num[3:0]] + 1;
                            end
                            1: begin
                                // Tens digit
                                if (digit_counts[(current_num / 10) % 10 + 10] < 20'hFFFFF)
                                    digit_counts[(current_num / 10) % 10 + 10] <= digit_counts[(current_num / 10) % 10 + 10] + 1;
                            end
                            2: begin
                                if (digit_counts[(current_num / 100) % 10 + 20] < 20'hFFFFF)
                                    digit_counts[(current_num / 100) % 10 + 20] <= digit_counts[(current_num / 100) % 10 + 20] + 1;
                            end
                            3: begin
                                if (digit_counts[(current_num / 1000) % 10 + 30] < 20'hFFFFF)
                                    digit_counts[(current_num / 1000) % 10 + 30] <= digit_counts[(current_num / 1000) % 10 + 30] + 1;
                            end
                            4: begin
                                if (digit_counts[(current_num / 10000) % 10 + 40] < 20'hFFFFF)
                                    digit_counts[(current_num / 10000) % 10 + 40] <= digit_counts[(current_num / 10000) % 10 + 40] + 1;
                            end
                            5: begin
                                if (digit_counts[(current_num / 100000) % 10 + 50] < 20'hFFFFF)
                                    digit_counts[(current_num / 100000) % 10 + 50] <= digit_counts[(current_num / 100000) % 10 + 50] + 1;
                            end
                            6: begin
                                if (digit_counts[(current_num / 1000000) % 10 + 60] < 20'hFFFFF)
                                    digit_counts[(current_num / 1000000) % 10 + 60] <= digit_counts[(current_num / 1000000) % 10 + 60] + 1;
                            end
                            7: begin
                                if (digit_counts[(current_num / 10000000) % 10 + 70] < 20'hFFFFF)
                                    digit_counts[(current_num / 10000000) % 10 + 70] <= digit_counts[(current_num / 10000000) % 10 + 70] + 1;
                            end
                        endcase
                        current_num <= current_num + 1;
                    end else if (current_pos < 7) begin
                        // Reset for next position
                        current_pos <= current_pos + 1;
                        current_num <= A;
                    end
                end

                SETUP_DIST: begin
                    d1 <= 0;
                    d2 <= 0;
                    partial_sum <= 0;
                end

                CALC_DIST: begin
                    if (d1 > 9) begin
                        // Completed this position, add partial to total
                        total_sum <= (total_sum + partial_sum) % MOD;
                        current_pos <= current_pos + 1;
                    end else if (d2 > 9) begin
                        // Next d1
                        d1 <= d1 + 1;
                        d2 <= 0;
                    end else begin
                        // Accumulate contribution: count[d1] * count[d2] * |d1-d2|
                        // We compute: count[d1] * count[d2] * |d1-d2| mod MOD
                        // Note: The formula is symmetric, but we loop all pairs as requested
                        // We use pre-fetched values for multiplication
                        if (count_d1 != 0 && count_d2 != 0 && (d1 != d2 || count_d1 > 1)) begin
                            // |d1 - d2|
                            abs_diff <= (d1 > d2) ? (d1 - d2) : (d2 - d1);
                            
                            // Multiplier 1: count[d1] * count[d2]
                            mul1 <= (count_d1 * count_d2) % MOD;
                            
                            // We need a multi-cycle multiplication pipeline or combinational
                            // To ensure synthesis and timing, we do it sequentially or combinational
                            // Assuming combinational for small values, but let's do staged
                            partial_sum <= (partial_sum + ((count_d1 * count_d2) % MOD) * ((d1 > d2) ? (d1 - d2) : (d2 - d1))) % MOD;
                        end
                        d2 <= d2 + 1;
                    end
                end

                COMPLETE: begin
                    result <= total_sum;
                    done <= 1;
                end
            endcase
        end
    end

    // Helper combinational logic to fetch counts for CALC_DIST stage
    // This is needed because we are indexing the array in the combinational path
    always @(*) begin
        if (state == CALC_DIST && d1 <= 9 && d2 <= 9) begin
            count_d1 = digit_counts[current_pos * 10 + d1];
            count_d2 = digit_counts[current_pos * 10 + d2];
        end else begin
            count_d1 = 0;
            count_d2 = 0;
        end
    end

endmodule