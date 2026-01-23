module special_filter(
    input clk,
    input rst_n,
    input start,
    input [2:0] len,
    input signed [7:0] arr [0:7],
    output reg [3:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_ARRAY_SIZE = 4'd8;
    localparam [7:0] DATA_WIDTH = 8'd8;
    localparam [3:0] RESULT_WIDTH = 4'd4;
    localparam [7:0] GT_10_THRESHOLD = 8'd10;

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] ABS         = 4'd1;
    localparam [3:0] CHECK_GT10  = 4'd2;
    localparam [3:0] GET_LAST    = 4'd3;
    localparam [3:0] GET_FIRST   = 4'd4;
    localparam [3:0] CHECK_ODD   = 4'd5;
    localparam [3:0] INCREMENT   = 4'd6;
    localparam [3:0] NEXT        = 4'd7;
    localparam [3:0] DONE_STATE  = 4'd8;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] index;
    reg signed [7:0] current_val;
    reg [7:0] abs_val;
    reg [7:0] last_digit;
    reg [7:0] first_digit;
    reg [3:0] temp_counter;
    reg [7:0] first_digit_temp;
    reg [2:0] loop_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = ABS;
                else
                    next_state = IDLE;
            end
            ABS: next_state = CHECK_GT10;
            CHECK_GT10: begin
                if (abs_val > GT_10_THRESHOLD)
                    next_state = GET_LAST;
                else
                    next_state = NEXT;
            end
            GET_LAST: next_state = GET_FIRST;
            GET_FIRST: begin
                if (first_digit_temp < 10)
                    next_state = CHECK_ODD;
                else
                    next_state = GET_FIRST;
            end
            CHECK_ODD: begin
                if (last_digit[0] && first_digit[0])
                    next_state = INCREMENT;
                else
                    next_state = NEXT;
            end
            INCREMENT: next_state = NEXT;
            NEXT: begin
                if (index >= len)
                    next_state = DONE_STATE;
                else
                    next_state = ABS;
            end
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 4'd0;
            current_val <= 8'sd0;
            abs_val <= 8'd0;
            last_digit <= 8'd0;
            first_digit <= 8'd0;
            first_digit_temp <= 8'd0;
            temp_counter <= 4'd0;
            loop_counter <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 4'd0;
                    index <= 4'd0;
                    cycle_count <= 8'd0;
                    temp_counter <= 4'd0;
                end

                ABS: begin
                    current_val <= arr[index];
                    // Take absolute value (two's complement)
                    if (arr[index][7])
                        abs_val <= -arr[index];
                    else
                        abs_val <= arr[index];
                end

                CHECK_GT10: begin
                    // Already checked in transition, just pass through
                end

                GET_LAST: begin
                    // last_digit = abs_val % 10
                    last_digit <= abs_val % 10;
                    first_digit_temp <= abs_val;
                    loop_counter <= 3'd0;
                end

                GET_FIRST: begin
                    // Divide by 10 repeatedly until < 10
                    if (first_digit_temp >= 10) begin
                        first_digit_temp <= first_digit_temp / 10;
                        loop_counter <= loop_counter + 3'd1;
                    end
                    // Store final result when < 10
                    if (first_digit_temp < 10)
                        first_digit <= first_digit_temp;
                end

                CHECK_ODD: begin
                    // Check if both are odd (bit 0 = 1)
                    // Already checked in transition
                end

                INCREMENT: begin
                    temp_counter <= temp_counter + 4'd1;
                end

                NEXT: begin
                    index <= index + 4'd1;
                end

                DONE_STATE: begin
                    result <= temp_counter;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Update state
            state <= next_state;
        end
    end

endmodule