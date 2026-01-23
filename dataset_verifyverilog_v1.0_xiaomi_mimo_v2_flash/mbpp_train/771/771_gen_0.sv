module bracket_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input write_en,
    input check_start,
    output reg result,
    output reg done,
    output reg [2:0] error_code
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] WRITE_CHARS = 3'd1;
    localparam [2:0] CHECKING    = 3'd2;
    localparam [2:0] COMPLETE    = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] char_buffer [0:15];  // 16 character buffer
    reg [4:0] char_count;           // Track number of chars written (0-16)
    reg [4:0] process_index;        // Current character being processed
    reg [3:0] stack_ptr;            // Stack pointer (0-8)
    reg [7:0] stack [0:7];          // Stack array (max 8 elements)
    reg [7:0] current_char;
    
    // Error codes
    localparam [2:0] ERR_SUCCESS      = 3'd0;
    localparam [2:0] ERR_STACK_UNDER  = 3'd1;
    localparam [2:0] ERR_UNMATCHED    = 3'd2;
    localparam [2:0] ERR_STACK_OVER   = 3'd3;
    localparam [2:0] ERR_INVALID_CHAR = 3'd4;

    integer i;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = WRITE_CHARS;
                end else begin
                    next_state = IDLE;
                end
            end
            WRITE_CHARS: begin
                if (check_start) begin
                    next_state = CHECKING;
                end else begin
                    next_state = WRITE_CHARS;
                end
            end
            CHECKING: begin
                if (process_index >= char_count) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = CHECKING;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            error_code <= ERR_SUCCESS;
            char_count <= 5'd0;
            process_index <= 5'd0;
            stack_ptr <= 4'd0;
            current_char <= 8'd0;
            // Initialize buffer
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 8'd0;
            end
            // Initialize stack
            for (i = 0; i < 8; i = i + 1) begin
                stack[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    result <= 1'b0;
                    error_code <= ERR_SUCCESS;
                    char_count <= 5'd0;
                    process_index <= 5'd0;
                    stack_ptr <= 4'd0;
                    // Clear buffer and stack
                    for (i = 0; i < 16; i = i + 1) begin
                        char_buffer[i] <= 8'd0;
                    end
                    for (i = 0; i < 8; i = i + 1) begin
                        stack[i] <= 8'd0;
                    end
                end
                
                WRITE_CHARS: begin
                    if (write_en && char_count < 5'd16) begin
                        char_buffer[char_count] <= char_in;
                        char_count <= char_count + 5'd1;
                    end
                end
                
                CHECKING: begin
                    if (process_index < char_count) begin
                        current_char <= char_buffer[process_index];
                        
                        // Handle opening brackets
                        if (char_buffer[process_index] == 8'h28 || // (
                            char_buffer[process_index] == 8'h7B || // {
                            char_buffer[process_index] == 8'h5B) begin // [
                            
                            if (stack_ptr < 4'd8) begin
                                stack[stack_ptr] <= char_buffer[process_index];
                                stack_ptr <= stack_ptr + 4'd1;
                            end else begin
                                // Stack overflow
                                result <= 1'b0;
                                error_code <= ERR_STACK_OVER;
                            end
                        end
                        // Handle closing brackets
                        else if (char_buffer[process_index] == 8'h29 || // )
                                 char_buffer[process_index] == 8'h7D || // }
                                 char_buffer[process_index] == 8'h5D) begin // ]
                            
                            if (stack_ptr == 4'd0) begin
                                // Stack underflow
                                result <= 1'b0;
                                error_code <= ERR_STACK_UNDER;
                            end else begin
                                // Check match
                                stack_ptr <= stack_ptr - 4'd1;
                                if ((char_buffer[process_index] == 8'h29 && stack[stack_ptr - 4'd1] != 8'h28) ||
                                    (char_buffer[process_index] == 8'h7D && stack[stack_ptr - 4'd1] != 8'h7B) ||
                                    (char_buffer[process_index] == 8'h5D && stack[stack_ptr - 4'd1] != 8'h5B)) begin
                                    result <= 1'b0;
                                    error_code <= ERR_UNMATCHED;
                                end
                            end
                        end
                        // Invalid character
                        else begin
                            result <= 1'b0;
                            error_code <= ERR_INVALID_CHAR;
                        end
                        
                        process_index <= process_index + 5'd1;
                    end
                    
                    // Check completion
                    if (process_index >= char_count) begin
                        // If no errors so far, check stack empty
                        if (error_code == ERR_SUCCESS) begin
                            if (stack_ptr == 4'd0) begin
                                result <= 1'b1;
                            end else begin
                                result <= 1'b0;
                                error_code <= ERR_UNMATCHED;
                            end
                        end
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    error_code <= ERR_SUCCESS;
                end
            endcase
        end
    end

endmodule