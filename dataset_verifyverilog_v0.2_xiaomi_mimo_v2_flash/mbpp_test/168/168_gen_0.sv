module frequency_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] target,
    input [7:0] list [0:7],
    output reg [3:0] count,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] index, next_index; // 3 bits to count 0-7
    reg [3:0] next_count;
    reg next_done;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'b0;
            count <= 4'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            count <= next_count;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_index = index;
        next_count = count;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    next_index = 3'b0;
                    next_count = 4'b0;
                end else begin
                    next_index = 3'b0;
                    next_count = 4'b0;
                end
            end

            PROCESSING: begin
                // Compare current element
                if (list[index] == target) begin
                    next_count = count + 1'b1;
                end else begin
                    next_count = count;
                end

                // Increment index
                next_index = index + 1'b1;

                // Check if finished (index goes from 0 to 7, so 8 cycles total)
                if (index == 3'b111) begin // 3'b111 is 7
                    next_state = DONE;
                    next_done = 1'b1;
                end else begin
                    next_state = PROCESSING;
                    next_done = 1'b0;
                end
            end

            DONE: begin
                next_done = 1'b1;
                if (start) begin
                    // Restart if start is held high or reasserted
                    next_state = PROCESSING;
                    next_index = 3'b0;
                    next_count = 4'b0;
                    next_done = 1'b0;
                end else begin
                    // Stay in DONE until reset or restart
                    // If user wants to hold 'done' high until next start, this works.
                    // If user wants to pulse 'done', logic would differ.
                    // Based on description "High when computation is complete", holding is valid.
                    // To reset to IDLE behavior explicitly: 
                    // next_state = IDLE; next_done = 1'b0; if (start) ...
                    // Let's stick to waiting for reset or restart.
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end

            default: begin
                next_state = IDLE;
                next_index = 3'b0;
                next_count = 4'b0;
                next_done = 1'b0;
            end
        endcase
    end

endmodule