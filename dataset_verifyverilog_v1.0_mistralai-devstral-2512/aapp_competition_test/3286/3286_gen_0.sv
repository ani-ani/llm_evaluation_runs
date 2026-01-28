module robber_language(
    input clk,
    input rst_n,
    input start,
    input [4:0] len,
    input [127:0] str,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // DP state
    reg [23:0] dp_prev;
    reg [23:0] dp_curr;
    reg [23:0] dp_next;
    
    reg [4:0] i;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg [7:0] next_next_char;
    
    reg is_vowel;
    reg is_consonant;
    reg is_valid;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 5'd0;
            dp_prev <= 24'd0;
            dp_curr <= 24'd0;
            dp_next <= 24'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        i <= 5'd0;
                        dp_prev <= 24'd1;  // Base case: empty string has 1 way
                        dp_curr <= 24'd0;
                        dp_next <= 24'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all characters
                    if (i >= len) begin
                        state <= FINISH;
                        result <= dp_prev;
                    end else begin
                        // Extract current character
                        current_char <= str[(i*8)+7 : i*8];
                        
                        // Check if current character is a vowel
                        is_vowel <= (current_char == 8'd97) ||  // 'a'
                                    (current_char == 8'd101) || // 'e'
                                    (current_char == 8'd105) || // 'i'
                                    (current_char == 8'd111) || // 'o'
                                    (current_char == 8'd117);  // 'u'
                        
                        is_consonant <= !is_vowel && (current_char >= 8'd97) && (current_char <= 8'd122);
                        
                        // Check if we can take 1 character (vowel or consonant)
                        if (is_vowel || is_consonant) begin
                            dp_curr <= dp_prev;
                        end else begin
                            dp_curr <= 24'd0;
                        end
                        
                        // Check if we can take 3 characters (consonant transformation)
                        if (i + 3'd2 < len) begin
                            next_char <= str[((i+1)*8)+7 : (i+1)*8];
                            next_next_char <= str[((i+2)*8)+7 : (i+2)*8];
                            
                            is_valid <= is_consonant && (next_char == 8'd111) && (next_next_char == current_char);
                            
                            if (is_valid) begin
                                dp_curr <= (dp_curr + dp_prev) % 24'd1000009;
                            end
                        end
                        
                        // Move to next position
                        dp_prev <= dp_curr;
                        i <= i + 5'd1;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= dp_prev;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule