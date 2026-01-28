module quote_extractor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] str,
    input wire [5:0] str_len,
    output reg [255:0] result,
    output reg [3:0] result_len,
    output reg done,
    output reg error
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SCAN    = 2'd1;
    localparam [1:0] CAPTURE = 2'd2;
    localparam [1:0] ERROR   = 2'd3;

    reg [1:0] state, next_state;

    // Control signals
    reg [5:0] index;
    reg in_quote;
    reg [5:0] token_count;
    reg [5:0] token_start_index;
    reg [5:0] token_char_count;
    reg [5:0] current_token_index;

    // Token buffer (8 bytes per token, 4 tokens max)
    reg [7:0] token_buffer [0:31]; // 4 tokens * 8 bytes = 32 bytes

    // Cycle counter for timeout
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;

    // Character comparison
    wire quote_detected = (str[index*8 +: 8] == 8'h22);

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 256'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            error <= 1'b0;
            index <= 6'd0;
            in_quote <= 1'b0;
            token_count <= 6'd0;
            token_start_index <= 6'd0;
            token_char_count <= 6'd0;
            current_token_index <= 6'd0;
            cycle_count <= 7'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 7'd0;
                    
                    if (start) begin
                        // Initialize all registers
                        index <= 6'd0;
                        in_quote <= 1'b0;
                        token_count <= 6'd0;
                        token_start_index <= 6'd0;
                        token_char_count <= 6'd0;
                        current_token_index <= 6'd0;
                        
                        // Clear token buffer
                        integer i;
                        for (i = 0; i < 32; i = i + 1) begin
                            token_buffer[i] <= 8'd0;
                        end
                        
                        next_state <= SCAN;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= ERROR;
                    end else if (index >= str_len) begin
                        // End of string
                        if (in_quote) begin
                            // Unbalanced quotes
                            next_state <= ERROR;
                        end else begin
                            next_state <= CAPTURE;
                        end
                    end else begin
                        // Process current character
                        if (quote_detected) begin
                            in_quote <= ~in_quote;
                            
                            if (!in_quote) begin
                                // End of quote - finalize token
                                if (token_char_count > 0) begin
                                    if (token_count < 4'd4) begin
                                        // Copy token to buffer
                                        integer i;
                                        for (i = 0; i < token_char_count; i = i + 1) begin
                                            token_buffer[current_token_index + i] <= str[(token_start_index + i)*8 +: 8];
                                        end
                                        
                                        token_count <= token_count + 6'd1;
                                        current_token_index <= current_token_index + 6'd8;
                                    end else begin
                                        next_state <= ERROR;
                                    end
                                end
                            end else begin
                                // Start of quote
                                token_start_index <= index + 6'd1;
                                token_char_count <= 6'd0;
                            end
                        end else if (in_quote) begin
                            // Inside quotes - accumulate character
                            if (token_char_count < 6'd8) begin
                                token_char_count <= token_char_count + 6'd1;
                            end else begin
                                // Token too long
                                next_state <= ERROR;
                            end
                        end
                        
                        index <= index + 6'd1;
                    end
                end

                CAPTURE: begin
                    // Pack tokens into result
                    integer i, j;
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if ((i*8 + j) < token_count*8) begin
                                result[(i*64) + (7-j)*8 +: 8] <= token_buffer[i*8 + j];
                            end else begin
                                result[(i*64) + (7-j)*8 +: 8] <= 8'd0;
                            end
                        end
                    end
                    
                    result_len <= token_count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                ERROR: begin
                    error <= 1'b1;
                    next_state <= ERROR;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule