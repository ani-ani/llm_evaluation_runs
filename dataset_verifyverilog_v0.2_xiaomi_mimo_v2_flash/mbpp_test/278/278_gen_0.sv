module count_first_elements (
    input clk,
    input rst_n,
    input start,
    input [7:0][1:0] data_types,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] count, next_count;
    reg [3:0] index, next_index;
    reg done_reg, next_done;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'b0;
            index <= 4'b0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            index <= next_index;
            done_reg <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        next_index = index;
        next_done = done_reg;

        case (state)
            IDLE: begin
                next_count = 4'b0;
                next_index = 4'b0;
                next_done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                if (index < 8) begin
                    // Check current element: 00=scalar, 01=tuple
                    if (data_types[index] == 2'b01) begin
                        // Found tuple, go to DONE
                        next_state = DONE;
                        next_done = 1'b1;
                    end else begin
                        // Scalar, increment count and index
                        next_count = count + 1;
                        next_index = index + 1;
                        // If we just processed the last element (index becomes 8), go to DONE
                        if (index == 4'h7) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end
                    end
                end else begin
                    // Should not reach here in normal operation, but safeguard
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end

            DONE: begin
                // Hold state and outputs until reset or next start
                // We stay in DONE until reset or external logic handles it
                // According to spec, behavior for transition out isn't defined, 
                // typically we wait for reset or a new sequence.
                // If start is asserted again while in DONE, we might need to restart.
                // But usually, IDLE waits for start. If we are in DONE, we stay here.
                // Let's assume we stay in DONE until reset.
                // However, to allow re-triggering if needed (though not explicitly stated),
                // we can check if start is high? No, spec says IDLE waits for start.
                // So we assume we stay here.
                next_done = 1'b1;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(*) begin
        if (state == DONE) begin
            result = count;
            done = 1'b1;
        end else if (state == PROCESSING) begin
            result = count; // Show current count
            done = 1'b0;
        end else begin // IDLE
            result = 4'b0;
            done = 1'b0;
        end
    end

endmodule