module pattern_checker (input clk, input rst_n, input start, input [63:0] colors_i, input [63:0] patterns_i, input [2:0] index, input valid, input last, output reg result, output reg done);
reg [1:0] state, next_state;
reg [3:0] num_entries;
reg [63:0] stored_patterns [7:0];
reg [63:0] stored_colors [7:0];
reg conflict_found;
parameter IDLE = 2'b00, COLLECT = 2'b01, VERIFY = 2'b10, COMPLETE = 2'b11;
always @(posedge ~rst_n) begin
    state <= IDLE;
    next_state <= IDLE;
    num_entries <= 4'd0;
    conflict_found <= 1'b0;
    stored_patterns[0] <= 64'b0;
    stored_patterns[1] <= 64'b0;
    stored_patterns[2] <= 64'b0;
    stored_patterns[3] <= 64'b0;
    stored_patterns[4] <= 64'b0;
    stored_patterns[5] <= 64'b0;
    stored_patterns[6] <= 64'b0;
    stored_patterns[7] <= 64'b0;
    stored_colors[0] <= 64'b0;
    stored_colors[1] <= 64'b0;
    stored_colors[2] <= 64'b0;
    stored_colors[3] <= 64'b0;
    stored_colors[4] <= 64'b0;
    stored_colors[5] <= 64'b0;
    stored_colors[6] <= 64'b0;
    stored_colors[7] <= 64'b0;
end
always @(*) begin
    next_state = state;
    case (state)
        IDLE:  
            if (start) next_state = COLLECT;
        COLLECT:  
            if (valid && index < 3'd8) begin
                stored_patterns[num_entries] = patterns_i;
                stored_colors[num_entries] = colors_i;
                num_entries <= num_entries + 1'd1;
                if (num_entries == 4'd8 || last) next_state = VERIFY;
            end
        VERIFY:  
            conflict_found = 1'b0;  
            next_state = COMPLETE;
        COMPLETE:  
            result = conflict_found;
            done = 1'b1;
    endcase
end
always @(posedge clk) state <= next_state;
endmodule