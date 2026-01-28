module CardArranger(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] a [0:15],
    input [3:0] b [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_SORTED = 3'd1;
    localparam [2:0] CHECK_SUFFIX = 3'd2;
    localparam [2:0] CALC_MAX = 3'd3;
    localparam [2:0] FINISHED = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Internal registers for inputs
    reg [3:0] n_reg;
    reg [3:0] a_reg [0:15];
    reg [3:0] b_reg [0:15];

    // Intermediate values
    reg [15:0] max_val;
    reg [3:0] suffix_start;
    reg [3:0] suffix_length;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] current_val;
    reg [3:0] expected_val;
    reg [3:0] missing_count;
    reg [3:0] temp_val;
    reg [3:0] temp_index;
    reg [3:0] temp_card;
    reg [3:0] temp_diff;

    reg suffix_valid;
    reg all_missing_available;
    reg card_found;
    reg card_in_hand;
    reg card_in_pile;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            n_reg <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                a_reg[i] <= 4'd0;
                b_reg[i] <= 4'd0;
            end

            max_val <= 16'd0;
            suffix_start <= 4'd0;
            suffix_length <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            current_val <= 4'd0;
            expected_val <= 4'd0;
            missing_count <= 4'd0;
            temp_val <= 4'd0;
            temp_index <= 4'd0;
            temp_card <= 4'd0;
            temp_diff <= 4'd0;

            suffix_valid <= 1'b0;
            all_missing_available <= 1'b0;
            card_found <= 1'b0;
            card_in_hand <= 1'b0;
            card_in_pile <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Latch inputs
                        n_reg <= n;
                        for (i = 0; i < 16; i = i + 1) begin
                            a_reg[i] <= a[i];
                            b_reg[i] <= b[i];
                        end
                        state <= CHECK_SORTED;
                    end
                end

                CHECK_SORTED: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if pile is already sorted [1..n]
                    reg [3:0] k;
                    reg sorted;
                    sorted = 1'b1;
                    for (k = 0; k < n_reg; k = k + 1) begin
                        if (b_reg[k] != (k + 1)) begin
                            sorted = 1'b0;
                        end
                    end
                    // Check remaining cards are 0
                    for (k = n_reg; k < 16; k = k + 1) begin
                        if (b_reg[k] != 4'd0) begin
                            sorted = 1'b0;
                        end
                    end

                    if (sorted) begin
                        result <= 16'd0;
                        state <= FINISHED;
                    end else begin
                        state <= CHECK_SUFFIX;
                    end
                end

                CHECK_SUFFIX: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find index of card 1 in pile
                    suffix_start <= 4'd0;
                    suffix_valid <= 1'b0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (b_reg[i] == 4'd1) begin
                            suffix_start <= i;
                            suffix_valid <= 1'b1;
                        end
                    end

                    if (suffix_valid) begin
                        // Verify if b[suffix_start..15] is sequence 1,2,3...
                        suffix_length <= 4'd0;
                        expected_val <= 4'd1;
                        suffix_valid <= 1'b1;
                        for (i = suffix_start; i < 16; i = i + 1) begin
                            if (b_reg[i] != expected_val) begin
                                suffix_valid <= 1'b0;
                            end
                            expected_val <= expected_val + 4'd1;
                            suffix_length <= suffix_length + 4'd1;
                        end

                        if (suffix_valid) begin
                            // Check if missing numbers are available
                            all_missing_available <= 1'b1;
                            missing_count <= 4'd0;
                            for (j = 4'd1; j <= n_reg; j = j + 1) begin
                                card_found <= 1'b0;
                                // Check if j is in the suffix
                                for (i = suffix_start; i < 16; i = i + 1) begin
                                    if (b_reg[i] == j) begin
                                        card_found <= 1'b1;
                                    end
                                end

                                if (!card_found) begin
                                    // Check if j is in hand
                                    card_in_hand <= 1'b0;
                                    for (i = 0; i < 16; i = i + 1) begin
                                        if (a_reg[i] == j) begin
                                            card_in_hand <= 1'b1;
                                        end
                                    end

                                    // Check if j appears in pile before suffix_start
                                    card_in_pile <= 1'b0;
                                    for (i = 0; i < suffix_start; i = i + 1) begin
                                        if (b_reg[i] == j) begin
                                            card_in_pile <= 1'b1;
                                        end
                                    end

                                    if (!card_in_hand && !card_in_pile) begin
                                        all_missing_available <= 1'b0;
                                    end
                                    missing_count <= missing_count + 4'd1;
                                end
                            end

                            if (all_missing_available) begin
                                result <= n_reg - suffix_length;
                                state <= FINISHED;
                            end else begin
                                state <= CALC_MAX;
                            end
                        end else begin
                            state <= CALC_MAX;
                        end
                    end else begin
                        state <= CALC_MAX;
                    end
                end

                CALC_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    max_val <= 16'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (b_reg[i] != 4'd0) begin
                            temp_diff <= b_reg[i] - (i + 4'd1);
                            if (temp_diff > 4'd0 && temp_diff > max_val[3:0]) begin
                                max_val <= {12'd0, temp_diff};
                            end
                        end
                    end
                    result <= n_reg + max_val;
                    state <= FINISHED;
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
            end
        end
    end
endmodule