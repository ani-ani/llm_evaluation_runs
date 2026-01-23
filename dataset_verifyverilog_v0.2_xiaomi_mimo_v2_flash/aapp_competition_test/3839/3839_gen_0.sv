module knight_generator(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    output reg [31:0] x,
    output reg [31:0] y,
    output reg valid,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam GENERATE = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Internal Registers
    reg [1:0] state, next_state;
    reg [9:0] knight_counter;       // Counts from 0 to n-1
    reg [9:0] block_index;          // index / 3
    reg [1:0] pos;                  // index % 3
    reg [31:0] next_x, next_y;
    reg next_valid, next_done;

    // State Transition and Output Logic (Moore style with explicit assignments)
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_x = x;
        next_y = y;
        next_valid = 1'b0;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
                next_x = 0;
                next_y = 0;
                next_valid = 1'b0;
                next_done = 1'b0;
            end

            INIT: begin
                // Prepare first knight coordinates
                // Knight index 0: block=0, pos=0 -> (0, 0)
                next_x = 32'd0;
                next_y = 32'd0;
                next_valid = 1'b1;
                next_done = 1'b0;
                
                if (n == 10'd1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = GENERATE;
                end
            end

            GENERATE: begin
                // Logic for current knight based on current counters (pre-increment logic)
                // Current knight index is 'knight_counter'
                
                // Calculate next coordinates
                if (pos == 2'b00) begin
                    next_x = {30'b0, block_index} << 1; // 2 * block_index
                    next_y = 32'd0;
                end else if (pos == 2'b01) begin
                    next_x = ({30'b0, block_index} << 1) + 1; // 2 * block_index + 1
                    next_y = 32'd0;
                end else begin // pos == 2'b10
                    next_x = ({30'b0, block_index} << 1) + 1; // 2 * block_index + 1
                    next_y = 32'd3;
                end

                next_valid = 1'b1;
                next_done = 1'b0;

                // Determine if this was the last knight (knight_counter currently points to this knight)
                // If knight_counter + 1 == n, then this is the last one to generate
                if (knight_counter + 1 == n) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = GENERATE;
                end
            end

            DONE_STATE: begin
                next_valid = 1'b0;
                next_done = 1'b1;
                if (~start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x <= 0;
            y <= 0;
            valid <= 0;
            done <= 0;
            knight_counter <= 0;
            block_index <= 0;
            pos <= 0;
        end else begin
            state <= next_state;
            x <= next_x;
            y <= next_y;
            valid <= next_valid;
            done <= next_done;

            if (state == IDLE && start) begin
                // Reset counters on start
                knight_counter <= 0;
                block_index <= 0;
                pos <= 0;
            end else if (state == INIT) begin
                // Increment counters to prepare for next knight (index 1)
                if (n > 1) begin
                    knight_counter <= 1;
                    if (pos == 2'b10) begin
                        pos <= 2'b00;
                        block_index <= block_index + 1;
                    end else begin
                        pos <= pos + 1;
                    end
                end
            end else if (state == GENERATE) begin
                // Increment counters for the next cycle
                if (knight_counter + 1 < n) begin // Increment only if not the last one
                    knight_counter <= knight_counter + 1;
                    if (pos == 2'b10) begin
                        pos <= 2'b00;
                        block_index <= block_index + 1;
                    end else begin
                        pos <= pos + 1;
                    end
                end
            end
        end
    end

endmodule