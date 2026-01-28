module z_word_detector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],
    input wire [4:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SCAN     = 3'd1;
    localparam [2:0] CHECK_Z  = 3'd2;
    localparam [2:0] UPDATE   = 3'd3;
    localparam [2:0] FINISH   = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Registers for scanning
    reg [4:0] index;
    reg in_word;
    reg found_z;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;
    
    // Helper function to check if character is alphanumeric
    function automatic is_alnum(input [7:0] ch);
        begin
            is_alnum = 0;
            // Check uppercase letters A-Z (65-90)
            if ((ch >= 8'd65) && (ch <= 8'd90))
                is_alnum = 1;
            // Check lowercase letters a-z (97-122)
            if ((ch >= 8'd97) && (ch <= 8'd122))
                is_alnum = 1;
            // Check digits 0-9 (48-57)
            if ((ch >= 8'd48) && (ch <= 8'd57))
                is_alnum = 1;
        end
    endfunction
    
    // Combinational next state logic
    always @(*) begin
        next_state = state; // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN;
            end
            
            SCAN: begin
                if (index >= len)
                    next_state = FINISH;
                else
                    next_state = CHECK_Z;
            end
            
            CHECK_Z: begin
                // If current char is 'z' (122) and we're in a word
                if ((str[index] == 8'd122) && in_word) begin
                    next_state = UPDATE;
                end else begin
                    next_state = UPDATE;
                end
            end
            
            UPDATE: begin
                // After processing current character
                next_state = SCAN;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential state update and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 5'd0;
            in_word <= 1'b0;
            found_z <= 1'b0;
            cycle_count <= 5'd0;
        end else begin
            state <= next_state;
            
            // Increment cycle count (prevent infinite loops)
            cycle_count <= cycle_count + 5'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    index <= 5'd0;
                    in_word <= 1'b0;
                    found_z <= 1'b0;
                    cycle_count <= 5'd0;
                end
                
                SCAN: begin
                    // Just waiting for next processing step
                end
                
                CHECK_Z: begin
                    // Check if current character changes word state
                    if (is_alnum(str[index])) begin
                        in_word <= 1'b1;
                        if (str[index] == 8'd122)
                            found_z <= 1'b1;
                    end else begin
                        in_word <= 1'b0;
                    end
                end
                
                UPDATE: begin
                    // Move to next character
                    index <= index + 5'd1;
                end
                
                FINISH: begin
                    result <= found_z;
                    done <= 1'b1;
                    // Return to idle automatically
                    index <= 5'd0;
                    in_word <= 1'b0;
                    found_z <= 1'b0;
                    cycle_count <= 5'd0;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule