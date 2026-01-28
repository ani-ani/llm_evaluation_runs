module boomerang_config (
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

    // Parameters
    localparam [10:0] MAX_N = 11'd1000;
    localparam [11:0] MAX_TARGETS = 12'd2000;
    localparam [10:0] MAX_ROW = 11'd1023;
    
    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] PROCESSING   = 3'd1;
    localparam [2:0] OUTPUTTING   = 3'd2;
    localparam [2:0] ERROR_STATE  = 3'd3;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [10:0] col_index;           // 0 to 1023
    reg [10:0] next_row;            // 1 to 1024
    reg [10:0] one_count_head;      // Stack pointer
    reg [10:0] two_count_head;
    reg [10:0] three_count_head;
    reg [11:0] target_buffer_head;  // For storing targets
    reg [11:0] target_buffer_tail;  // For outputting targets
    
    // Stack memories (implemented as 2D arrays)
    reg [9:0] one_count_mem [0:1023];
    reg [9:0] two_count_mem [0:1023];
    reg [9:0] three_count_mem [0:1023];
    
    // Target buffer (stores row, col pairs)
    reg [9:0] target_buffer_row [0:2047];
    reg [9:0] target_buffer_col [0:2047];
    
    // Temporary registers for target generation
    reg [9:0] temp_row;
    reg [9:0] temp_col;
    reg [10:0] total_columns;
    reg [11:0] max_targets_check;
    reg [1:0] pending_a;
    
    // Error flag register
    reg error_flag;
    
    integer i;
    
    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            col_index <= 11'd0;
            next_row <= 11'd1;
            one_count_head <= 11'd0;
            two_count_head <= 11'd0;
            three_count_head <= 11'd0;
            target_buffer_head <= 12'd0;
            target_buffer_tail <= 12'd0;
            target_count <= 18'd0;
            error <= 1'b0;
            error_flag <= 1'b0;
            done <= 1'b0;
            target_valid <= 1'b0;
            total_columns <= 11'd0;
            max_targets_check <= 12'd0;
            pending_a <= 2'd0;
        end else begin
            // Default assignments
            done <= 1'b0;
            target_valid <= 1'b0;
            error <= error_flag;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset all pointers and counters
                        col_index <= 11'd0;
                        next_row <= 11'd1;
                        one_count_head <= 11'd0;
                        two_count_head <= 11'd0;
                        three_count_head <= 11'd0;
                        target_buffer_head <= 12'd0;
                        target_buffer_tail <= 12'd0;
                        target_count <= 18'd0;
                        error <= 1'b0;
                        error_flag <= 1'b0;
                        total_columns <= 11'd0;
                        max_targets_check <= 12'd0;
                        pending_a <= 2'd0;
                        // Wait for first valid input
                        if (valid_in) begin
                            pending_a <= a_in;
                            state <= PROCESSING;
                        end else begin
                            // Stay in IDLE until first valid
                            state <= IDLE;
                        end
                    end
                end
                
                PROCESSING: begin
                    if (valid_in || (col_index == 11'd0)) begin
                        // Process current column
                        if (col_index >= MAX_N) begin
                            // Exceeded max columns
                            error_flag <= 1'b1;
                            state <= ERROR_STATE;
                        end else begin
                            case (pending_a)
                                2'd0: begin
                                    // a_i = 0: do nothing
                                end
                                2'd1: begin
                                    // a_i = 1: add new target
                                    if (next_row <= MAX_ROW) begin
                                        // Store target
                                        if (target_buffer_head < MAX_TARGETS) begin
                                            target_buffer_row[target_buffer_head] <= next_row[9:0];
                                            target_buffer_col[target_buffer_head] <= col_index[9:0];
                                            target_buffer_head <= target_buffer_head + 12'd1;
                                            target_count <= target_count + 18'd1;
                                            
                                            // Store in one_count stack
                                            if (one_count_head < MAX_N) begin
                                                one_count_mem[one_count_head] <= next_row[9:0];
                                                one_count_head <= one_count_head + 11'd1;
                                            end else begin
                                                error_flag <= 1'b1;
                                                state <= ERROR_STATE;
                                            end
                                            next_row <= next_row + 11'd1;
                                        end else begin
                                            error_flag <= 1'b1;
                                            state <= ERROR_STATE;
                                        end
                                    end else begin
                                        error_flag <= 1'b1;
                                        state <= ERROR_STATE;
                                    end
                                end
                                2'd2: begin
                                    // a_i = 2: consume from one_count, store in two_count
                                    if (one_count_head > 11'd0) begin
                                        one_count_head <= one_count_head - 11'd1;
                                        temp_row <= one_count_mem[one_count_head - 11'd1];
                                        temp_col <= col_index[9:0];
                                        // Store connection
                                        if (target_buffer_head < MAX_TARGETS) begin
                                            target_buffer_row[target_buffer_head] <= one_count_mem[one_count_head - 11'd1];
                                            target_buffer_col[target_buffer_head] <= col_index[9:0];
                                            target_buffer_head <= target_buffer_head + 12'd1;
                                            target_count <= target_count + 18'd1;
                                            
                                            // Store in two_count stack
                                            if (two_count_head < MAX_N) begin
                                                two_count_mem[two_count_head] <= one_count_mem[one_count_head - 11'd1];
                                                two_count_head <= two_count_head + 11'd1;
                                            end else begin
                                                error_flag <= 1'b1;
                                                state <= ERROR_STATE;
                                            end
                                        end else begin
                                            error_flag <= 1'b1;
                                            state <= ERROR_STATE;
                                        end
                                    end else begin
                                        // No pending target to connect
                                        error_flag <= 1'b1;
                                        state <= ERROR_STATE;
                                    end
                                end
                                2'd3: begin
                                    // a_i = 3: consume from three_count or two_count
                                    if (three_count_head > 11'd0) begin
                                        // Consume from three_count
                                        three_count_head <= three_count_head - 11'd1;
                                        temp_row <= three_count_mem[three_count_head - 11'd1];
                                        temp_col <= col_index[9:0];
                                        if (target_buffer_head < MAX_TARGETS) begin
                                            target_buffer_row[target_buffer_head] <= three_count_mem[three_count_head - 11'd1];
                                            target_buffer_col[target_buffer_head] <= col_index[9:0];
                                            target_buffer_head <= target_buffer_head + 12'd1;
                                            target_count <= target_count + 18'd1;
                                            // Store back in three_count (for next connection)
                                            if (three_count_head < MAX_N) begin
                                                three_count_mem[three_count_head] <= three_count_mem[three_count_head - 11'd1];
                                                three_count_head <= three_count_head + 11'd1;
                                            end else begin
                                                error_flag <= 1'b1;
                                                state <= ERROR_STATE;
                                            end
                                        end else begin
                                            error_flag <= 1'b1;
                                            state <= ERROR_STATE;
                                        end
                                    end else if (two_count_head > 11'd0) begin
                                        // Consume from two_count
                                        two_count_head <= two_count_head - 11'd1;
                                        temp_row <= two_count_mem[two_count_head - 11'd1];
                                        temp_col <= col_index[9:0];
                                        if (target_buffer_head < MAX_TARGETS) begin
                                            target_buffer_row[target_buffer_head] <= two_count_mem[two_count_head - 11'd1];
                                            target_buffer_col[target_buffer_head] <= col_index[9:0];
                                            target_buffer_head <= target_buffer_head + 12'd1;
                                            target_count <= target_count + 18'd1;
                                            // Store in three_count (for next connection)
                                            if (three_count_head < MAX_N) begin
                                                three_count_mem[three_count_head] <= two_count_mem[two_count_head - 11'd1];
                                                three_count_head <= three_count_head + 11'd1;
                                            end else begin
                                                error_flag <= 1'b1;
                                                state <= ERROR_STATE;
                                            end
                                        end else begin
                                            error_flag <= 1'b1;
                                            state <= ERROR_STATE;
                                        end
                                    end else begin
                                        // No pending target to connect
                                        error_flag <= 1'b1;
                                        state <= ERROR_STATE;
                                    end
                                end
                            endcase
                            
                            col_index <= col_index + 11'd1;
                            
                            // Prepare for next column
                            if (valid_in && (col_index < MAX_N - 11'd1)) begin
                                pending_a <= a_in;
                            end else begin
                                // If no more valid input, or reached max columns
                                if (!valid_in || col_index >= MAX_N - 11'd1) begin
                                    state <= OUTPUTTING;
                                end else begin
                                    state <= PROCESSING;
                                end
                            end
                        end
                    end else begin
                        // No valid input, check if we should continue
                        if (col_index >= MAX_N) begin
                            state <= OUTPUTTING;
                        end else if (pending_a == 2'd0) begin
                            // 0 hits, just increment
                            col_index <= col_index + 11'd1;
                        end
                    end
                end
                
                OUTPUTTING: begin
                    if (target_buffer_tail < target_buffer_head) begin
                        // Output next target
                        target_row <= target_buffer_row[target_buffer_tail];
                        target_col <= target_buffer_col[target_buffer_tail];
                        target_addr <= {8'd0, target_buffer_tail[9:0]};
                        target_valid <= 1'b1;
                        target_buffer_tail <= target_buffer_tail + 12'd1;
                    end else begin
                        // All targets output
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                ERROR_STATE: begin
                    error <= 1'b1;
                    error_flag <= 1'b1;
                    // Wait for reset or new start
                    if (start) begin
                        state <= IDLE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule