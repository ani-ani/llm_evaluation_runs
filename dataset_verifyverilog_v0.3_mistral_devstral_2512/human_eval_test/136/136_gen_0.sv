module extrema_finder(
    input clk,
    input rst_n,
    input start,
    input [2:0] len,
    input signed [15:0] arr [0:7],
    output reg signed [15:0] largest_neg,
    output reg signed [15:0] smallest_pos,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] index;
    reg signed [15:0] max_neg;
    reg signed [15:0] min_pos;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

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
                if (index == len - 1 || cycle_count >= MAX_CYCLES)
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

    // State register and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 3'd0;
            max_neg <= 16'sh8000;
            min_pos <= 16'sh8000;
            largest_neg <= 16'sh8000;
            smallest_pos <= 16'sh8000;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    index <= 3'd0;
                    max_neg <= 16'sh8000;
                    min_pos <= 16'sh8000;
                    cycle_count <= 8'd0;
                end
                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Process current element
                    if (arr[index] < 16'sd0 && arr[index] > max_neg)
                        max_neg <= arr[index];
                    if (arr[index] > 16'sd0 && (min_pos == 16'sh8000 || arr[index] < min_pos))
                        min_pos <= arr[index];

                    // Move to next index
                    if (index < len - 1)
                        index <= index + 3'd1;
                end
                DONE_STATE: begin
                    largest_neg <= max_neg;
                    smallest_pos <= min_pos;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    index <= 3'd0;
                    max_neg <= 16'sh8000;
                    min_pos <= 16'sh8000;
                    largest_neg <= 16'sh8000;
                    smallest_pos <= 16'sh8000;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule