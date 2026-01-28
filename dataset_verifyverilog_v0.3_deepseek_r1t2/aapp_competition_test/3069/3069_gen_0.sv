module bracket_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] brackets,
    input [2:0] length,
    output reg possible,
    output reg done
);
    
    // State declarations
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] CHECK_ORIG   = 4'd1;
    localparam [3:0] SETUP_SEG    = 4'd2;
    localparam [3:0] CHECK_SEG    = 4'd3;
    localparam [3:0] LOOP_I       = 4'd4;
    localparam [3:0] NEXT_I       = 4'd5;
    localparam [3:0] ORIG_DONE    = 4'd6;
    localparam [3:0] SEGMENT_DONE = 4'd7;
    localparam [3:0] NEXT_R       = 4'd8;
    localparam [3:0] NEXT_L       = 4'd9;
    localparam [3:0] DONE_STATE   = 4'd10;
    
    reg [3:0] state;
    
    // Data registers
    reg [7:0] brackets_reg;
    reg [2:0] length_reg;
    reg [2:0] l;
    reg [2:0] r;
    reg [2:0] i;
    reg signed [4:0] cnt;
    reg invalid;
    reg found;
    reg invert_enable;
    reg check_orig;
    
    // Current bracket logic
    wire [2:0] i_val = i;
    wire current_bracket_raw = (i_val < length_reg) ? brackets_reg[i_val] : 1'b0;
    wire invert_flag = invert_enable && (i_val >= l) && (i_val <= r);
    wire current_bracket = invert_flag ? ~current_bracket_raw : current_bracket_raw;
    
    // Counter update logic
    wire signed [4:0] next_cnt = current_bracket ? cnt + 5'sd1 : cnt - 5'sd1;
    wire next_invalid = invalid || (next_cnt < 5'sd0);
    
    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            possible <= 1'b0;
            done <= 1'b0;
            brackets_reg <= 8'd0;
            length_reg <= 3'd0;
            l <= 3'd0;
            r <= 3'd0;
            i <= 3'd0;
            cnt <= 5'sd0;
            invalid <= 1'b0;
            found <= 1'b0;
            invert_enable <= 1'b0;
            check_orig <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        brackets_reg <= brackets;
                        length_reg <= length;
                        found <= 1'b0;
                        state <= CHECK_ORIG;
                    end
                end
                
                CHECK_ORIG: begin
                    invert_enable <= 1'b0;
                    check_orig <= 1'b1;
                    i <= 3'd0;
                    cnt <= 5'sd0;
                    invalid <= 1'b0;
                    state <= LOOP_I;
                end
                
                SETUP_SEG: begin
                    check_orig <= 1'b0;
                    l <= 3'd0;
                    r <= 3'd0;
                    state <= CHECK_SEG;
                end
                
                CHECK_SEG: begin
                    invert_enable <= 1'b1;
                    i <= 3'd0;
                    cnt <= 5'sd0;
                    invalid <= 1'b0;
                    state <= LOOP_I;
                end
                
                LOOP_I: begin
                    cnt <= next_cnt;
                    invalid <= next_invalid;
                    state <= NEXT_I;
                end
                
                NEXT_I: begin
                    i <= i + 3'd1;
                    if (i + 3'd1 < length_reg) begin
                        state <= LOOP_I;
                    end else begin
                        state <= (check_orig) ? ORIG_DONE : SEGMENT_DONE;
                    end
                end
                
                ORIG_DONE: begin
                    if (!invalid && (cnt == 5'sd0)) begin
                        found <= 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        state <= SETUP_SEG;
                    end
                end
                
                SEGMENT_DONE: begin
                    if (!invalid && (cnt == 5'sd0)) begin
                        found <= 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        state <= NEXT_R;
                    end
                end
                
                NEXT_R: begin
                    if (r + 3'd1 < length_reg) begin
                        r <= r + 3'd1;
                        state <= CHECK_SEG;
                    end else begin
                        state <= NEXT_L;
                    end
                end
                
                NEXT_L: begin
                    if (l + 3'd1 < length_reg) begin
                        l <= l + 3'd1;
                        r <= l + 3'd1;
                        state <= CHECK_SEG;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    possible <= found;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule