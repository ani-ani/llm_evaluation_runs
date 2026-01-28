module boomerang_target_config(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] a_in,
    input wire valid_in,
    output reg done,
    output reg error,
    output reg [17:0] target_count,
    output reg [17:0] target_addr,
    output reg [9:0] target_row,
    output reg [9:0] target_col,
    output reg target_valid
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESSING = 3'd1;
    localparam [2:0] OUTPUTTING = 3'd2;
    localparam [2:0] ERROR_STATE = 3'd3;

    // Stack sizes (max n=1000)
    localparam [9:0] MAX_STACK_SIZE = 10'd1000;
    localparam [10:0] MAX_TARGETS = 11'd2000;

    // Internal registers
    reg [2:0] process_state;
    reg [9:0] next_row;
    reg [9:0] col_index;
    reg [9:0] stack_ptr_one;
    reg [9:0] stack_ptr_two;
    reg [9:0] stack_ptr_three;
    reg [9:0] target_buffer_row [0:2047];
    reg [9:0] target_buffer_col [0:2047];
    reg [10:0] target_head;
    reg [10:0] target_tail;
    reg [9:0] stack_one [0:999];
    reg [9:0] stack_two [0:999];
    reg [9:0] stack_three [0:999];

    // Stack operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            process_state <= IDLE;
            next_row <= 10'd0;
            col_index <= 10'd0;
            stack_ptr_one <= 10'd0;
            stack_ptr_two <= 10'd0;
            stack_ptr_three <= 10'd0;
            target_head <= 11'd0;
            target_tail <= 11'd0;
            done <= 1'b0;
            error <= 1'b0;
            target_count <= 18'd0;
            target_addr <= 18'd0;
            target_row <= 10'd0;
            target_col <= 10'd0;
            target_valid <= 1'b0;
        end else begin
            case (process_state)
                IDLE: begin
                    if (start) begin
                        process_state <= PROCESSING;
                        next_row <= 10'd1;
                        col_index <= 10'd0;
                        stack_ptr_one <= 10'd0;
                        stack_ptr_two <= 10'd0;
                        stack_ptr_three <= 10'd0;
                        target_head <= 11'd0;
                        target_tail <= 11'd0;
                        error <= 1'b0;
                    end
                end

                PROCESSING: begin
                    if (valid_in) begin
                        // Process current column
                        case (a_in)
                            2'd0: begin
                                // No targets needed
                                col_index <= col_index + 10'd1;
                            end

                            2'd1: begin
                                // Add new target to one_count stack
                                if (stack_ptr_one < MAX_STACK_SIZE) begin
                                    stack_one[stack_ptr_one] <= next_row;
                                    stack_ptr_one <= stack_ptr_one + 10'd1;
                                    next_row <= next_row + 10'd1;
                                    col_index <= col_index + 10'd1;
                                end else begin
                                    error <= 1'b1;
                                    process_state <= ERROR_STATE;
                                end
                            end

                            2'd2: begin
                                // Consume from one_count stack
                                if (stack_ptr_one > 10'd0) begin
                                    stack_ptr_one <= stack_ptr_one - 10'd1;
                                    // Add target at (stack_one[stack_ptr_one], col_index)
                                    if (target_tail < MAX_TARGETS) begin
                                        target_buffer_row[target_tail] <= stack_one[stack_ptr_one];
                                        target_buffer_col[target_tail] <= col_index;
                                        target_tail <= target_tail + 11'd1;
                                        // Add new target to two_count stack
                                        stack_two[stack_ptr_two] <= next_row;
                                        stack_ptr_two <= stack_ptr_two + 10'd1;
                                        next_row <= next_row + 10'd1;
                                        col_index <= col_index + 10'd1;
                                    end else begin
                                        error <= 1'b1;
                                        process_state <= ERROR_STATE;
                                    end
                                end else begin
                                    error <= 1'b1;
                                    process_state <= ERROR_STATE;
                                end
                            end

                            2'd3: begin
                                // Try to consume from three_count first, then two_count
                                if (stack_ptr_three > 10'd0) begin
                                    stack_ptr_three <= stack_ptr_three - 10'd1;
                                    // Add two targets
                                    if (target_tail + 11'd2 < MAX_TARGETS) begin
                                        target_buffer_row[target_tail] <= stack_three[stack_ptr_three];
                                        target_buffer_col[target_tail] <= col_index;
                                        target_tail <= target_tail + 11'd1;
                                        target_buffer_row[target_tail] <= next_row;
                                        target_buffer_col[target_tail] <= col_index;
                                        target_tail <= target_tail + 11'd1;
                                        next_row <= next_row + 10'd1;
                                        col_index <= col_index + 10'd1;
                                    end else begin
                                        error <= 1'b1;
                                        process_state <= ERROR_STATE;
                                    end
                                end else if (stack_ptr_two > 10'd0) begin
                                    stack_ptr_two <= stack_ptr_two - 10'd1;
                                    // Add two targets
                                    if (target_tail + 11'd2 < MAX_TARGETS) begin
                                        target_buffer_row[target_tail] <= stack_two[stack_ptr_two];
                                        target_buffer_col[target_tail] <= col_index;
                                        target_tail <= target_tail + 11'd1;
                                        target_buffer_row[target_tail] <= next_row;
                                        target_buffer_col[target_tail] <= col_index;
                                        target_tail <= target_tail + 11'd1;
                                        // Add new target to three_count stack
                                        stack_three[stack_ptr_three] <= next_row + 10'd1;
                                        stack_ptr_three <= stack_ptr_three + 10'd1;
                                        next_row <= next_row + 10'd2;
                                        col_index <= col_index + 10'd1;
                                    end else begin
                                        error <= 1'b1;
                                        process_state <= ERROR_STATE;
                                    end
                                end else begin
                                    error <= 1'b1;
                                    process_state <= ERROR_STATE;
                                end
                            end
                        endcase

                        // Check if all columns processed
                        if (col_index >= 10'd1000) begin
                            target_count <= target_tail;
                            if (target_tail > 11'd0) begin
                                process_state <= OUTPUTTING;
                                target_head <= 11'd0;
                            end else begin
                                done <= 1'b1;
                                process_state <= IDLE;
                            end
                        end
                    end
                end

                OUTPUTTING: begin
                    if (target_head < target_tail) begin
                        target_row <= target_buffer_row[target_head];
                        target_col <= target_buffer_col[target_head];
                        target_addr <= target_head;
                        target_valid <= 1'b1;
                        target_head <= target_head + 11'd1;
                        if (target_head == target_tail - 11'd1) begin
                            done <= 1'b1;
                            process_state <= IDLE;
                        end
                    end else begin
                        target_valid <= 1'b0;
                        done <= 1'b1;
                        process_state <= IDLE;
                    end
                end

                ERROR_STATE: begin
                    error <= 1'b1;
                    done <= 1'b1;
                    process_state <= IDLE;
                end

                default: begin
                    process_state <= IDLE;
                end
            endcase
        end
    end

endmodule