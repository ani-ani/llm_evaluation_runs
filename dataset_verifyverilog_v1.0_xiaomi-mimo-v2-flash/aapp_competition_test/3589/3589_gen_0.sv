module ProductDigitCounter (
    input clk,
    input rst_n,
    input start,
    input [15:0] L,
    input [15:0] R,
    output reg [15:0] count [0:8],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CALCULATE_R  = 3'd1;
    localparam [2:0] CALCULATE_L  = 3'd2;
    localparam [2:0] COMPUTE_R    = 3'd3;
    localparam [2:0] COMPUTE_L    = 3'd4;
    localparam [2:0] SUBTRACT     = 3'd5;
    localparam [2:0] FINISH       = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] counter;
    reg [15:0] current_num;
    reg [31:0] product;
    reg [3:0] digit;
    reg [3:0] digit_idx;
    reg [3:0] num_digits;
    reg [15:0] temp_count [0:8];
    reg [15:0] count_R [0:8];
    reg [15:0] count_L [0:8];
    reg [15:0] result_count [0:8];
    reg [15:0] final_num;
    reg [3:0] sub_state;
    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 8'd0;
            current_num <= 16'd0;
            product <= 32'd0;
            digit <= 4'd0;
            digit_idx <= 4'd0;
            num_digits <= 4'd0;
            final_num <= 16'd0;
            sub_state <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 9; i = i + 1) begin
                count[i] <= 16'd0;
                temp_count[i] <= 16'd0;
                count_R[i] <= 16'd0;
                count_L[i] <= 16'd0;
                result_count[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 8'd0;
                    current_num <= 16'd0;
                    product <= 32'd0;
                    digit <= 4'd0;
                    digit_idx <= 4'd0;
                    num_digits <= 4'd0;
                    final_num <= 16'd0;
                    sub_state <= 4'd0;
                    for (i = 0; i < 9; i = i + 1) begin
                        count[i] <= 16'd0;
                        temp_count[i] <= 16'd0;
                        count_R[i] <= 16'd0;
                        count_L[i] <= 16'd0;
                        result_count[i] <= 16'd0;
                    end
                end

                CALCULATE_R: begin
                    if (counter == 8'd0) begin
                        temp_count[0] <= 16'd0;
                        for (i = 1; i < 9; i = i + 1) begin
                            temp_count[i] <= 16'd0;
                        end
                        counter <= 8'd1;
                        current_num <= 16'd0;
                    end else begin
                        if (current_num <= R) begin
                            // Calculate digit product for current_num
                            if (current_num == 16'd0) begin
                                // 0 produces 0, skip
                                current_num <= current_num + 16'd1;
                            end else begin
                                product <= 32'd1;
                                final_num <= current_num;
                                sub_state <= 4'd0;
                            end
                        end else begin
                            for (i = 0; i < 9; i = i + 1) begin
                                count_R[i] <= temp_count[i];
                            end
                            counter <= 8'd0;
                        end
                    end
                    // Inner computation for product
                    if (sub_state == 4'd0 && current_num <= R && current_num != 16'd0) begin
                        if (final_num > 16'd9) begin
                            digit <= final_num % 10;
                            if ((final_num % 10) != 0) begin
                                product <= product * (final_num % 10);
                            end
                            final_num <= final_num / 10;
                        end else begin
                            digit <= final_num;
                            if (final_num != 0) begin
                                product <= product * final_num;
                            end
                            sub_state <= 4'd1;
                        end
                    end else if (sub_state == 4'd1) begin
                        // Now product contains result for current_num (if product <= 9)
                        if (product >= 16'd1 && product <= 16'd9) begin
                            temp_count[product - 16'd1] <= temp_count[product - 16'd1] + 16'd1;
                        end else if (product >= 16'd10) begin
                            // Need to reduce further, restart with product
                            final_num <= product[15:0];
                            product <= 32'd1;
                            sub_state <= 4'd0;
                        end else begin
                            // product became 0
                            current_num <= current_num + 16'd1;
                            sub_state <= 4'd0;
                        end
                    end else if (sub_state == 4'd1 && product < 16'd10 && product >= 16'd1) begin
                        current_num <= current_num + 16'd1;
                        sub_state <= 4'd0;
                    end
                end

                CALCULATE_L: begin
                    if (counter == 8'd0) begin
                        temp_count[0] <= 16'd0;
                        for (i = 1; i < 9; i = i + 1) begin
                            temp_count[i] <= 16'd0;
                        end
                        counter <= 8'd1;
                        current_num <= 16'd0;
                    end else begin
                        if (current_num < L) begin
                            // Calculate digit product for current_num
                            if (current_num == 16'd0) begin
                                current_num <= current_num + 16'd1;
                            end else begin
                                product <= 32'd1;
                                final_num <= current_num;
                                sub_state <= 4'd0;
                            end
                        end else begin
                            for (i = 0; i < 9; i = i + 1) begin
                                count_L[i] <= temp_count[i];
                            end
                            counter <= 8'd0;
                        end
                    end
                    // Inner computation for product (same as CALCULATE_R)
                    if (sub_state == 4'd0 && current_num < L && current_num != 16'd0) begin
                        if (final_num > 16'd9) begin
                            digit <= final_num % 10;
                            if ((final_num % 10) != 0) begin
                                product <= product * (final_num % 10);
                            end
                            final_num <= final_num / 10;
                        end else begin
                            digit <= final_num;
                            if (final_num != 0) begin
                                product <= product * final_num;
                            end
                            sub_state <= 4'd1;
                        end
                    end else if (sub_state == 4'd1) begin
                        if (product >= 16'd1 && product <= 16'd9) begin
                            temp_count[product - 16'd1] <= temp_count[product - 16'd1] + 16'd1;
                        end else if (product >= 16'd10) begin
                            final_num <= product[15:0];
                            product <= 32'd1;
                            sub_state <= 4'd0;
                        end else begin
                            current_num <= current_num + 16'd1;
                            sub_state <= 4'd0;
                        end
                    end else if (sub_state == 4'd1 && product < 16'd10 && product >= 16'd1) begin
                        current_num <= current_num + 16'd1;
                        sub_state <= 4'd0;
                    end
                end

                SUBTRACT: begin
                    for (i = 0; i < 9; i = i + 1) begin
                        if (count_R[i] >= count_L[i]) begin
                            result_count[i] <= count_R[i] - count_L[i];
                        end else begin
                            result_count[i] <= 16'd0;
                        end
                    end
                end

                FINISH: begin
                    for (i = 0; i < 9; i = i + 1) begin
                        count[i] <= result_count[i];
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATE_R;
                end
            end

            CALCULATE_R: begin
                if (counter == 8'd1 && current_num > R) begin
                    if (sub_state == 4'd0 || (sub_state == 4'd1 && (product < 16'd10 || product >= 16'd10))) begin
                        next_state = CALCULATE_L;
                    end
                end
            end

            CALCULATE_L: begin
                if (counter == 8'd1 && current_num >= L) begin
                    if (sub_state == 4'd0 || (sub_state == 4'd1 && (product < 16'd10 || product >= 16'd10))) begin
                        next_state = SUBTRACT;
                    end
                end
            end

            SUBTRACT: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule