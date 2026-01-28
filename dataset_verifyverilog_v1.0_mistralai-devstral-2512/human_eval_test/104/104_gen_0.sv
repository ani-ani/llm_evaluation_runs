module FilterNoEvenDigits(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_0,
    input wire [7:0] input_1,
    input wire [7:0] input_2,
    input wire [7:0] input_3,
    input wire [7:0] input_4,
    input wire [7:0] input_5,
    input wire [7:0] input_6,
    input wire [7:0] input_7,
    input wire [3:0] input_len,
    output reg [7:0] output_0,
    output reg [7:0] output_1,
    output reg [7:0] output_2,
    output reg [7:0] output_3,
    output reg [7:0] output_4,
    output reg [7:0] output_5,
    output reg [7:0] output_6,
    output reg [7:0] output_7,
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_DIGITS = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Input array storage
    reg [7:0] input_array [0:7];
    reg [3:0] current_input_idx;
    reg [7:0] current_number;
    reg has_even_digit;

    // Filtered array storage
    reg [7:0] filtered_array [0:7];
    reg [3:0] filtered_count;

    // Sorting variables
    reg [7:0] temp_array [0:7];
    reg [3:0] sort_i, sort_j;
    reg [7:0] temp_val;

    // Digit checking variables
    reg [7:0] num_to_check;
    reg [7:0] digit;
    reg [3:0] digit_idx;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_input_idx <= 4'd0;
            current_number <= 8'd0;
            has_even_digit <= 1'b0;
            filtered_count <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            temp_val <= 8'd0;
            num_to_check <= 8'd0;
            digit <= 8'd0;
            digit_idx <= 4'd0;

            // Initialize input array
            input_array[0] <= 8'd0;
            input_array[1] <= 8'd0;
            input_array[2] <= 8'd0;
            input_array[3] <= 8'd0;
            input_array[4] <= 8'd0;
            input_array[5] <= 8'd0;
            input_array[6] <= 8'd0;
            input_array[7] <= 8'd0;

            // Initialize filtered array
            filtered_array[0] <= 8'd0;
            filtered_array[1] <= 8'd0;
            filtered_array[2] <= 8'd0;
            filtered_array[3] <= 8'd0;
            filtered_array[4] <= 8'd0;
            filtered_array[5] <= 8'd0;
            filtered_array[6] <= 8'd0;
            filtered_array[7] <= 8'd0;

            // Initialize temp array
            temp_array[0] <= 8'd0;
            temp_array[1] <= 8'd0;
            temp_array[2] <= 8'd0;
            temp_array[3] <= 8'd0;
            temp_array[4] <= 8'd0;
            temp_array[5] <= 8'd0;
            temp_array[6] <= 8'd0;
            temp_array[7] <= 8'd0;

            // Initialize outputs
            output_0 <= 8'd0;
            output_1 <= 8'd0;
            output_2 <= 8'd0;
            output_3 <= 8'd0;
            output_4 <= 8'd0;
            output_5 <= 8'd0;
            output_6 <= 8'd0;
            output_7 <= 8'd0;
            output_len <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            // Update cycle counter
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
            end

            // State machine logic
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Store inputs
                        input_array[0] <= input_0;
                        input_array[1] <= input_1;
                        input_array[2] <= input_2;
                        input_array[3] <= input_3;
                        input_array[4] <= input_4;
                        input_array[5] <= input_5;
                        input_array[6] <= input_6;
                        input_array[7] <= input_7;
                        next_state <= CHECK_DIGITS;
                        current_input_idx <= 4'd0;
                        filtered_count <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_DIGITS: begin
                    // Process each input number
                    if (current_input_idx < input_len) begin
                        current_number <= input_array[current_input_idx];
                        num_to_check <= current_number;
                        digit_idx <= 4'd0;
                        has_even_digit <= 1'b0;

                        // Check all digits
                        if (num_to_check == 8'd0) begin
                            has_even_digit <= 1'b1;
                        end else begin
                            // Extract and check each digit
                            digit <= num_to_check % 10;
                            if (digit == 8'd0 || digit[0] == 1'b0) begin
                                has_even_digit <= 1'b1;
                            end
                            num_to_check <= num_to_check / 10;
                            digit_idx <= digit_idx + 4'd1;

                            // If we've checked all digits and none are even
                            if (num_to_check == 8'd0 && !has_even_digit && digit_idx > 4'd0) begin
                                // Add to filtered array
                                filtered_array[filtered_count] <= current_number;
                                filtered_count <= filtered_count + 4'd1;
                            end
                        end

                        // Move to next input
                        if (num_to_check == 8'd0) begin
                            current_input_idx <= current_input_idx + 4'd1;
                        end
                    end else begin
                        // Copy filtered array to temp array for sorting
                        temp_array[0] <= filtered_array[0];
                        temp_array[1] <= filtered_array[1];
                        temp_array[2] <= filtered_array[2];
                        temp_array[3] <= filtered_array[3];
                        temp_array[4] <= filtered_array[4];
                        temp_array[5] <= filtered_array[5];
                        temp_array[6] <= filtered_array[6];
                        temp_array[7] <= filtered_array[7];
                        next_state <= SORT;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                    end
                end

                SORT: begin
                    // Bubble sort implementation
                    if (sort_i < filtered_count - 4'd1) begin
                        if (sort_j < filtered_count - sort_i - 4'd1) begin
                            if (temp_array[sort_j] > temp_array[sort_j + 4'd1]) begin
                                temp_val <= temp_array[sort_j];
                                temp_array[sort_j] <= temp_array[sort_j + 4'd1];
                                temp_array[sort_j + 4'd1] <= temp_val;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        // Copy sorted array to outputs
                        output_0 <= temp_array[0];
                        output_1 <= temp_array[1];
                        output_2 <= temp_array[2];
                        output_3 <= temp_array[3];
                        output_4 <= temp_array[4];
                        output_5 <= temp_array[5];
                        output_6 <= temp_array[6];
                        output_7 <= temp_array[7];
                        output_len <= filtered_count;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
            end
        end
    end

endmodule