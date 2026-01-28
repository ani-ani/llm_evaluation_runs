module NauuoCards(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] hand_0, hand_1, hand_2, hand_3, hand_4, hand_5, hand_6, hand_7,
    input wire [7:0] pile_0, pile_1, pile_2, pile_3, pile_4, pile_5, pile_6, pile_7,
    output reg [7:0] result,
    output reg done
);

// State machine states
localparam [2:0] IDLE      = 3'd0;
localparam [2:0] CALC_POS  = 3'd1;
localparam [2:0] CHECK_SEQ = 3'd2;
localparam [2:0] CALC_MAX  = 3'd3;
localparam [2:0] FINISH    = 3'd4;

reg [2:0] state, next_state;

// Internal registers
reg [7:0] pos [0:7];  // Position of each card in pile (0 if not in pile)
reg [7:0] max_val;
reg [7:0] i_reg;      // Loop counter (1 to 8)
reg seq_valid;        // Flag for sequential chain validity
reg [7:0] chain_len;  // Length of chain starting from 1
reg [7:0] temp_val;   // Temporary calculation
reg calc_done;        // Flag for calculation completion

// Helper: find position of card in pile
function automatic [7:0] find_position(input [7:0] card);
    begin
        find_position = 0;
        if (pile_0 == card) find_position = 1;
        else if (pile_1 == card) find_position = 2;
        else if (pile_2 == card) find_position = 3;
        else if (pile_3 == card) find_position = 4;
        else if (pile_4 == card) find_position = 5;
        else if (pile_5 == card) find_position = 6;
        else if (pile_6 == card) find_position = 7;
        else if (pile_7 == card) find_position = 8;
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 8'd0;
        done <= 1'b0;
        max_val <= 8'd0;
        i_reg <= 8'd0;
        seq_valid <= 1'b1;
        chain_len <= 8'd0;
        temp_val <= 8'd0;
        calc_done <= 1'b0;
        // Initialize pos array
        pos[0] <= 8'd0;
        pos[1] <= 8'd0;
        pos[2] <= 8'd0;
        pos[3] <= 8'd0;
        pos[4] <= 8'd0;
        pos[5] <= 8'd0;
        pos[6] <= 8'd0;
        pos[7] <= 8'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                calc_done <= 1'b0;
                if (start) begin
                    i_reg <= 8'd1;
                    max_val <= 8'd0;
                    seq_valid <= 1'b1;
                    chain_len <= 8'd0;
                end
            end
            
            CALC_POS: begin
                if (i_reg <= 8) begin
                    // Calculate position for current card
                    pos[i_reg-1] <= find_position(i_reg);
                    i_reg <= i_reg + 8'd1;
                end
            end
            
            CHECK_SEQ: begin
                if (i_reg <= 8) begin
                    // Check if cards form sequential chain starting from 1
                    if (seq_valid && pos[0] == 8'd1 && (i_reg == 8'd1 || pos[i_reg-1] == i_reg)) begin
                        chain_len <= i_reg;
                    end else begin
                        seq_valid <= 1'b0;
                    end
                    i_reg <= i_reg + 8'd1;
                end
            end
            
            CALC_MAX: begin
                if (i_reg <= 8) begin
                    if (pos[i_reg-1] != 8'd0) begin
                        // Calculate pos[i] - i + 1 + 8
                        temp_val <= pos[i_reg-1] - i_reg + 8'd1 + 8'd8;
                        calc_done <= 1'b1;
                    end else begin
                        calc_done <= 1'b1;
                    end
                end
                
                if (calc_done && i_reg <= 8) begin
                    if (pos[i_reg-1] != 8'd0 && temp_val > max_val) begin
                        max_val <= temp_val;
                    end
                    calc_done <= 1'b0;
                    i_reg <= i_reg + 8'd1;
                end
            end
            
            FINISH: begin
                // Determine result based on sequential chain
                if (seq_valid && chain_len > 8'd0) begin
                    result <= 8'd8 - chain_len;  // n - chain_len (where n=8)
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
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = CALC_POS;
            else next_state = IDLE;
        end
        
        CALC_POS: begin
            if (i_reg > 8'd8) next_state = CHECK_SEQ;
            else next_state = CALC_POS;
        end
        
        CHECK_SEQ: begin
            if (i_reg > 8'd8) next_state = CALC_MAX;
            else next_state = CHECK_SEQ;
        end
        
        CALC_MAX: begin
            if (i_reg > 8'd8) next_state = FINISH;
            else next_state = CALC_MAX;
        end
        
        FINISH: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule