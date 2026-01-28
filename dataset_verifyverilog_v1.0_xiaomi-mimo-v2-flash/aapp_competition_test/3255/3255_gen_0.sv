module ExplorationFSM(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] D,
    input wire [15:0] M,
    input wire signed [15:0] arr [0:15],
    output reg [15:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] INIT   = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] DONE   = 3'd3;
    localparam [2:0] ERROR  = 3'd4;

    reg [2:0] state, next_state;
    
    // Control variables
    reg [15:0] max_length;
    reg [15:0] current_length;
    reg [3:0] current_pos;
    reg [15:0] visited_mask;
    reg [15:0] stack [0:255];  // Stack: upper bits = pos, middle bits = visited_mask
    reg [7:0] stack_ptr;
    reg [7:0] stack_size;
    
    // Search variables
    reg [3:0] jump_offset;
    reg [3:0] new_pos;
    reg signed [15:0] value_diff;
    reg stack_empty;
    reg jump_valid;
    
    // Cycle counter for timeout
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // For loop indices
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            max_length <= 16'd0;
            current_length <= 16'd0;
            current_pos <= 4'd0;
            visited_mask <= 16'd0;
            stack_ptr <= 8'd0;
            stack_size <= 8'd0;
            jump_offset <= 4'd0;
            new_pos <= 4'd0;
            value_diff <= 16'd0;
            cycle_count <= 10'd0;
            // Initialize stack to 0
            for (i = 0; i < 256; i = i + 1) begin
                stack[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= INIT;
                        busy <= 1'b1;
                    end
                end

                INIT: begin
                    // Initialize for starting position 0
                    max_length <= 16'd1;
                    current_length <= 16'd1;
                    current_pos <= 4'd0;
                    visited_mask <= 16'h0001;  // Bit 0 set
                    stack_ptr <= 8'd0;
                    stack_size <= 8'd1;
                    stack[0] <= {4'd0, 16'h0001, 8'd1};  // Format: pos, mask, length
                    state <= SEARCH;
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 10'd1;
                    stack_empty <= (stack_ptr >= stack_size);
                    
                    if (stack_ptr >= stack_size) begin
                        // Stack is empty, done with search
                        state <= DONE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Timeout protection
                        state <= DONE;
                    end else begin
                        // Pop state from stack
                        {current_pos, visited_mask, current_length} <= stack[stack_ptr];
                        stack_ptr <= stack_ptr + 8'd1;
                        jump_offset <= 4'd1;
                        jump_valid <= 1'b0;
                    end
                    
                    // Update global maximum if current path is longer
                    if (current_length > max_length) begin
                        max_length <= current_length;
                    end
                end

                // Continue SEARCH logic with jump evaluation
                // We need to check jumps in the next cycle(s)
                // This is a simplified approach - we process one jump per cycle
                
                DONE: begin
                    result <= max_length;
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
    
    // Separate always block for jump logic to handle multiple cycles per state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == SEARCH && !stack_empty && cycle_count < MAX_CYCLES) begin
                // Check positive and negative jumps
                if (jump_offset <= D) begin
                    // Check forward jump
                    if (current_pos + jump_offset < n) begin
                        new_pos <= current_pos + jump_offset;
                    end
                    // Check backward jump  
                    // Process one jump per cycle
                end
            end
        end
    end

    // Simplified approach: Use combinational logic for jump evaluation
    // and stack pushing within the same state
    
    // Re-implement with better control flow
    reg [3:0] jump_idx;
    reg push_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            jump_idx <= 4'd0;
            push_state <= 1'b0;
        end else if (state == SEARCH && !stack_empty && cycle_count < MAX_CYCLES) begin
            push_state <= 1'b0;
            
            // Evaluate one jump per cycle
            if (jump_idx == 4'd0) begin
                // First check forward jumps
                if (current_pos + jump_offset < n) begin
                    new_pos <= current_pos + jump_offset;
                    value_diff <= arr[current_pos + jump_offset] - arr[current_pos];
                    if (!(visited_mask & (16'd1 << (current_pos + jump_offset))) && 
                        ((value_diff >= 0 && value_diff <= M) || 
                         (value_diff < 0 && (-value_diff) <= M))) begin
                        // Valid forward jump - push to stack
                        if (stack_size < 256) begin
                            stack[stack_size] <= {current_pos + jump_offset, 
                                                  visited_mask | (16'd1 << (current_pos + jump_offset)), 
                                                  current_length + 16'd1};
                            stack_size <= stack_size + 8'd1;
                        end
                    end
                    jump_idx <= 4'd1;
                end else begin
                    jump_idx <= 4'd1;  // Skip to backward checks
                end
            end else if (jump_idx == 4'd1) begin
                // Check backward jumps
                if (current_pos >= jump_offset) begin
                    new_pos <= current_pos - jump_offset;
                    value_diff <= arr[current_pos - jump_offset] - arr[current_pos];
                    if (!(visited_mask & (16'd1 << (current_pos - jump_offset))) && 
                        ((value_diff >= 0 && value_diff <= M) || 
                         (value_diff < 0 && (-value_diff) <= M))) begin
                        // Valid backward jump - push to stack
                        if (stack_size < 256) begin
                            stack[stack_size] <= {current_pos - jump_offset, 
                                                  visited_mask | (16'd1 << (current_pos - jump_offset)), 
                                                  current_length + 16'd1};
                            stack_size <= stack_size + 8'd1;
                        end
                    end
                end
                jump_offset <= jump_offset + 4'd1;
                if (jump_offset >= D) begin
                    jump_idx <= 4'd0;  // Reset for next state
                end else begin
                    jump_idx <= 4'd0;  // Process next jump in next cycle
                end
            end
        end
    end

endmodule