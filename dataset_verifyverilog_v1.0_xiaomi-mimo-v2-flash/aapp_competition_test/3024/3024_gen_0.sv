module MaximumPalindromePartition(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] s,
    input wire [4:0] len,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] MATCH_FOUND = 3'd3;
    localparam [2:0] UPDATE_POINTERS = 3'd4;
    localparam [2:0] NEXT_WIDTH = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] l_reg, r_reg;
    reg [4:0] width_reg;
    reg [4:0] current_count_reg;
    reg [4:0] result_reg;
    reg [9:0] cycle_count; // 1024 cycles max (32*32)
    
    // Temporary storage for comparison
    reg [3:0] left_char;
    reg [3:0] right_char;
    reg match_flag;
    
    // Helper signals
    wire [4:0] remaining_len;
    wire [4:0] l_plus_width;
    wire [4:0] r_minus_width;
    
    assign remaining_len = r_reg - l_reg + 5'd1;
    assign l_plus_width = l_reg + width_reg;
    assign r_minus_width = r_reg - width_reg;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            l_reg <= 5'd0;
            r_reg <= 5'd0;
            width_reg <= 5'd1;
            current_count_reg <= 5'd0;
            result_reg <= 5'd0;
            cycle_count <= 10'd0;
            left_char <= 4'd0;
            right_char <= 4'd0;
            match_flag <= 1'b0;
            result <= 5'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        l_reg <= 5'd0;
                        r_reg <= len - 5'd1;
                        width_reg <= 5'd1;
                        current_count_reg <= 5'd0;
                    end
                end
                
                LOAD: begin
                    // Prepare for comparison
                    match_flag <= 1'b0;
                end
                
                PROCESS: begin
                    // Extract characters for comparison
                    left_char <= s[(l_plus_width << 2) +: 4];
                    right_char <= s[(r_minus_width << 2) +: 4];
                    
                    if (width_reg > remaining_len) begin
                        // No match possible for any width, whole string is one partition
                        result_reg <= 5'd1;
                    end
                end
                
                MATCH_FOUND: begin
                    if (left_char == right_char) begin
                        match_flag <= 1'b1;
                    end
                end
                
                UPDATE_POINTERS: begin
                    if (match_flag) begin
                        current_count_reg <= current_count_reg + 5'd2;
                        l_reg <= l_plus_width + 5'd1;
                        r_reg <= r_minus_width - 5'd1;
                        width_reg <= 5'd1; // Reset width for next segment
                    end
                end
                
                NEXT_WIDTH: begin
                    width_reg <= width_reg + 5'd1;
                end
                
                FINISH: begin
                    if (match_flag) begin
                        // Update pointers were successful
                        if (l_reg > r_reg) begin
                            if (l_reg == r_reg + 5'd1) begin
                                result_reg <= current_count_reg;
                            end else if (l_reg == r_reg + 5'd2) begin
                                result_reg <= current_count_reg + 5'd1;
                            end else begin
                                // Should not happen with proper logic, but safe fallback
                                result_reg <= current_count_reg;
                            end
                        end
                    end else if (l_reg > r_reg) begin
                        // Process finished via other condition
                        result_reg <= current_count_reg;
                    end
                    
                    result <= result_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            cycle_count <= cycle_count + 10'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                next_state = PROCESS;
            end
            
            PROCESS: begin
                if (width_reg > remaining_len) begin
                    // No match found for any width, result is 1
                    next_state = FINISH;
                end else begin
                    next_state = MATCH_FOUND;
                end
            end
            
            MATCH_FOUND: begin
                if (left_char == right_char) begin
                    next_state = UPDATE_POINTERS;
                end else begin
                    next_state = NEXT_WIDTH;
                end
            end
            
            UPDATE_POINTERS: begin
                next_state = PROCESS;
            end
            
            NEXT_WIDTH: begin
                next_state = PROCESS;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety: Check if pointers crossed or cycle limit reached
        if ((l_reg > r_reg || cycle_count >= 10'd1024) && (state != FINISH)) begin
            next_state = FINISH;
        end
    end

endmodule