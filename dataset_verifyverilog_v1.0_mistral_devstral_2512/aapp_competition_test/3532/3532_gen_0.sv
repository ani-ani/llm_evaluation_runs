module string_explosion #(
    parameter MAX_STR_LEN = 8,
    parameter MAX_EXP_LEN = 4
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_str [0:MAX_STR_LEN-1],
    input wire [3:0] input_len,
    input wire [7:0] explosion_str [0:MAX_EXP_LEN-1],
    input wire [3:0] explosion_len,
    output reg [7:0] result_str [0:MAX_STR_LEN-1],
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Stack implementation
    reg [7:0] stack [0:MAX_STR_LEN-1];
    reg [3:0] sp;  // Stack pointer (next free position)
    
    // Input processing
    reg [3:0] input_idx;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Initialize stack
            integer i;
            for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                stack[i] <= 8'd0;
            end
            sp <= 4'd0;
            
            input_idx <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize outputs
            for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                result_str[i] <= 8'd0;
            end
            result_len <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        next_state <= PROCESS;
                        input_idx <= 4'd0;
                        sp <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Push current character onto stack
                    if (input_idx < input_len) begin
                        stack[sp] <= input_str[input_idx];
                        sp <= sp + 4'd1;
                        input_idx <= input_idx + 4'd1;
                    end
                    
                    // Check for explosion match
                    if (sp >= explosion_len && explosion_len > 0) begin
                        reg match;
                        integer i;
                        
                        // Compare top explosion_len characters
                        match = 1'b1;
                        for (i = 0; i < explosion_len; i = i + 1) begin
                            if (stack[sp - 4'd1 - i] != explosion_str[explosion_len - 4'd1 - i]) begin
                                match = 1'b0;
                            end
                        end
                        
                        // If match, remove explosion_len characters
                        if (match) begin
                            sp <= sp - explosion_len;
                        end
                    end
                    
                    // Check if processing is complete
                    if (input_idx >= input_len && cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else if (input_idx >= input_len) begin
                        // Check if stack is empty or no more explosions possible
                        reg no_more_explosions;
                        integer i;
                        
                        no_more_explosions = 1'b1;
                        if (sp >= explosion_len && explosion_len > 0) begin
                            for (i = 0; i < sp - explosion_len + 4'd1; i = i + 1) begin
                                reg local_match;
                                integer j;
                                
                                local_match = 1'b1;
                                for (j = 0; j < explosion_len; j = j + 1) begin
                                    if (stack[i + j] != explosion_str[j]) begin
                                        local_match = 1'b0;
                                    end
                                end
                                
                                if (local_match) begin
                                    no_more_explosions = 1'b0;
                                end
                            end
                        end
                        
                        if (no_more_explosions) begin
                            next_state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    // Copy stack to result
                    integer i;
                    for (i = 0; i < MAX_STR_LEN; i = i + 1) begin
                        if (i < sp) begin
                            result_str[i] <= stack[i];
                        end else begin
                            result_str[i] <= 8'd0;
                        end
                    end
                    result_len <= sp;
                    
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
endmodule