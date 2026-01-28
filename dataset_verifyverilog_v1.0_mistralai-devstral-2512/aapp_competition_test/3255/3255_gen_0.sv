module LongestExplorationSequence(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] D,
    input [15:0] M,
    input [15:0] arr [0:15],
    output reg [15:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] SEARCH  = 3'd2;
    localparam [2:0] DONE    = 3'd3;

    reg [2:0] state, next_state;

    // Stack for DFS (FIFO)
    reg [7:0] stack_ptr;
    reg [15:0] stack_pos [0:255];
    reg [15:0] stack_mask [0:255];
    reg [15:0] stack_len [0:255];

    // Current state variables
    reg [3:0] current_pos;
    reg [15:0] current_mask;
    reg [15:0] current_len;

    // Global max length
    reg [15:0] max_len;

    // Cycle counter for timeout
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Helper signals
    reg [3:0] next_pos;
    reg [15:0] next_mask;
    reg [15:0] next_len;
    reg [15:0] abs_diff;
    reg valid_jump;
    reg stack_full;
    reg stack_empty;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 10'd0;
            max_len <= 16'd0;
            stack_ptr <= 8'd0;
            current_pos <= 4'd0;
            current_mask <= 16'd0;
            current_len <= 16'd0;

            // Initialize stack
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                stack_pos[i] <= 16'd0;
                stack_mask[i] <= 16'd0;
                stack_len[i] <= 16'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                        busy <= 1'b1;
                    end
                end

                INIT: begin
                    // Initialize for new computation
                    max_len <= 16'd0;
                    stack_ptr <= 8'd0;
                    cycle_count <= 10'd0;

                    // Push initial states (all starting positions)
                    integer i;
                    for (i = 0; i < n; i = i + 1) begin
                        if (stack_ptr < 256) begin
                            stack_pos[stack_ptr] <= i;
                            stack_mask[stack_ptr] <= (1 << i);
                            stack_len[stack_ptr] <= 16'd1;
                            stack_ptr <= stack_ptr + 8'd1;
                        end
                    end

                    next_state <= SEARCH;
                end

                SEARCH: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    cycle_count <= cycle_count + 10'd1;

                    // Check if stack is empty
                    stack_empty = (stack_ptr == 8'd0);

                    if (stack_empty || cycle_count >= MAX_CYCLES) begin
                        result <= max_len;
                        next_state <= DONE;
                    end else begin
                        // Pop from stack
                        stack_ptr <= stack_ptr - 8'd1;
                        current_pos <= stack_pos[stack_ptr];
                        current_mask <= stack_mask[stack_ptr];
                        current_len <= stack_len[stack_ptr];

                        // Update max length
                        if (current_len > max_len) begin
                            max_len <= current_len;
                        end

                        // Explore all possible jumps
                        integer d;
                        for (d = 1; d <= D; d = d + 1) begin
                            // Positive jump
                            next_pos = current_pos + d;
                            if (next_pos < n && !(current_mask[next_pos])) begin
                                // Check value difference
                                abs_diff = (arr[next_pos] > arr[current_pos]) ?
                                          (arr[next_pos] - arr[current_pos]) :
                                          (arr[current_pos] - arr[next_pos]);
                                valid_jump = (abs_diff <= M);

                                if (valid_jump && stack_ptr < 256) begin
                                    next_mask = current_mask | (1 << next_pos);
                                    next_len = current_len + 16'd1;
                                    stack_pos[stack_ptr] <= next_pos;
                                    stack_mask[stack_ptr] <= next_mask;
                                    stack_len[stack_ptr] <= next_len;
                                    stack_ptr <= stack_ptr + 8'd1;
                                end
                            end

                            // Negative jump
                            next_pos = current_pos - d;
                            if (next_pos >= 0 && !(current_mask[next_pos])) begin
                                // Check value difference
                                abs_diff = (arr[next_pos] > arr[current_pos]) ?
                                          (arr[next_pos] - arr[current_pos]) :
                                          (arr[current_pos] - arr[next_pos]);
                                valid_jump = (abs_diff <= M);

                                if (valid_jump && stack_ptr < 256) begin
                                    next_mask = current_mask | (1 << next_pos);
                                    next_len = current_len + 16'd1;
                                    stack_pos[stack_ptr] <= next_pos;
                                    stack_mask[stack_ptr] <= next_mask;
                                    stack_len[stack_ptr] <= next_len;
                                    stack_ptr <= stack_ptr + 8'd1;
                                end
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule