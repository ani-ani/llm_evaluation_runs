module max_element (
    input clk,
    input rst_n,
    input start,
    input [4:0] array_size,
    input [15:0] array_data [0:15],
    output reg [15:0] max_result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam COMPARE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [4:0] index, next_index;
    reg [15:0] next_max_result;
    reg next_done;

    // State Register & Synchronous Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 5'd0;
            max_result <= 16'sd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            max_result <= next_max_result;
            done <= next_done;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_index = index;
        next_max_result = max_result;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = INIT;
                    next_index = 5'd0;
                end
            end

            INIT: begin
                // Initialize with element 0
                next_max_result = array_data[0];
                
                // Check if array size is 1
                if (array_size <= 5'd1) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPARE;
                    next_index = 5'd1;
                end
            end

            COMPARE: begin
                // Compare current element with max
                if (array_data[index] > max_result) begin
                    next_max_result = array_data[index];
                end
                
                // Increment index
                next_index = index + 5'd1;
                
                // Check if finished (index reached array_size)
                if (index >= array_size - 5'd1) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule