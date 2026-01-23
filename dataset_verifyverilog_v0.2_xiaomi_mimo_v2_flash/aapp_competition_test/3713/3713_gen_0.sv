module hack_cows (
    input clk,
    input rst_n,
    input start,
    input [3:0] str_len,
    input [15:0] binary_string,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam SCAN_STRING = 2'b01;
    localparam CALCULATE_RESULT = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state, next_state;
    reg [3:0] index; // Iteration index (0 to 14)
    reg [7:0] transitions_reg;
    reg [7:0] adj_dups_reg;
    reg [3:0] str_len_d1;

    // State Transition and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            result <= 8'b0;
            index <= 4'd0;
            transitions_reg <= 8'd0;
            adj_dups_reg <= 8'd0;
            str_len_d1 <= 4'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'b0;
                    index <= 4'd0;
                    transitions_reg <= 8'd0;
                    adj_dups_reg <= 8'd0;
                    if (start) begin
                        current_state <= SCAN_STRING;
                        str_len_d1 <= str_len;
                        // Check first pair immediately for the very first bit
                        // We start at index 0, checking bit 0 vs 1
                    end
                end

                SCAN_STRING: begin
                    // We iterate index from 0 up to str_len-2 (max 14)
                    if (index < str_len_d1 - 1) begin
                        // Compare bit 'index' and 'index+1'
                        // binary_string is LSB first (bit 0 is s[0])
                        if (binary_string[index] == binary_string[index + 1]) begin
                            adj_dups_reg <= adj_dups_reg + 1;
                        end else begin
                            transitions_reg <= transitions_reg + 1;
                        end
                        index <= index + 1;
                    end else begin
                        // Scanning complete
                        current_state <= CALCULATE_RESULT;
                    end
                end

                CALCULATE_RESULT: begin
                    // Logic: LAS = transitions + 1
                    // Add min(2, adj_dups)
                    // transitions_reg holds count of s[i] != s[i+1]
                    // adj_dups_reg holds count of s[i] == s[i+1]
                    
                    // Calculate additions
                    if (adj_dups_reg >= 2) begin
                        result <= (transitions_reg + 1) + 2;
                    end else if (adj_dups_reg == 1) begin
                        result <= (transitions_reg + 1) + 1;
                    end else begin
                        result <= (transitions_reg + 1);
                    end
                    
                    current_state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for reset or new start
                    if (!start) begin
                        // Stay here until start goes low is handled by transition logic usually
                        // To be safe, we stay in DONE until reset or start re-assertion cycle
                    end
                    // If start is deasserted, we can transition to IDLE to be ready for next trigger
                    if (!start) begin
                        current_state <= IDLE;
                    end
                end
                
                default: current_state <= IDLE;
            endcase
        end
    end

endmodule