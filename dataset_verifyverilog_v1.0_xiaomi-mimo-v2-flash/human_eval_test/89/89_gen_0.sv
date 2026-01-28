module string_encryptor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_done,
    output reg [7:0] char_out,
    output reg char_valid_out,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] READING     = 3'd1;
    localparam [2:0] PROCESSING  = 3'd2;
    localparam [2:0] OUTPUT_CHAR = 3'd3;
    localparam [2:0] FINISHED    = 3'd4;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] write_ptr;  // 0-15 for 16 chars
    reg [3:0] read_ptr;   // 0-15 for 16 chars
    reg [3:0] char_count; // Number of characters stored
    reg [3:0] process_idx;
    reg [7:0] input_buffer [0:15];  // Fixed array: 16 chars x 8 bits
    reg [7:0] temp_char;
    reg [1:0] cycle_count;  // For processing delay
    
    // Combinational signals for arithmetic
    wire [5:0] val;
    wire [5:0] shifted;
    wire [5:0] out_val;
    
    // Arithmetic calculations (combinational)
    assign val = char_in - 8'd97;              // Convert ASCII to 0-25
    assign shifted = (val + 6'd4) % 6'd26;     // Shift by 4, wrap around
    assign out_val = shifted + 8'd97;          // Convert back to ASCII
    
    // Sequential logic for state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_ptr <= 4'd0;
            read_ptr <= 4'd0;
            char_count <= 4'd0;
            process_idx <= 4'd0;
            temp_char <= 8'd0;
            cycle_count <= 2'd0;
            char_out <= 8'd0;
            char_valid_out <= 1'b0;
            done <= 1'b0;
            // Initialize buffer (optional but good practice)
            for (integer i = 0; i < 16; i = i + 1) begin
                input_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            // Default outputs
            char_valid_out <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        write_ptr <= 4'd0;
                        read_ptr <= 4'd0;
                        char_count <= 4'd0;
                        process_idx <= 4'd0;
                        cycle_count <= 2'd0;
                    end
                end
                
                READING: begin
                    if (char_valid && write_ptr < 4'd16) begin
                        input_buffer[write_ptr] <= char_in;
                        write_ptr <= write_ptr + 4'd1;
                        char_count <= char_count + 4'd1;
                    end
                end
                
                PROCESSING: begin
                    if (process_idx < char_count) begin
                        cycle_count <= cycle_count + 2'd1;
                        if (cycle_count == 2'd1) begin
                            // Calculate encrypted character
                            temp_char <= out_val;
                        end
                    end
                end
                
                OUTPUT_CHAR: begin
                    char_out <= temp_char;
                    char_valid_out <= 1'b1;
                    read_ptr <= read_ptr + 4'd1;
                    cycle_count <= 2'd0;
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = READING;
            end
            
            READING: begin
                if (char_done) begin
                    if (char_count == 4'd0) begin
                        next_state = FINISHED;  // Empty string
                    end else begin
                        next_state = PROCESSING;
                    end
                end else if (write_ptr >= 4'd16) begin
                    // Buffer full, start processing
                    next_state = PROCESSING;
                end
            end
            
            PROCESSING: begin
                if (process_idx >= char_count) begin
                    next_state = FINISHED;
                end else if (cycle_count == 2'd1) begin
                    next_state = OUTPUT_CHAR;
                end
            end
            
            OUTPUT_CHAR: begin
                // Output completed, check if more chars to process
                if (read_ptr < char_count) begin
                    next_state = PROCESSING;
                    process_idx <= process_idx + 4'd1;
                end else begin
                    next_state = FINISHED;
                end
            end
            
            FINISHED: begin
                // Wait for next start pulse
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule