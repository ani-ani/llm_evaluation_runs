module yahtzee_solver (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_rolls,
    input [2:0] dice_in [0:64],
    output reg [11:0] max_score,
    output reg done
);

reg [2:0] state;
reg [12:0] total_score;
reg [4:0] count;
reg done_reg;

assign done = done_reg;
assign max_score = total_score;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
        total_score <= 0;
        count <= 0;
        done_reg <= 0;
    end else begin
        case (state)
            0: // IDLE
                if (start) state <= 1;
            1: // COMPUTING
                count <= count + 1;
                if (count >= 2000) begin
                    state <= 2;
                    done_reg <= 1;
                end
            2: // DONE
                ; // stay
        endcase
    end
end

endmodule