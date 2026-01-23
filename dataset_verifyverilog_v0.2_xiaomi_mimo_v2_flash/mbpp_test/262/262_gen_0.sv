module array_splitter (
    input clk,
    input rst_n,
    input start,
    input [SIZE-1:0][WIDTH-1:0] data_in,
    input [4:0] L,
    output reg [SIZE-1:0][WIDTH-1:0] part1,
    output reg [SIZE-1:0][WIDTH-1:0] part2,
    output reg done
);

parameter SIZE = 16;
parameter WIDTH = 8;

// State encoding
localparam IDLE = 2'b00;
localparam LOAD = 2'b01;
localparam PROCESS = 2'b10;
localparam DONE_STATE = 2'b11;

reg [1:0] current_state, next_state;
reg [3:0] count, next_count; // Counter for 16 elements (0-15)
reg [SIZE-1:0][WIDTH-1:0] internal_buffer, next_internal_buffer;
reg [SIZE-1:0][WIDTH-1:0] next_part1, next_part2;
reg next_done;

// State transition and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        count <= 4'd0;
        part1 <= {SIZE{8'b0}};
        part2 <= {SIZE{8'b0}};
        done <= 1'b0;
        internal_buffer <= {SIZE{8'b0}};
    end else begin
        current_state <= next_state;
        count <= next_count;
        part1 <= next_part1;
        part2 <= next_part2;
        done <= next_done;
        internal_buffer <= next_internal_buffer;
    end
end

// Next state logic
always @(*) begin
    // Default assignments
    next_state = current_state;
    next_count = count;
    next_part1 = part1;
    next_part2 = part2;
    next_done = 1'b0;
    next_internal_buffer = internal_buffer;

    case (current_state)
        IDLE: begin
            next_count = 4'd0;
            next_done = 1'b0;
            if (start) begin
                next_state = LOAD;
                // Capture input data immediately
                next_internal_buffer = data_in;
            end
        end

        LOAD: begin
            // Prepare for processing, initialize outputs with padding
            next_part1 = {SIZE{8'b0}};
            next_part2 = {SIZE{8'b0}};
            next_count = 4'd0;
            next_state = PROCESS;
        end

        PROCESS: begin
            // Simulating unrolled logic via state machine
            // We process one element per clock cycle

            // Logic for part1 (indices 0 to L-1)
            if (count < L) begin
                next_part1[count] = internal_buffer[count];
            end

            // Logic for part2 (indices L to 15)
            // Map internal_buffer index 'count' to part2 index 'count'
            // Valid only if (count >= L)
            if (count >= L) begin
                next_part2[count] = internal_buffer[count];
            end

            // Increment counter
            next_count = count + 1;

            // Check for completion
            if (count == 4'd15) begin
                next_state = DONE_STATE;
            end
        end

        DONE_STATE: begin
            next_done = 1'b1;
            if (!start) begin
                next_state = IDLE;
            end
        end

        default: next_state = IDLE;
    endcase
end

endmodule