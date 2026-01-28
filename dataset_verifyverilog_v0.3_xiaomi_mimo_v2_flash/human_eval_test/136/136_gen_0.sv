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

    reg [1:0] state, next_state;
    reg [2:0] index;
    reg signed [15:0] max_neg;
    reg signed [15:0] min_pos;
    reg [2:0] counter;

    // Sentinel value 0x8000 (-32768)
    localparam signed [15:0] SENTINEL = 16'sh8000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            largest_neg <= SENTINEL;
            smallest_pos <= SENTINEL;
            done <= 1'b0;
            index <= 3'd0;
            max_neg <= SENTINEL;
            min_pos <= SENTINEL;
            counter <= 3'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    counter <= 3'd0;
                    max_neg <= SENTINEL;
                    min_pos <= SENTINEL;
                    largest_neg <= SENTINEL;
                    smallest_pos <= SENTINEL;
                end

                PROCESSING: begin
                    if (counter < len) begin
                        // Process element arr[index]
                        if (arr[index] < 0) begin
                            // Negative number: check if larger than current max_neg
                            if (arr[index] > max_neg) begin
                                max_neg <= arr[index];
                            end
                        end else if (arr[index] > 0) begin
                            // Positive number: check if smaller than current min_pos
                            if (arr[index] < min_pos) begin
                                min_pos <= arr[index];
                            end
                        end
                        // If arr[index] == 0, we ignore it (0 is neither positive nor negative)
                        
                        index <= index + 3'd1;
                        counter <= counter + 3'd1;
                    end
                end

                DONE_STATE: begin
                    largest_neg <= max_neg;
                    smallest_pos <= min_pos;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                if (counter >= len) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESSING;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule