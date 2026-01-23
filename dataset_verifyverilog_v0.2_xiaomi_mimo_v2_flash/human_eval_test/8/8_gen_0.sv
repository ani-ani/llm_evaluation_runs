module sum_product (
    input clk,
    input rst_n,
    input start,
    input [4:0] array_len,
    input [15:0] array_data [0:15],
    output reg [31:0] sum_out,
    output reg [31:0] product_out,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [4:0] idx, next_idx; // Index counter (0-16)
    reg [31:0] next_sum_out;
    reg [31:0] next_product_out;
    reg next_done;

    // State Register and Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 5'b0;
            sum_out <= 32'b0;
            product_out <= 32'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            idx <= next_idx;
            sum_out <= next_sum_out;
            product_out <= next_product_out;
            done <= next_done;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_idx = idx;
        next_sum_out = sum_out;
        next_product_out = product_out;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    // Special handling for empty array
                    if (array_len == 5'b0) begin
                        next_sum_out = 32'b0;
                        next_product_out = 32'b1;
                        next_state = DONE;
                        next_done = 1'b1;
                        next_idx = 5'b0;
                    end else begin
                        // Initialize computation
                        next_sum_out = {16'b0, array_data[0]}; // sum = first element
                        next_product_out = {16'b0, array_data[0]}; // product = first element
                        next_idx = 5'b1; // Start checking from index 1
                        next_state = PROCESSING;
                    end
                end
            end

            PROCESSING: begin
                if (idx < array_len) begin
                    // Continue accumulation
                    next_sum_out = sum_out + {16'b0, array_data[idx]};
                    next_product_out = product_out * {16'b0, array_data[idx]};
                    next_idx = idx + 1'b1;
                    next_state = PROCESSING;
                end else begin
                    // Iteration complete
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end

            DONE: begin
                // Hold results and done signal until reset
                next_done = 1'b1;
                // Wait for reset or potentially new start if handled (keeping sticky done per requirement)
            end

            default: begin
                next_state = IDLE;
                next_idx = 5'b0;
                next_sum_out = 32'b0;
                next_product_out = 32'b0;
                next_done = 1'b0;
            end
        endcase
    end

endmodule
