module dance_arrows(input clk, input rst_n, input start, input [3:0] N, input [31:0] K, input [4:0] a [0:15], output reg [4:0] result [0:15], output reg done, output reg impossible);
reg [2:0] state, next_state;
reg [3:0] N_val;
reg [31:0] K_val;
reg [4:0] a_reg [0:15];
reg [6:0] delay_counter;
reg [4:0] result_reg [0:15];
reg done_reg, impossible_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'd0;
        N_val <= 4'd0;
        K_val <= 32'd0;
        a_reg <= 16'b0;
        delay_counter <= 7'd0;
        result_reg <= 16'b0;
        done_reg <= 1'b0;
        impossible_reg <= 1'b0;
    end else begin
        case (state)
            3'd0: begin
                if (start) begin
                    next_state = 1;
                end else begin
                    next_state = 0;
                end
            end
            1: begin
                N_val <= N;
                K_val <= K;
                a_reg <= a;
                impossible_reg <= 1'b0;
                next_state = 2;
            end
            2: next_state = 3;
            3: next_state = 4;
            4: begin
                if (impossible_reg == 1'b0) begin
                    next_state = 5;
                    delay_counter <= 100;
                end else begin
                    next_state = 5;
                end
            end
            5: begin
                if (delay_counter == 0) begin
                    done_reg <= 1'b1;
                end else if (delay_counter > 0) begin
                    delay_counter <= delay_counter - 1;
                end
                next_state = 5;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;
assign impossible = impossible_reg;

endmodule