module garbage_disposal(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] k,
    input wire [7:0] a_0,
    input wire [7:0] a_1,
    input wire [7:0] a_2,
    input wire [7:0] a_3,
    input wire [7:0] a_4,
    input wire [7:0] a_5,
    input wire [7:0] a_6,
    input wire [7:0] a_7,
    output reg [15:0] bags,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] day_count;
    reg [7:0] leftover;
    reg [7:0] current_garbage;
    reg [15:0] total_bags;
    reg [7:0] i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            day_count <= 8'd0;
            leftover <= 8'd0;
            current_garbage <= 8'd0;
            total_bags <= 16'd0;
            bags <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    day_count = 8'd0;
                    leftover = 8'd0;
                    total_bags = 16'd0;
                    done = 1'b0;
                end else begin
                    next_state = IDLE;
                end
            end

            PROCESSING: begin
                if (day_count < n) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk) begin
        if (state == PROCESSING) begin
            // Compute bags for leftover from previous day
            if (leftover > 8'd0) begin
                total_bags = total_bags + 16'd1 + ((leftover - 1'b1) / k);
            end

            // Get current day's garbage
            case (day_count)
                8'd0: current_garbage = a_0;
                8'd1: current_garbage = a_1;
                8'd2: current_garbage = a_2;
                8'd3: current_garbage = a_3;
                8'd4: current_garbage = a_4;
                8'd5: current_garbage = a_5;
                8'd6: current_garbage = a_6;
                8'd7: current_garbage = a_7;
                default: current_garbage = 8'd0;
            endcase

            // Use remaining space for today's garbage
            if (leftover > 8'd0) begin
                if (current_garbage > (k - leftover)) begin
                    current_garbage = current_garbage - (k - leftover);
                    leftover = 8'd0;
                end else begin
                    leftover = leftover + current_garbage;
                    current_garbage = 8'd0;
                end
            end

            // Compute bags for remaining current garbage
            if (current_garbage > 8'd0) begin
                total_bags = total_bags + 16'd1 + ((current_garbage - 1'b1) / k);
                leftover = current_garbage % k;
            end

            // Increment day count
            day_count = day_count + 8'd1;
        end else if (state == DONE_STATE) begin
            // Dispose any remaining leftover
            if (leftover > 8'd0) begin
                total_bags = total_bags + 16'd1;
            end
            bags = total_bags;
            done = 1'b1;
        end
    end

endmodule