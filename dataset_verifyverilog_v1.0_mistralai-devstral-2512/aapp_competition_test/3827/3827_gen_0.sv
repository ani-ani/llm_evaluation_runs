module pattern_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] length,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state, next_state;
    reg [7:0] char_buffer [0:31];
    reg [4:0] char_index;
    reg [4:0] count_a, count_b, count_c;
    reg [4:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            char_index <= 5'd0;
            count_a <= 5'd0;
            count_b <= 5'd0;
            count_c <= 5'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                    char_index = 5'd0;
                    count_a = 5'd0;
                    count_b = 5'd0;
                    count_c = 5'd0;
                    cycle_count = 8'd0;
                end
            end
            
            LOAD: begin
                if (char_index < length) begin
                    char_buffer[char_index] = char_in;
                    char_index = char_index + 5'd1;
                end else begin
                    next_state = CHECK;
                end
            end
            
            CHECK: begin
                reg [4:0] i;
                reg valid_pattern;
                reg has_a, has_b;
                reg [4:0] a_count, b_count, c_count;
                
                // Initialize
                valid_pattern = 1'b1;
                has_a = 1'b0;
                has_b = 1'b0;
                a_count = 5'd0;
                b_count = 5'd0;
                c_count = 5'd0;
                
                // Check pattern and count characters
                for (i = 0; i < length; i = i + 1) begin
                    if (char_buffer[i] == 8'd97) begin  // 'a'
                        a_count = a_count + 5'd1;
                        has_a = 1'b1;
                    end else if (char_buffer[i] == 8'd98) begin  // 'b'
                        b_count = b_count + 5'd1;
                        has_b = 1'b1;
                    end else if (char_buffer[i] == 8'd99) begin  // 'c'
                        c_count = c_count + 5'd1;
                    end else begin
                        valid_pattern = 1'b0;
                    end
                end
                
                // Check if pattern is strictly non-decreasing
                reg in_a, in_b, in_c;
                in_a = 1'b1;
                in_b = 1'b0;
                in_c = 1'b0;
                
                for (i = 0; i < length; i = i + 1) begin
                    if (in_a) begin
                        if (char_buffer[i] == 8'd97) begin
                            // Still in 'a's
                        end else if (char_buffer[i] == 8'd98) begin
                            in_a = 1'b0;
                            in_b = 1'b1;
                        end else if (char_buffer[i] == 8'd99) begin
                            valid_pattern = 1'b0;
                        end else begin
                            valid_pattern = 1'b0;
                        end
                    end else if (in_b) begin
                        if (char_buffer[i] == 8'd97) begin
                            valid_pattern = 1'b0;
                        end else if (char_buffer[i] == 8'd98) begin
                            // Still in 'b's
                        end else if (char_buffer[i] == 8'd99) begin
                            in_b = 1'b0;
                            in_c = 1'b1;
                        end else begin
                            valid_pattern = 1'b0;
                        end
                    end else if (in_c) begin
                        if (char_buffer[i] == 8'd97 || char_buffer[i] == 8'd98) begin
                            valid_pattern = 1'b0;
                        end else if (char_buffer[i] != 8'd99) begin
                            valid_pattern = 1'b0;
                        end
                    end
                end
                
                // Check conditions
                if (valid_pattern && has_a && has_b && 
                    ((c_count == a_count) || (c_count == b_count))) begin
                    result = 1'b1;
                end else begin
                    result = 1'b0;
                end
                
                next_state = FINISH;
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE) begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state = IDLE;
                result <= 1'b0;
                done <= 1'b1;
            end
        end
    end
    
endmodule