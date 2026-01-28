module word_reverser(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:7],
    output reg [7:0] result [0:7],
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PARSE     = 3'd1;
    localparam [2:0] REVERSE   = 3'd2;
    localparam [2:0] WRITE     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Word storage
    reg [7:0] word_start [0:3];
    reg [7:0] word_end [0:3];
    reg [3:0] word_count;
    reg [3:0] current_word;
    reg [7:0] output_index;
    reg [7:0] input_index;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            
            // Initialize word storage
            word_count <= 4'd0;
            current_word <= 4'd0;
            output_index <= 8'd0;
            input_index <= 8'd0;
            
            // Initialize word boundaries
            integer i;
            for (i = 0; i < 4; i = i + 1) begin
                word_start[i] <= 8'd0;
                word_end[i] <= 8'd0;
            end
            
            // Initialize output
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PARSE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PARSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Parse input string to find word boundaries
                    if (input_index < 8'd8) begin
                        if (str[input_index] == 8'h20) begin
                            // Space found, end of current word
                            word_end[word_count] <= input_index - 8'd1;
                            word_count <= word_count + 4'd1;
                        end
                        input_index <= input_index + 8'd1;
                        
                        // Check if we've reached end of string
                        if (input_index == 8'd8) begin
                            word_end[word_count] <= 8'd7;
                            word_count <= word_count + 4'd1;
                            next_state <= REVERSE;
                        end
                    end else begin
                        next_state <= REVERSE;
                    end
                end
                
                REVERSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Copy words in reverse order to output
                    if (current_word < word_count) begin
                        reg [7:0] word_start_idx;
                        reg [7:0] word_end_idx;
                        reg [7:0] i;
                        
                        // Get word boundaries (reverse order)
                        word_start_idx = word_start[word_count - 4'd1 - current_word];
                        word_end_idx = word_end[word_count - 4'd1 - current_word];
                        
                        // Copy word to output
                        for (i = word_start_idx; i <= word_end_idx; i = i + 1) begin
                            result[output_index] <= str[i];
                            output_index <= output_index + 8'd1;
                        end
                        
                        // Add space if not last word
                        if (current_word < word_count - 4'd1) begin
                            result[output_index] <= 8'h20;
                            output_index <= output_index + 8'd1;
                        end
                        
                        current_word <= current_word + 4'd1;
                        
                        // Check if all words processed
                        if (current_word == word_count) begin
                            next_state <= WRITE;
                        end
                    end else begin
                        next_state <= WRITE;
                    end
                end
                
                WRITE: begin
                    cycle_count <= cycle_count + 8'd1;
                    next_state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = IDLE;
            PARSE: next_state = PARSE;
            REVERSE: next_state = REVERSE;
            WRITE: next_state = WRITE;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Initialize word start positions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < 4; i = i + 1) begin
                word_start[i] <= 8'd0;
            end
        end else if (state == PARSE && input_index == 8'd0) begin
            // First character is start of first word
            word_start[0] <= 8'd0;
        end else if (state == PARSE && str[input_index] == 8'h20 && input_index > 8'd0) begin
            // After space, next character is start of new word
            word_start[word_count] <= input_index + 8'd1;
        end
    end
    
    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= FINISH;
        end
    end
    
endmodule