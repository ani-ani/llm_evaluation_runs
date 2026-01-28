module pack_consecutive_duplicates(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] len,
    input wire [7:0] arr [0:15],
    output reg [7:0] result,
    output reg done,
    output reg result_valid,
    output reg result_is_group_start
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] RESET_BUFFER   = 3'd1;
    localparam [2:0] READ_INPUT     = 3'd2;
    localparam [2:0] COMPARE        = 3'd3;
    localparam [2:0] FLUSH_BUFFER   = 3'd4;
    localparam [2:0] PROCESS_NEW_GROUP = 3'd5;
    localparam [2:0] DONE           = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] input_ptr;
    reg [4:0] buffer_ptr;
    reg [4:0] flush_ptr;
    reg [7:0] prev_value;
    reg [7:0] buffer [0:15];
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;  // Safe limit

    // Integer for loop
    integer i;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? RESET_BUFFER : IDLE;
            RESET_BUFFER: next_state = READ_INPUT;
            READ_INPUT: next_state = COMPARE;
            COMPARE: begin
                if (buffer_ptr == 5'd0) begin
                    next_state = PROCESS_NEW_GROUP;
                end else if (arr[input_ptr] == prev_value) begin
                    next_state = PROCESS_NEW_GROUP;
                end else begin
                    next_state = FLUSH_BUFFER;
                end
            end
            FLUSH_BUFFER: begin
                if (flush_ptr == 5'd1) begin
                    next_state = (input_ptr == len) ? DONE : PROCESS_NEW_GROUP;
                end else begin
                    next_state = FLUSH_BUFFER;
                end
            end
            PROCESS_NEW_GROUP: begin
                if (input_ptr == len) begin
                    next_state = FLUSH_BUFFER;
                end else begin
                    next_state = READ_INPUT;
                end
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State register and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_ptr <= 5'd0;
            buffer_ptr <= 5'd0;
            flush_ptr <= 5'd0;
            prev_value <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            result_is_group_start <= 1'b0;
            cycle_count <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                buffer[i] <= 8'd0;
            end
        end else begin
            // Default outputs
            done <= 1'b0;
            result_valid <= 1'b0;
            result_is_group_start <= 1'b0;
            
            // Cycle counter
            if (state == IDLE) begin
                cycle_count <= 5'd0;
            end else if (state != next_state) begin
                cycle_count <= cycle_count + 5'd1;
            end

            state <= next_state;

            case (state)
                IDLE: begin
                    // Wait for start
                    input_ptr <= 5'd0;
                    buffer_ptr <= 5'd0;
                    flush_ptr <= 5'd0;
                end

                RESET_BUFFER: begin
                    buffer_ptr <= 5'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        buffer[i] <= 8'd0;
                    end
                end

                READ_INPUT: begin
                    // Input already available on arr
                end

                COMPARE: begin
                    if (buffer_ptr == 5'd0) begin
                        // First element of group
                        buffer[0] <= arr[input_ptr];
                        buffer_ptr <= 5'd1;
                        prev_value <= arr[input_ptr];
                        result <= arr[input_ptr];
                        result_valid <= 1'b1;
                        result_is_group_start <= 1'b1;
                        input_ptr <= input_ptr + 5'd1;
                    end else if (arr[input_ptr] == prev_value) begin
                        // Same as previous - add to buffer
                        buffer[buffer_ptr] <= arr[input_ptr];
                        buffer_ptr <= buffer_ptr + 5'd1;
                        result <= arr[input_ptr];
                        result_valid <= 1'b1;
                        result_is_group_start <= 1'b0;
                        input_ptr <= input_ptr + 5'd1;
                    end else begin
                        // Different - will flush in next state
                    end
                end

                FLUSH_BUFFER: begin
                    if (flush_ptr == 5'd0) begin
                        // Start flushing from index 1 (skip first, already output)
                        flush_ptr <= 5'd1;
                    end else if (flush_ptr < buffer_ptr) begin
                        result <= buffer[flush_ptr];
                        result_valid <= 1'b1;
                        result_is_group_start <= 1'b0;
                        flush_ptr <= flush_ptr + 5'd1;
                    end else if (flush_ptr == buffer_ptr) begin
                        // Done flushing
                        buffer_ptr <= 5'd0;
                        flush_ptr <= 5'd0;
                    end
                end

                PROCESS_NEW_GROUP: begin
                    // Start new group with current value
                    buffer[0] <= arr[input_ptr];
                    buffer_ptr <= 5'd1;
                    prev_value <= arr[input_ptr];
                    result <= arr[input_ptr];
                    result_valid <= 1'b1;
                    result_is_group_start <= 1'b1;
                    input_ptr <= input_ptr + 5'd1;
                end

                DONE: begin
                    done <= 1'b1;
                    input_ptr <= 5'd0;
                    buffer_ptr <= 5'd0;
                    flush_ptr <= 5'd0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE;
            end
        end
    end

endmodule