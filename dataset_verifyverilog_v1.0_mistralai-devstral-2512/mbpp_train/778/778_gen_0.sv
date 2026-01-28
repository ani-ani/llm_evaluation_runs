module pack_duplicates(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RESET_BUFFER = 3'd1;
    localparam [2:0] READ_INPUT = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] FLUSH_BUFFER = 3'd4;
    localparam [2:0] PROCESS_NEW_GROUP = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal signals
    reg [2:0] state, next_state;
    reg [7:0] buffer [0:15];
    reg [4:0] buffer_ptr;
    reg [7:0] prev_value;
    reg [4:0] input_ptr;
    reg [4:0] flush_ptr;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            result_is_group_start <= 1'b0;
            input_ptr <= 5'd0;
            buffer_ptr <= 5'd0;
            flush_ptr <= 5'd0;
            prev_value <= 8'd0;
            cycle_count <= 8'd0;
            // Initialize buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            result_valid <= 1'b0;
            result_is_group_start <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= RESET_BUFFER;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                RESET_BUFFER: begin
                    input_ptr <= 5'd0;
                    buffer_ptr <= 5'd0;
                    flush_ptr <= 5'd0;
                    prev_value <= 8'd0;
                    cycle_count <= 8'd0;
                    // Clear buffer
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        buffer[i] <= 8'd0;
                    end
                    next_state <= READ_INPUT;
                end

                READ_INPUT: begin
                    if (input_ptr < len) begin
                        next_state <= COMPARE;
                    end else begin
                        next_state <= FLUSH_BUFFER;
                    end
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
                        next_state <= READ_INPUT;
                    end else if (arr[input_ptr] == prev_value) begin
                        // Same as previous, add to buffer
                        buffer[buffer_ptr] <= arr[input_ptr];
                        buffer_ptr <= buffer_ptr + 5'd1;
                        result <= arr[input_ptr];
                        result_valid <= 1'b1;
                        result_is_group_start <= 1'b0;
                        input_ptr <= input_ptr + 5'd1;
                        next_state <= READ_INPUT;
                    end else begin
                        // Different value, start new group
                        next_state <= PROCESS_NEW_GROUP;
                    end
                end

                FLUSH_BUFFER: begin
                    if (flush_ptr < buffer_ptr) begin
                        result <= buffer[flush_ptr];
                        result_valid <= 1'b1;
                        if (flush_ptr == 5'd0) begin
                            result_is_group_start <= 1'b1;
                        end else begin
                            result_is_group_start <= 1'b0;
                        end
                        flush_ptr <= flush_ptr + 5'd1;
                        next_state <= FLUSH_BUFFER;
                    end else if (input_ptr < len) begin
                        next_state <= READ_INPUT;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                PROCESS_NEW_GROUP: begin
                    // Flush remaining buffer elements (except first)
                    if (buffer_ptr > 5'd1) begin
                        flush_ptr <= 5'd1;
                        next_state <= FLUSH_BUFFER;
                    end else begin
                        // Start new group
                        buffer[0] <= arr[input_ptr];
                        buffer_ptr <= 5'd1;
                        prev_value <= arr[input_ptr];
                        result <= arr[input_ptr];
                        result_valid <= 1'b1;
                        result_is_group_start <= 1'b1;
                        input_ptr <= input_ptr + 5'd1;
                        next_state <= READ_INPUT;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // Cycle counter for safety
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= DONE_STATE;
                end
            end
        end
    end
endmodule