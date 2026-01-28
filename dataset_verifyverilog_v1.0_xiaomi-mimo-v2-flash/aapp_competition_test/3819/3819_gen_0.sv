module card_arrangement(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] a [0:15],
    input wire [3:0] b [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CHECK_SORTED  = 3'd1;
    localparam [2:0] CHECK_SUFFIX  = 3'd2;
    localparam [2:0] CALC_MAX      = 3'd3;
    localparam [2:0] FINISHED      = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] n_reg;
    reg [3:0] a_reg [0:15];
    reg [3:0] b_reg [0:15];
    reg [3:0] suffix_len;
    reg [15:0] max_val;
    reg [15:0] temp_val;
    reg [7:0] counter;
    reg [7:0] i;
    reg [3:0] start_idx;
    reg [3:0] check_num;
    reg valid_suffix;
    reg found;
    reg [3:0] next_num;
    
    integer loop_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            for (loop_idx = 0; loop_idx < 16; loop_idx = loop_idx + 1) begin
                a_reg[loop_idx] <= 4'd0;
                b_reg[loop_idx] <= 4'd0;
            end
            suffix_len <= 4'd0;
            max_val <= 16'd0;
            temp_val <= 16'd0;
            counter <= 8'd0;
            i <= 8'd0;
            start_idx <= 4'd0;
            check_num <= 4'd0;
            valid_suffix <= 1'b0;
            found <= 1'b0;
            next_num <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 8'd0;
                    i <= 8'd0;
                    start_idx <= 4'd0;
                    check_num <= 4'd0;
                    valid_suffix <= 1'b0;
                    found <= 1'b0;
                    next_num <= 4'd0;
                    if (start) begin
                        n_reg <= n;
                        // Latch inputs
                        for (loop_idx = 0; loop_idx < 16; loop_idx = loop_idx + 1) begin
                            a_reg[loop_idx] <= a[loop_idx];
                            b_reg[loop_idx] <= b[loop_idx];
                        end
                        state <= CHECK_SORTED;
                    end
                end

                CHECK_SORTED: begin
                    // Check if b[0..n-1] is 1,2,3...n
                    valid_suffix <= 1'b1;
                    if (i < n_reg) begin
                        if (b_reg[i] != (i + 4'd1)) begin
                            valid_suffix <= 1'b0;
                        end
                        i <= i + 8'd1;
                    end else begin
                        // Finished checking
                        if (valid_suffix) begin
                            result <= 16'd0;
                            state <= FINISHED;
                        end else begin
                            state <= CHECK_SUFFIX;
                            i <= 8'd0;
                            start_idx <= 4'd0;
                            found <= 1'b0;
                        end
                    end
                end

                CHECK_SUFFIX: begin
                    // Find index of card 1 in pile
                    if (i < 16 && !found) begin
                        if (b_reg[i] == 4'd1) begin
                            start_idx <= i;
                            found <= 1'b1;
                        end
                        i <= i + 8'd1;
                    end else if (found) begin
                        // Verify suffix starting from start_idx
                        if (i < 16) begin
                            // Check if b_reg[i] matches expected (i - start_idx + 1)
                            check_num <= i - start_idx + 4'd1;
                            if (b_reg[i] != (i - start_idx + 4'd1)) begin
                                // End of valid suffix
                                suffix_len <= i - start_idx;
                                check_num <= i - start_idx + 4'd1;
                                i <= 16; // Force exit
                            end else begin
                                i <= i + 8'd1;
                            end
                        end else begin
                            // Reached end of array
                            suffix_len <= 16 - start_idx;
                            check_num <= (16 - start_idx) + 4'd1;
                        end
                        
                        // If we have determined suffix_len and check_num, verify missing nums
                        if (i >= 16 || b_reg[i] != (i - start_idx + 4'd1)) begin
                            if (check_num > n_reg) begin
                                // No missing numbers, valid suffix
                                result <= n_reg - suffix_len;
                                state <= FINISHED;
                            end else begin
                                // Check if missing number 'check_num' exists in a or in b before start_idx
                                if (check_num > n_reg) begin
                                    result <= n_reg - suffix_len;
                                    state <= FINISHED;
                                end else begin
                                    // Search in a_reg
                                    found <= 1'b0;
                                    for (loop_idx = 0; loop_idx < 16; loop_idx = loop_idx + 1) begin
                                        if (a_reg[loop_idx] == check_num) begin
                                            found <= 1'b1;
                                        end
                                    end
                                    // If not in a, search in b before start_idx
                                    if (!found) begin
                                        for (loop_idx = 0; loop_idx < start_idx; loop_idx = loop_idx + 1) begin
                                            if (b_reg[loop_idx] == check_num) begin
                                                found <= 1'b1;
                                            end
                                        end
                                    end
                                    // If found, check next missing number
                                    if (found) begin
                                        check_num <= check_num + 4'd1;
                                        // Need to recheck if we've covered all
                                        if (check_num + 4'd1 > n_reg) begin
                                            result <= n_reg - suffix_len;
                                            state <= FINISHED;
                                        end
                                    end else begin
                                        // Missing number not available, go to CALC_MAX
                                        state <= CALC_MAX;
                                        i <= 8'd0;
                                        max_val <= 16'd0;
                                    end
                                end
                            end
                        end
                    end else begin
                        // Card 1 not found in pile
                        state <= CALC_MAX;
                        i <= 8'd0;
                        max_val <= 16'd0;
                    end
                end

                CALC_MAX: begin
                    // Calculate max(b[i] - i - 1) where b[i] != 0
                    if (i < 16) begin
                        if (b_reg[i] != 4'd0 && b_reg[i] > (i + 4'd1)) begin
                            temp_val <= (b_reg[i] - (i + 4'd1));
                            if ((b_reg[i] - (i + 4'd1)) > max_val) begin
                                max_val <= (b_reg[i] - (i + 4'd1));
                            end
                        end
                        i <= i + 8'd1;
                    end else begin
                        result <= n_reg + max_val;
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule