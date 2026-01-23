module cyclic_codec (
    input clk,
    input rst_n,
    input start,
    input mode,
    input [7:0] char_in,
    input valid_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done
);

    // Parameters
    localparam [7:0] MAX_LEN = 8'd16;
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [2:0] buffer_idx;          // Index for 3-char buffer (0,1,2)
    reg [2:0] char_count;          // Count of characters received (0-6 for buffer)
    reg [7:0] char_buffer [0:2];   // 3-character buffer
    reg [2:0] output_idx;          // Index for output sequence
    reg output_active;             // Flag for outputting buffered characters
    reg [2:0] output_counter;      // Count of characters being output
    reg [7:0] output_buffer [0:2]; // Output buffer for transformation
    reg [2:0] output_buffer_idx;   // Index for output buffer
    reg [1:0] shift_count;         // For output delay control
    reg mode_reg;                  // Registered mode
    
    // Cycle counter for timeout protection
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            
            PROCESSING: begin
                // Exit when buffer is empty and no more input expected
                if (char_count == 3'd0 && buffer_idx == 3'd0 && 
                    !output_active && shift_count == 2'd0 && cycle_count >= MAX_LEN)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State machine sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            buffer_idx <= 3'd0;
            char_count <= 3'd0;
            output_idx <= 3'd0;
            output_active <= 1'b0;
            output_counter <= 3'd0;
            output_buffer_idx <= 3'd0;
            shift_count <= 2'd0;
            mode_reg <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize character buffer
            char_buffer[0] <= 8'd0;
            char_buffer[1] <= 8'd0;
            char_buffer[2] <= 8'd0;
            // Initialize output buffer
            output_buffer[0] <= 8'd0;
            output_buffer[1] <= 8'd0;
            output_buffer[2] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_out <= 1'b0;
                    buffer_idx <= 3'd0;
                    char_count <= 3'd0;
                    output_idx <= 3'd0;
                    output_active <= 1'b0;
                    output_counter <= 3'd0;
                    output_buffer_idx <= 3'd0;
                    shift_count <= 2'd0;
                    cycle_count <= 8'd0;
                    char_buffer[0] <= 8'd0;
                    char_buffer[1] <= 8'd0;
                    char_buffer[2] <= 8'd0;
                    output_buffer[0] <= 8'd0;
                    output_buffer[1] <= 8'd0;
                    output_buffer[2] <= 8'd0;
                    if (start) begin
                        mode_reg <= mode;
                    end
                end
                
                PROCESSING: begin
                    // Increment cycle counter when receiving input
                    if (valid_in && cycle_count < MAX_LEN) begin
                        cycle_count <= cycle_count + 8'd1;
                    end
                    
                    // Default: no valid output
                    valid_out <= 1'b0;
                    
                    // Input processing: store in buffer
                    if (valid_in && char_count < 6) begin
                        char_buffer[buffer_idx] <= char_in;
                        buffer_idx <= buffer_idx + 3'd1;
                        char_count <= char_count + 3'd1;
                        
                        // When we have 3 chars or it's the last expected input, trigger output
                        if ((buffer_idx == 3'd2) || 
                            (cycle_count == MAX_LEN - 3'd1 && valid_in)) begin
                            output_active <= 1'b1;
                            output_counter <= buffer_idx + 3'd1;
                            output_buffer_idx <= 3'd0;
                            
                            // Copy buffer to output buffer
                            output_buffer[0] <= char_buffer[0];
                            output_buffer[1] <= char_buffer[1];
                            output_buffer[2] <= char_buffer[2];
                            
                            // Also include the just-received character
                            if (buffer_idx == 3'd0)
                                output_buffer[0] <= char_in;
                            else if (buffer_idx == 3'd1)
                                output_buffer[1] <= char_in;
                            else if (buffer_idx == 3'd2)
                                output_buffer[2] <= char_in;
                        end
                    end
                    
                    // Output processing: transform and send
                    if (output_active && shift_count == 2'd0) begin
                        shift_count <= 2'd2;  // 2-cycle delay before output
                    end
                    
                    if (output_active && shift_count > 2'd0) begin
                        shift_count <= shift_count - 2'd1;
                        
                        if (shift_count == 2'd1) begin
                            // Output character based on output buffer index
                            if (output_buffer_idx < output_counter) begin
                                valid_out <= 1'b1;
                                
                                if (mode_reg == 1'b0) begin
                                    // ENCODE: output order 1,2,0
                                    if (output_buffer_idx == 3'd0) begin
                                        if (output_counter >= 3'd1) begin
                                            char_out <= output_buffer[1];
                                            output_buffer_idx <= output_buffer_idx + 3'd1;
                                        end
                                    end else if (output_buffer_idx == 3'd1) begin
                                        if (output_counter >= 3'd2) begin
                                            char_out <= output_buffer[2];
                                            output_buffer_idx <= output_buffer_idx + 3'd1;
                                        end
                                    end else if (output_buffer_idx == 3'd2) begin
                                        if (output_counter >= 3'd3) begin
                                            char_out <= output_buffer[0];
                                            output_buffer_idx <= output_buffer_idx + 3'd1;
                                        end
                                    end
                                end else begin
                                    // DECODE: output order 2,0,1
                                    if (output_buffer_idx == 3'd0) begin
                                        if (output_counter >= 3'd1) begin
                                            char_out <= output_buffer[2];
                                            output_buffer_idx <= output_buffer_idx + 3'd1;
                                        end
                                    end else if (output_buffer_idx == 3'd1) begin
                                        if (output_counter >= 3'd2) begin
                                            char_out <= output_buffer[0];
                                            output_buffer_idx <= output_buffer_idx + 3'd1;
                                        end
                                    end else if (output_buffer_idx == 3'd2) begin
                                        if (output_counter >= 3'd3) begin
                                            char_out <= output_buffer[1];
                                            output_buffer_idx <= output_buffer_idx + 3'd1;
                                        end
                                    end
                                end
                            end
                            
                            // Check if all output done
                            if (output_buffer_idx == output_counter) begin
                                output_active <= 1'b0;
                                
                                // Clear buffer if all chars processed
                                if (buffer_idx == 3'd3 || 
                                    (cycle_count >= MAX_LEN && char_count == 3'd0)) begin
                                    buffer_idx <= 3'd0;
                                    char_count <= 3'd0;
                                    char_buffer[0] <= 8'd0;
                                    char_buffer[1] <= 8'd0;
                                    char_buffer[2] <= 8'd0;
                                end
                            end
                        end
                    end
                    
                    // Also handle final character when no more valid_in
                    if (!valid_in && buffer_idx > 3'd0 && buffer_idx < 3'd3 && 
                        !output_active && shift_count == 2'd0 && 
                        cycle_count >= MAX_LEN) begin
                        output_active <= 1'b1;
                        output_counter <= buffer_idx;
                        output_buffer_idx <= 3'd0;
                        output_buffer[0] <= char_buffer[0];
                        output_buffer[1] <= char_buffer[1];
                        output_buffer[2] <= char_buffer[2];
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid_out <= 1'b0;
                    buffer_idx <= 3'd0;
                    char_count <= 3'd0;
                    output_active <= 1'b0;
                    shift_count <= 2'd0;
                    cycle_count <= 8'd0;
                end
                
                default: begin
                    state <= IDLE;
                    valid_out <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule