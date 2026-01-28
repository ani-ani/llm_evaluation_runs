module NauuoCards(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] hand_0, hand_1, hand_2, hand_3, hand_4, hand_5, hand_6, hand_7,
    input wire [7:0] pile_0, pile_1, pile_2, pile_3, pile_4, pile_5, pile_6, pile_7,
    output reg [7:0] result,
    output reg done
);
    
    // State declaration
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_POS  = 3'd1;
    localparam [2:0] CHECK_SEQ = 3'd2;
    localparam [2:0] CALC_MAX  = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    reg [2:0] current_state, next_state;
    reg [7:0] pos [0:7];  // Card positions (pos[0] = card1 position)
    reg [7:0] max_val;
    reg [7:0] chain_len;
    reg seq_valid;
    
    // Loop counters
    reg [3:0] i_reg;
    
    // Position lookup function
    function automatic [7:0] find_pos(input [7:0] card);
        begin
            if (card == pile_0) find_pos = 8'd1;
            else if (card == pile_1) find_pos = 8'd2;
            else if (card == pile_2) find_pos = 8'd3;
            else if (card == pile_3) find_pos = 8'd4;
            else if (card == pile_4) find_pos = 8'd5;
            else if (card == pile_5) find_pos = 8'd6;
            else if (card == pile_6) find_pos = 8'd7;
            else if (card == pile_7) find_pos = 8'd8;
            else find_pos = 8'd0;
        end
    endfunction
    
    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        integer idx;
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            max_val <= 8'd0;
            chain_len <= 8'd0;
            seq_valid <= 1'b0;
            i_reg <= 4'd0;
            // Initialize position array
            for (idx = 0; idx < 8; idx = idx + 1) begin
                pos[idx] <= 8'd0;
            end
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i_reg <= 4'd1;
                        seq_valid <= 1'b1;
                        chain_len <= 8'd0;
                    end
                end
                
                CALC_POS: begin
                    if (i_reg <= 4'd8) begin
                        // Find position for card i_reg (hand_{i_reg-1})
                        case (i_reg)
                            1: pos[0] <= find_pos(hand_0);
                            2: pos[1] <= find_pos(hand_1);
                            3: pos[2] <= find_pos(hand_2);
                            4: pos[3] <= find_pos(hand_3);
                            5: pos[4] <= find_pos(hand_4);
                            6: pos[5] <= find_pos(hand_5);
                            7: pos[6] <= find_pos(hand_6);
                            8: pos[7] <= find_pos(hand_7);
                        endcase
                        i_reg <= i_reg + 4'd1;
                    end
                end
                
                CHECK_SEQ: begin
                    if (i_reg <= 4'd8) begin
                        // Skip if card not in pile
                        if (pos[i_reg-4'd1] != 8'd0) begin
                            // First valid card starts the chain
                            if (chain_len == 8'd0) begin
                                chain_len <= 8'd1;
                            end else if (pos[i_reg-4'd1] == (pos[i_reg-4'd2] + 8'd1)) begin
                                chain_len <= chain_len + 8'd1;
                            end else begin
                                seq_valid <= 1'b0;
                            end
                        end
                        i_reg <= i_reg + 4'd1;
                    end
                end
                
                CALC_MAX: begin
                    if (i_reg <= 4'd8) begin
                        if (pos[i_reg-4'd1] != 8'd0) begin
                            // pos[i] - i + 1 + 8 = pos[i] - (i-1) + 8
                            begin
                                reg [7:0] temp_val;
                                temp_val = pos[i_reg-4'd1] - (i_reg - 4'd1) + 8'd8;
                                if (temp_val > max_val) max_val <= temp_val;
                            end
                        end
                        i_reg <= i_reg + 4'd1;
                    end
                end
                
                FINISH: begin
                    if (seq_valid && (chain_len > 8'd0)) begin
                        result <= 8'd8 - chain_len;
                    end else begin
                        result <= max_val;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = CALC_POS;
            end
            
            CALC_POS: begin
                if (i_reg > 4'd8) next_state = CHECK_SEQ;
            end
            
            CHECK_SEQ: begin
                if (i_reg > 4'd8) next_state = CALC_MAX;
            end
            
            CALC_MAX: begin
                if (i_reg > 4'd8) next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
endmodule