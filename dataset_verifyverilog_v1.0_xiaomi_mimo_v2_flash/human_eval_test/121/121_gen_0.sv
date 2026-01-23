module sum_odd_even_pos (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index, next_index;           // Counter from 0 to 7
    reg [15:0] accumulator, next_accum;    // Running sum
    reg [7:0] current_element;             // Registered array element
    reg is_even_index, is_odd_value;       // Combinational flags

    // Combinational logic for conditions
    always @(*) begin
        is_even_index = (index[0] == 1'b0);  // Even index: 0, 2, 4, 6
        is_odd_value = (current_element[0] == 1'b1);  // Odd value
    end

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            current_element <= 8'd0;
        end else begin
            state <= next_state;
            index <= next_index;
            accumulator <= next_accum;
            // Capture array element based on current index (simplified for synthesis)
            // Note: In real hardware, we'd use a mux or register the entire array
            // For Icarus compatibility, we'll handle this in the state machine logic
        end
    end

    // Next state logic
    always @(*) begin
        // Default values
        next_state = state;
        next_index = index;
        next_accum = accumulator;
        result = result;
        done = 1'b0;

        case (state)
            IDLE: begin
                next_index = 4'd0;
                next_accum = 16'd0;
                done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    // Initialize with element 0
                    current_element = arr[0];
                end
            end

            PROCESSING: begin
                // Get current element
                current_element = arr[index];
                
                // Check conditions and accumulate
                if (is_even_index && is_odd_value) begin
                    next_accum = accumulator + {8'd0, current_element};
                end else begin
                    next_accum = accumulator;
                end

                // Increment index
                next_index = index + 4'd1;

                // Check if done processing all elements
                if (index == 4'd7) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESSING;
                end
            end

            DONE_STATE: begin
                result = accumulator;  // Assign result
                done = 1'b1;
                next_state = IDLE;
                next_index = 4'd0;
                next_accum = 16'd0;
            end

            default: begin
                next_state = IDLE;
                next_index = 4'd0;
                next_accum = 16'd0;
            end
        endcase
    end

endmodule