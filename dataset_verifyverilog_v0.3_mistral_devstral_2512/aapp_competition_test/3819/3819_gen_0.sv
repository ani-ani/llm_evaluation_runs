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
localparam [1:0] IDLE = 2'd0;
localparam [1:0] CALC_POS = 2'd1;
localparam [1:0] CHECK_SEQ = 2'd2;
localparam [1:0] CALC_MAX = 2'd3;
localparam [1:0] FINISH = 2'd4;

reg [1:0] current_state, next_state;

// Internal registers
reg [7:0] pos [0:7];
reg [7:0] max_val;
reg [7:0] i_reg;
reg [7:0] j_reg;
reg seq_valid;
reg [7:0] chain_len;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        result <= 8'd0;
        done <= 1'b0;
        max_val <= 8'd0;
        i_reg <= 8'd0;
        j_reg <= 8'd0;
        seq_valid <= 1'b0;
        chain_len <= 8'd0;
        
        // Initialize pos array
        integer i;
        for (i = 0; i < 8; i = i + 1) begin
            pos[i] <= 8'd0;
        end
    end else begin
        current_state <= next_state;
        
        case (current_state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    i_reg <= 8'd1;
                    max_val <= 8'd0;
                    seq_valid <= 1'b1;
                    chain_len <= 8'd0;
                end
            end
            
            CALC_POS: begin
                // Calculate position for current card (i_reg)
                if (pile_0 == i_reg) pos[i_reg-1] <= 8'd1;
                else if (pile_1 == i_reg) pos[i_reg-1] <= 8'd2;
                else if (pile_2 == i_reg) pos[i_reg-1] <= 8'd3;
                else if (pile_3 == i_reg) pos[i_reg-1] <= 8'd4;
                else if (pile_4 == i_reg) pos[i_reg-1] <= 8'd5;
                else if (pile_5 == i_reg) pos[i_reg-1] <= 8'd6;
                else if (pile_6 == i_reg) pos[i_reg-1] <= 8'd7;
                else if (pile_7 == i_reg) pos[i_reg-1] <= 8'd8;
                else pos[i_reg-1] <= 8'd0;
                
                i_reg <= i_reg + 8'd1;
            end
            
            CHECK_SEQ: begin
                // Check if cards form sequential chain
                if (i_reg <= 8'd8 && pos[i_reg-1] != 8'd0 && pos[i_reg-1] == i_reg) begin
                    chain_len <= i_reg;
                end else begin
                    seq_valid <= 1'b0;
                end
                i_reg <= i_reg + 8'd1;
            end
            
            CALC_MAX: begin
                // Calculate max(pos[i] - i + 1 + 8)
                if (i_reg <= 8'd8 && pos[i_reg-1] != 8'd0) begin
                    reg [7:0] val = pos[i_reg-1] - i_reg + 8'd1 + 8'd8;
                    if (val > max_val) max_val <= val;
                end
                i_reg <= i_reg + 8'd1;
            end
            
            FINISH: begin
                // Determine result based on sequential chain
                if (seq_valid && chain_len > 8'd0) begin
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