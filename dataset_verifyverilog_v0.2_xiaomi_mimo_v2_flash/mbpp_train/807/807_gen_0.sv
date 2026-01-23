module first_odd_finder (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input [2:0] list_size,
    input valid_in,
    output reg [7:0] first_odd,
    output reg found,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam CHECKING = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state, next_state;
    reg [2:0] counter, next_counter; // counts how many numbers processed
    reg [7:0] next_first_odd;
    reg next_found;
    reg next_done;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            counter <= 3'b0;
            first_odd <= 8'b0;
            found <= 1'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            counter <= next_counter;
            first_odd <= next_first_odd;
            found <= next_found;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = current_state;
        next_counter = counter;
        next_first_odd = first_odd;
        next_found = found;
        next_done = done;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_counter = 3'b0;
                    next_done = 1'b0;
                    next_found = 1'b0;
                    next_first_odd = 8'b0;
                end
            end

            PROCESSING: begin
                if (valid_in) begin
                    next_state = CHECKING;
                end
            end

            CHECKING: begin
                // Check if data_in is odd (LSB is 1)
                if (data_in[0]) begin
                    // Odd number found
                    next_first_odd = data_in;
                    next_found = 1'b1;
                    next_state = DONE;
                end else begin
                    // Not odd, increment counter
                    next_counter = counter + 1'b1;
                    
                    // Check if we have processed all elements
                    if (next_counter >= list_size) begin
                        // Finished list, no odd found
                        next_first_odd = 8'hFF;
                        next_found = 1'b0;
                        next_state = DONE;
                    end else begin
                        // Continue processing
                        next_state = PROCESSING;
                    end
                end
            end

            DONE: begin
                // Wait in DONE state until reset
                // Keep done signal high
                next_done = 1'b1;
                if (!rst_n) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
                next_counter = 3'b0;
                next_first_odd = 8'b0;
                next_found = 1'b0;
                next_done = 1'b0;
            end
        endcase
    end

endmodule