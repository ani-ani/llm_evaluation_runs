module string_explosion(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] in_char,
    input wire [7:0] explosion_pattern [0:7],
    input wire [3:0] pattern_len,
    input wire [6:0] input_len,
    output reg [7:0] out_char,
    output reg out_valid,
    output reg done,
    output reg frula
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] OUTPUTING = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Stack implementation
    reg [7:0] stack [0:63];
    reg [5:0] stack_ptr;
    
    // Processing counters
    reg [6:0] input_counter;
    reg [6:0] output_counter;
    
    // Pattern matching
    reg [3:0] match_counter;
    reg pattern_match;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            stack_ptr <= 6'd0;
            input_counter <= 7'd0;
            output_counter <= 7'd0;
            match_counter <= 4'd0;
            pattern_match <= 1'b0;
            out_char <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            frula <= 1'b0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end
            end
            
            PROCESSING: begin
                if (input_counter == input_len - 7'd1) begin
                    next_state = OUTPUTING;
                end
            end
            
            OUTPUTING: begin
                if (output_counter == stack_ptr) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Stack processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stack_ptr <= 6'd0;
            input_counter <= 7'd0;
            output_counter <= 7'd0;
            match_counter <= 4'd0;
            pattern_match <= 1'b0;
        end else begin
            case (state)
                PROCESSING: begin
                    // Push character onto stack
                    stack[stack_ptr] <= in_char;
                    
                    // Check for pattern match
                    if (pattern_len > 4'd0) begin
                        if (stack[stack_ptr] == explosion_pattern[pattern_len - 4'd1]) begin
                            match_counter <= match_counter + 4'd1;
                            if (match_counter == pattern_len - 4'd1) begin
                                pattern_match <= 1'b1;
                            end
                        end else begin
                            match_counter <= 4'd0;
                            pattern_match <= 1'b0;
                        end
                    end
                    
                    // Update stack pointer
                    if (pattern_match) begin
                        stack_ptr <= stack_ptr - (pattern_len - 4'd1);
                        match_counter <= 4'd0;
                        pattern_match <= 1'b0;
                    end else begin
                        stack_ptr <= stack_ptr + 6'd1;
                    end
                    
                    input_counter <= input_counter + 7'd1;
                end
                
                OUTPUTING: begin
                    if (output_counter < stack_ptr) begin
                        out_char <= stack[output_counter];
                        out_valid <= 1'b1;
                        output_counter <= output_counter + 7'd1;
                    end else begin
                        out_valid <= 1'b0;
                        done <= 1'b1;
                        
                        // Check for FRULA
                        if (stack_ptr == 6'd0) begin
                            frula <= 1'b1;
                        end else begin
                            frula <= 1'b0;
                        end
                    end
                end
                
                default: begin
                    stack_ptr <= 6'd0;
                    input_counter <= 7'd0;
                    output_counter <= 7'd0;
                    match_counter <= 4'd0;
                    pattern_match <= 1'b0;
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    frula <= 1'b0;
                end
            endcase
        end
    end
    
    // Done signal handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == OUTPUTING && output_counter == stack_ptr) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule