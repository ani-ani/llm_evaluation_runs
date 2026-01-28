module char_replace(
    input clk,
    input rst_n,
    input start,
    input [7:0] str_in [0:7],
    input [7:0] old_char,
    input [7:0] new_char,
    output reg [7:0] str_out [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] char_index;
    reg [7:0] current_char;
    reg [7:0] internal_str [0:7];
    reg char_match;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            char_index <= 3'd0;
            current_char <= 8'd0;
            char_match <= 1'b0;
            done <= 1'b0;
            
            // Initialize output and internal arrays
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                str_out[i] <= 8'd0;
                internal_str[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture input string
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            internal_str[i] <= str_in[i];
                        end
                        next_state <= PROCESSING;
                        char_index <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESSING: begin
                    // Process current character
                    current_char <= internal_str[char_index];
                    char_match <= (current_char == old_char);
                    
                    // Store result
                    if (char_match)
                        str_out[char_index] <= new_char;
                    else
                        str_out[char_index] <= current_char;
                    
                    // Move to next character or finish
                    if (char_index == 3'd7) begin
                        next_state <= DONE_STATE;
                    end else begin
                        char_index <= char_index + 3'd1;
                        next_state <= PROCESSING;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule