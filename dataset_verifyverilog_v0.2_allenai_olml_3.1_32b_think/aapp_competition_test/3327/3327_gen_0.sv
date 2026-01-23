module crossword_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_in [0:7][0:7],
    input [7:0] word_list [0:15][0:7],
    input [3:0] num_words,
    input [2:0] grid_width,
    input [2:0] grid_height,
    output reg [7:0] grid_out [0:7][0:7],
    output reg done
);

reg [2:0] state;

reg [3:0] current_word_idx;

reg [2:0] current_row; 
reg [2:0] current_col;

reg [1:0] direction; 
reg [7:0] grid_reg [0:7][0:7];

always @(*) begin
    grid_out <= grid_reg;
    done = 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'd0; // IDLE
        current_word_idx <= 0;
        current_row <= 0;
        current_col <= 0;
        direction <= 2'd0; // horizontal
        for (int i=0; i<8; i=i+1)
            for (int j=0; j<8; j=j+1)
                grid_reg[i][j] <= grid_in[i][j];
    end else begin
        case (state)
            3'd0: // IDLE
                if (start) begin
                    state <= 3'd1; // PLACE_WORD
                    current_word_idx <= 0;
                    current_row <= 0;
                    current_col <= 0;
                    direction <= 2'd0;
                end
            3'd1: // PLACE_WORD
                state <= 3'd2; // CHECK_SOLUTION
            3'd2: // CHECK_SOLUTION
                if (current_word_idx == num_words) begin
                    done <= 1;
                    state <= 3'd3; // DONE
                end else begin
                    current_word_idx <= current_word_idx +1;
                    state <= 3'd1;
                end
            3'd3: // DONE
                state <= 3'd3;
        endcase
    end
end

endmodule