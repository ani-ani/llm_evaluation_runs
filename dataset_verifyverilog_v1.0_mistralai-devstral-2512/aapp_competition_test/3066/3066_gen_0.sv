module tape_art_reconstructor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] color_in,
    input wire [7:0] len,
    output reg [1:0] cmd_type,
    output reg [7:0] l,
    output reg [7:0] r,
    output reg [7:0] c,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ      = 3'd1;
    localparam [2:0] VERIFY    = 3'd2;
    localparam [2:0] EMIT      = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Counters and pointers
    reg [7:0] idx;           // Current index (1-based)
    reg [7:0] stack_ptr;     // Stack pointer
    reg [7:0] emit_idx;      // Instruction emission index
    
    // Memories
    reg [7:0] color_ram [0:255];  // Stores input colors
    reg [7:0] first_ram [0:255];  // First index of each color
    reg [7:0] last_ram [0:255];   // Last index of each color
    reg [15:0] stack_ram [0:255]; // Stack: (start_index << 8) | color
    
    // Internal signals
    reg [7:0] current_color;
    reg [7:0] top_color;
    reg [7:0] top_start;
    reg valid_flag;
    reg impossible_flag;
    reg [7:0] temp_first;
    
    // Initialize memories and registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            idx <= 8'd0;
            stack_ptr <= 8'd0;
            emit_idx <= 8'd0;
            cmd_type <= 2'd0;
            l <= 8'd0;
            r <= 8'd0;
            c <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            valid_flag <= 1'b0;
            impossible_flag <= 1'b0;
            
            // Initialize memories
            for (i = 0; i < 256; i = i + 1) begin
                color_ram[i] <= 8'd0;
                first_ram[i] <= 8'd0;
                last_ram[i] <= 8'd0;
                stack_ram[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end
    
    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ;
                    idx = 8'd0;
                    stack_ptr = 8'd0;
                    emit_idx = 8'd0;
                    valid_flag = 1'b1;
                    impossible_flag = 1'b0;
                    error = 1'b0;
                    cmd_type = 2'd0;
                end
            end
            
            READ: begin
                if (idx < len) begin
                    // Store color and update first/last
                    color_ram[idx] = color_in;
                    current_color = color_in;
                    
                    if (first_ram[current_color] == 8'd0) begin
                        first_ram[current_color] = idx + 8'd1;
                    end
                    last_ram[current_color] = idx + 8'd1;
                    
                    idx = idx + 8'd1;
                end else begin
                    next_state = VERIFY;
                    idx = 8'd0;
                end
            end
            
            VERIFY: begin
                if (idx < len) begin
                    current_color = color_ram[idx];
                    temp_first = first_ram[current_color];
                    
                    if (color_ram[idx] != color_ram[temp_first - 8'd1]) begin
                        valid_flag = 1'b0;
                        impossible_flag = 1'b1;
                    end
                    
                    idx = idx + 8'd1;
                end else begin
                    if (impossible_flag) begin
                        next_state = FINISH;
                        cmd_type = 2'd0;
                        error = 1'b1;
                    end else begin
                        next_state = EMIT;
                        idx = 8'd0;
                        stack_ptr = 8'd0;
                    end
                end
            end
            
            EMIT: begin
                if (idx < len) begin
                    current_color = color_ram[idx];
                    
                    if (stack_ptr > 8'd0) begin
                        top_color = stack_ram[stack_ptr - 8'd1] & 255;
                        top_start = stack_ram[stack_ptr - 8'd1] >> 8;
                    end else begin
                        top_color = 8'd0;
                        top_start = 8'd0;
                    end
                    
                    if (stack_ptr > 8'd0 && top_color == current_color) begin
                        // Continue current interval
                        idx = idx + 8'd1;
                    end else if (idx + 8'd1 <= last_ram[current_color]) begin
                        // Push new interval
                        stack_ram[stack_ptr] = {idx + 8'd1, current_color};
                        stack_ptr = stack_ptr + 8'd1;
                        idx = idx + 8'd1;
                    end else if (stack_ptr > 8'd0 && idx + 8'd1 == last_ram[top_color]) begin
                        // Pop and emit instruction
                        l = top_start;
                        r = idx + 8'd1;
                        c = top_color;
                        cmd_type = 2'd2;
                        stack_ptr = stack_ptr - 8'd1;
                        emit_idx = emit_idx + 8'd1;
                        idx = idx + 8'd1;
                    end else begin
                        // Should not happen due to validity check
                        idx = idx + 8'd1;
                    end
                end else begin
                    // Emit remaining instructions
                    if (stack_ptr > 8'd0) begin
                        top_color = stack_ram[stack_ptr - 8'd1] & 255;
                        top_start = stack_ram[stack_ptr - 8'd1] >> 8;
                        l = top_start;
                        r = last_ram[top_color];
                        c = top_color;
                        cmd_type = 2'd2;
                        stack_ptr = stack_ptr - 8'd1;
                        emit_idx = emit_idx + 8'd1;
                    end else begin
                        next_state = FINISH;
                        cmd_type = 2'd1;
                    end
                end
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output handling
    always @(posedge clk) begin
        if (state == FINISH) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
        
        if (impossible_flag) begin
            error <= 1'b1;
            cmd_type <= 2'd0;
        end
    end

endmodule