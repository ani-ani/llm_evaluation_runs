module bracket_fix(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire data_in,
    input wire valid_in,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers and wires
    reg [1:0] state;
    reg [10:0] balance;          // 11-bit signed: range -1024 to 1024
    reg [9:0] seg_len;           // 10-bit unsigned: max 1024
    reg seg_active;              // Flag for segment active
    reg [15:0] total_cost;       // 16-bit unsigned accumulator
    reg [9:0] input_count;       // 10-bit counter: max 1024 inputs
    reg [1023:0] input_buffer;   // 1024-bit shift register for storage
    reg [9:0] buffer_index;      // Current position in buffer for processing
    reg [9:0] stored_length;     // Number of stored inputs
    
    // Control flags
    reg processing_done;         // Flag indicating input processing complete
    reg buffer_stored;           // Flag indicating buffer full or all stored
    
    // Reset and state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            balance <= 11'sd0;
            seg_len <= 10'd0;
            seg_active <= 1'b0;
            total_cost <= 16'd0;
            input_count <= 10'd0;
            input_buffer <= 1024'd0;
            buffer_index <= 10'd0;
            stored_length <= 10'd0;
            processing_done <= 1'b0;
            buffer_stored <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    // Reset computational registers
                    balance <= 11'sd0;
                    seg_len <= 10'd0;
                    seg_active <= 1'b0;
                    total_cost <= 16'd0;
                    input_count <= 10'd0;
                    input_buffer <= 1024'd0;
                    buffer_index <= 10'd0;
                    stored_length <= 10'd0;
                    processing_done <= 1'b0;
                    buffer_stored <= 1'b0;
                    
                    if (start) begin
                        state <= READ;
                        ready <= 1'b0;
                    end
                end
                
                READ: begin
                    // Store input in buffer
                    if (valid_in) begin
                        input_buffer[stored_length] <= data_in;
                        stored_length <= stored_length + 10'd1;
                    end
                    
                    // Process stored buffer sequentially
                    if (buffer_stored || (valid_in && stored_length >= 10'd1024)) begin
                        buffer_stored <= 1'b1;
                        
                        // Process one character per cycle
                        if (buffer_index < stored_length) begin
                            // Process current character from buffer
                            if (input_buffer[buffer_index] == 1'b0) begin // '(' character
                                balance <= balance + 11'sd1;
                                // If segment is active and balance becomes 0
                                if (seg_active && (balance == -11'sd1)) begin
                                    // This is the character that brought balance to 0
                                    // Add segment length + 1 to total cost
                                    total_cost <= total_cost + {6'd0, seg_len} + 16'd1;
                                    seg_active <= 1'b0;
                                    seg_len <= 10'd0;
                                end
                            end else begin // ')' character
                                balance <= balance - 11'sd1;
                                // Check if balance becomes negative
                                if (balance <= 11'sd0) begin
                                    seg_active <= 1'b1;
                                    seg_len <= seg_len + 10'd1;
                                end
                            end
                            buffer_index <= buffer_index + 10'd1;
                        end else begin
                            // All buffer processed
                            processing_done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    ready <= 1'b1;
                    
                    // Check final balance
                    if (balance == 11'sd0 && processing_done) begin
                        result <= total_cost;
                    end else begin
                        result <= 16'hFFFF; // Represent -1
                    end
                    
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule