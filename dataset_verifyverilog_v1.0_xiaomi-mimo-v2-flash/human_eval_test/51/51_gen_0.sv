module RemoveVowels(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input done_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] PROCESSING = 3'd1;
    localparam [2:0] OUTPUTTING = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    localparam [2:0] FLUSHING   = 3'd4;

    // FSM registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Buffer management
    reg [7:0] buffer [0:15];  // FIFO buffer for 16 characters
    reg [4:0] write_ptr;       // Pointer for writing to buffer (0-16)
    reg [4:0] read_ptr;        // Pointer for reading from buffer (0-16)
    reg [4:0] valid_count;     // Number of valid characters in buffer
    
    // Output tracking
    reg [4:0] output_count;    // Number of characters outputted
    
    // Control signals
    reg is_vowel;              // Flag for vowel detection
    reg is_flush;              // Flag for flush mode
    
    // Vowel detection helper
    reg [7:0] temp_char;
    
    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            char_out <= 8'd0;
            valid_out <= 1'b0;
            write_ptr <= 5'd0;
            read_ptr <= 5'd0;
            valid_count <= 5'd0;
            output_count <= 5'd0;
            is_flush <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            // Default values
            valid_out <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    is_flush <= 1'b0;
                    write_ptr <= 5'd0;
                    read_ptr <= 5'd0;
                    valid_count <= 5'd0;
                    output_count <= 5'd0;
                    
                    if (start) begin
                        busy <= 1'b1;
                        // Continue with zeroed buffer state
                    end
                end
                
                PROCESSING: begin
                    busy <= 1'b1;
                    
                    // Input characters into buffer
                    if (valid_in && (write_ptr < 5'd16)) begin
                        buffer[write_ptr] <= char_in;
                        write_ptr <= write_ptr + 5'd1;
                        valid_count <= valid_count + 5'd1;
                    end
                    
                    // Check for end of input
                    if (done_in && (valid_count == 5'd0)) begin
                        // No more data to process
                        is_flush <= 1'b1;
                    end
                end
                
                OUTPUTTING: begin
                    busy <= 1'b1;
                    
                    // Output current character if it's a non-vowel
                    if (read_ptr < write_ptr) begin
                        temp_char <= buffer[read_ptr];
                        read_ptr <= read_ptr + 5'd1;
                        valid_count <= valid_count - 5'd1;
                        
                        // Check vowel and output immediately
                        case (buffer[read_ptr])
                            8'h61, 8'h41, 8'h65, 8'h45, 8'h69, 8'h49, 8'h6F, 8'h4F, 8'h75, 8'h55: begin
                                // Vowel - do nothing
                            end
                            default: begin
                                char_out <= buffer[read_ptr];
                                valid_out <= 1'b1;
                                output_count <= output_count + 5'd1;
                            end
                        endcase
                    end
                    
                    // Check if done with current buffer
                    if (read_ptr >= write_ptr) begin
                        if (is_flush) begin
                            // All done
                        end else if (done_in && (write_ptr <= read_ptr)) begin
                            // More data might come in
                            is_flush <= 1'b1;
                        end
                    end
                end
                
                FLUSHING: begin
                    busy <= 1'b1;
                    
                    // Output any remaining non-vowels
                    if (read_ptr < write_ptr) begin
                        temp_char <= buffer[read_ptr];
                        read_ptr <= read_ptr + 5'd1;
                        
                        case (buffer[read_ptr])
                            8'h61, 8'h41, 8'h65, 8'h45, 8'h69, 8'h49, 8'h6F, 8'h4F, 8'h75, 8'h55: begin
                                // Vowel - do nothing
                            end
                            default: begin
                                char_out <= buffer[read_ptr];
                                valid_out <= 1'b1;
                                output_count <= output_count + 5'd1;
                            end
                        endcase
                    end
                end
                
                DONE_STATE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    // Reset for next operation
                    write_ptr <= 5'd0;
                    read_ptr <= 5'd0;
                    valid_count <= 5'd0;
                    output_count <= 5'd0;
                    is_flush <= 1'b0;
                    for (i = 0; i < 16; i = i + 1) begin
                        buffer[i] <= 8'd0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    valid_out <= 1'b0;
                    write_ptr <= 5'd0;
                    read_ptr <= 5'd0;
                    valid_count <= 5'd0;
                    output_count <= 5'd0;
                    is_flush <= 1'b0;
                    for (i = 0; i < 16; i = i + 1) begin
                        buffer[i] <= 8'd0;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESSING: begin
                if (done_in && (valid_count == 5'd0)) begin
                    // No more data, go to DONE
                    next_state = DONE_STATE;
                end else if (valid_count > 5'd0) begin
                    // Has data to output
                    next_state = OUTPUTTING;
                end else begin
                    next_state = PROCESSING;
                end
            end
            
            OUTPUTTING: begin
                if (read_ptr >= write_ptr) begin
                    // Finished current buffer
                    if (is_flush) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = PROCESSING;
                    end
                end else begin
                    next_state = OUTPUTTING;
                end
            end
            
            FLUSHING: begin
                if (read_ptr >= write_ptr) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = FLUSHING;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule