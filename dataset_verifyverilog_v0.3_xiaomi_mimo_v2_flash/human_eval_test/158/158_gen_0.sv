module find_max (
    input clk,
    input rst_n,
    input start,
    input [7:0] strings [0:3][0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COUNTING  = 2'd1;
    localparam [1:0] COMPARING = 2'd2;
    localparam [1:0] DONE      = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] str_idx;          // Index 0-3 for string selection
    reg [3:0] char_idx;         // Index 0-7 for character scanning
    reg [3:0] unique_count [0:3]; // Stores unique count for each string
    reg [31:0] packed_str [0:3];  // Packed 32-bit representation for lex comparison
    reg [31:0] best_packed;       // Winner's packed string
    reg [2:0] best_idx;           // Winner's index
    reg [3:0] max_unique;         // Current maximum unique count found
    
    // Temporary storage for character comparison
    reg found;
    reg [7:0] current_char;
    reg [31:0] current_packed;
    
    // Loop counters for initialization
    reg [2:0] init_idx;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            str_idx <= 3'd0;
            char_idx <= 4'd0;
            max_unique <= 4'd0;
            best_idx <= 3'd0;
            best_packed <= 32'd0;
            found <= 1'b0;
            current_char <= 8'd0;
            current_packed <= 32'd0;
            init_idx <= 3'd0;
            
            // Initialize arrays
            unique_count[0] <= 4'd0;
            unique_count[1] <= 4'd0;
            unique_count[2] <= 4'd0;
            unique_count[3] <= 4'd0;
            
            packed_str[0] <= 32'd0;
            packed_str[1] <= 32'd0;
            packed_str[2] <= 32'd0;
            packed_str[3] <= 32'd0;
            
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
            
        end else begin
            
            case (state)
                
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize processing variables
                        str_idx <= 3'd0;
                        char_idx <= 4'd0;
                        max_unique <= 4'd0;
                        best_idx <= 3'd0;
                        best_packed <= 32'd0;
                        found <= 1'b0;
                        current_char <= 8'd0;
                        current_packed <= 32'd0;
                        // Reset counts
                        unique_count[0] <= 4'd0;
                        unique_count[1] <= 4'd0;
                        unique_count[2] <= 4'd0;
                        unique_count[3] <= 4'd0;
                        // Pack strings for later comparison
                        packed_str[0] <= {strings[0][7], strings[0][6], strings[0][5], strings[0][4],
                                          strings[0][3], strings[0][2], strings[0][1], strings[0][0]};
                        packed_str[1] <= {strings[1][7], strings[1][6], strings[1][5], strings[1][4],
                                          strings[1][3], strings[1][2], strings[1][1], strings[1][0]};
                        packed_str[2] <= {strings[2][7], strings[2][6], strings[2][5], strings[2][4],
                                          strings[2][3], strings[2][2], strings[2][1], strings[2][0]};
                        packed_str[3] <= {strings[3][7], strings[3][6], strings[3][5], strings[3][4],
                                          strings[3][3], strings[3][2], strings[3][1], strings[3][0]};
                        
                        next_state <= COUNTING;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COUNTING: begin
                    // Process current string (str_idx)
                    // Get current character
                    current_char <= strings[str_idx][char_idx];
                    
                    if (char_idx == 4'd0) begin
                        // First character, always unique if not null
                        if (strings[str_idx][0] != 8'd0) begin
                            unique_count[str_idx] <= 4'd1;
                        end else begin
                            unique_count[str_idx] <= 4'd0;
                        end
                        char_idx <= char_idx + 4'd1;
                        found <= 1'b0;
                    end else begin
                        // Compare current character with previous ones
                        if (strings[str_idx][char_idx] == 8'd0) begin
                            // Null character, skip
                            char_idx <= char_idx + 4'd1;
                            found <= 1'b0;
                        end else begin
                            // Check if unique among 0 to char_idx-1
                            if (!found) begin
                                if (char_idx <= 8'd7) begin
                                    // Simple linear search (unrolled for efficiency)
                                    // Note: This logic runs in parallel for all characters due to combinational nature
                                    // We implement sequential check within this clock cycle
                                    // For hardware simplicity, we use a flag to indicate checking
                                    if (char_idx == 4'd1 && strings[str_idx][0] == strings[str_idx][1]) begin
                                        found <= 1'b1;
                                    end else if (char_idx == 4'd2 && 
                                        (strings[str_idx][0] == strings[str_idx][2] || strings[str_idx][1] == strings[str_idx][2])) begin
                                        found <= 1'b1;
                                    end else if (char_idx == 4'd3 && 
                                        (strings[str_idx][0] == strings[str_idx][3] || strings[str_idx][1] == strings[str_idx][3] || strings[str_idx][2] == strings[str_idx][3])) begin
                                        found <= 1'b1;
                                    end else if (char_idx == 4'd4 && 
                                        (strings[str_idx][0] == strings[str_idx][4] || strings[str_idx][1] == strings[str_idx][4] || strings[str_idx][2] == strings[str_idx][4] || strings[str_idx][3] == strings[str_idx][4])) begin
                                        found <= 1'b1;
                                    end else if (char_idx == 4'd5 && 
                                        (strings[str_idx][0] == strings[str_idx][5] || strings[str_idx][1] == strings[str_idx][5] || strings[str_idx][2] == strings[str_idx][5] || strings[str_idx][3] == strings[str_idx][5] || strings[str_idx][4] == strings[str_idx][5])) begin
                                        found <= 1'b1;
                                    end else if (char_idx == 4'd6 && 
                                        (strings[str_idx][0] == strings[str_idx][6] || strings[str_idx][1] == strings[str_idx][6] || strings[str_idx][2] == strings[str_idx][6] || strings[str_idx][3] == strings[str_idx][6] || strings[str_idx][4] == strings[str_idx][6] || strings[str_idx][5] == strings[str_idx][6])) begin
                                        found <= 1'b1;
                                    end else if (char_idx == 4'd7 && 
                                        (strings[str_idx][0] == strings[str_idx][7] || strings[str_idx][1] == strings[str_idx][7] || strings[str_idx][2] == strings[str_idx][7] || strings[str_idx][3] == strings[str_idx][7] || strings[str_idx][4] == strings[str_idx][7] || strings[str_idx][5] == strings[str_idx][7] || strings[str_idx][6] == strings[str_idx][7])) begin
                                        found <= 1'b1;
                                    end
                                end
                            end
                            
                            // Increment char_idx
                            if (char_idx < 4'd7) begin
                                char_idx <= char_idx + 4'd1;
                            end else begin
                                char_idx <= 4'd0;
                                str_idx <= str_idx + 3'd1;
                                if (str_idx == 3'd3) begin
                                    next_state <= COMPARING;
                                end else begin
                                    next_state <= COUNTING;
                                end
                            end
                            
                            // Update count if not found
                            if (!found && char_idx < 4'd7) begin
                                unique_count[str_idx] <= unique_count[str_idx] + 4'd1;
                            end
                        end
                    end
                end
                
                COMPARING: begin
                    // Compare unique_count[str_idx] with max_unique
                    // str_idx iterates 0 to 3
                    if (str_idx <= 3'd3) begin
                        if (unique_count[str_idx] > max_unique) begin
                            // New maximum found
                            max_unique <= unique_count[str_idx];
                            best_idx <= str_idx;
                            best_packed <= packed_str[str_idx];
                        end else if (unique_count[str_idx] == max_unique) begin
                            // Tie break: lexicographical order (packed integer comparison)
                            if (packed_str[str_idx] < best_packed) begin
                                best_idx <= str_idx;
                                best_packed <= packed_str[str_idx];
                            end
                        end
                        
                        if (str_idx < 3'd3) begin
                            str_idx <= str_idx + 3'd1;
                            next_state <= COMPARING;
                        end else begin
                            next_state <= DONE;
                        end
                    end else begin
                        next_state <= DONE;
                    end
                end
                
                DONE: begin
                    // Output the winning string
                    result[0] <= strings[best_idx][0];
                    result[1] <= strings[best_idx][1];
                    result[2] <= strings[best_idx][2];
                    result[3] <= strings[best_idx][3];
                    result[4] <= strings[best_idx][4];
                    result[5] <= strings[best_idx][5];
                    result[6] <= strings[best_idx][6];
                    result[7] <= strings[best_idx][7];
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
                
            endcase
        end
    end

endmodule