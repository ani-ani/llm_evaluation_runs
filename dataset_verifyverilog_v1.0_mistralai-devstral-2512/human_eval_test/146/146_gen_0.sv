module CountElements(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] nums [0:15],
    output reg [7:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] index;
    reg [7:0] temp_count;
    reg signed [15:0] abs_num;
    reg [3:0] first_digit, last_digit;
    reg first_odd, last_odd;
    reg condition_met;

    // Cycle counter to prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (index == 4'd15 || cycle_count >= MAX_CYCLES)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            count <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            index <= 4'd0;
            temp_count <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    index <= 4'd0;
                    temp_count <= 8'd0;
                end
                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Get absolute value (handle -32768 overflow)
                    if (nums[index] == 16'sd-32768)
                        abs_num <= 16'd32767;
                    else if (nums[index][15])
                        abs_num <= -nums[index];
                    else
                        abs_num <= nums[index];

                    // Extract digits
                    if (abs_num > 16'd9) begin
                        first_digit <= abs_num / 16'd10 % 16'd10;
                        last_digit <= abs_num % 16'd10;
                    end else begin
                        first_digit <= 4'd0;
                        last_digit <= abs_num;
                    end

                    // Check if digits are odd
                    first_odd <= (first_digit & 1'b1);
                    last_odd <= (last_digit & 1'b1);

                    // Check conditions
                    condition_met <= (nums[index] > 16'd10) && first_odd && last_odd;

                    // Update count if condition met
                    if (condition_met)
                        temp_count <= temp_count + 8'd1;

                    // Move to next element
                    index <= index + 4'd1;
                end
                DONE_STATE: begin
                    count <= temp_count;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule