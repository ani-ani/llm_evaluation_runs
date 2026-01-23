module pirate_chest_solver (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [15:0] coins [0:14],
    output reg [15:0] result,
    output reg done
);

reg [15:0] current_coins [0:14];
reg [15:0] moves_counter;
reg [3:0] current_i;
reg [2:0] state;

always @(*) begin
    current_coins[0:14] = 0;
    moves_counter = 0;
    current_i = 0;
    state = 0;
    result = 0;
    done = 0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        current_coins[0:14] <= 0;
        moves_counter <= 0;
        current_i <= 0;
        state <= 0;
        result <= 0;
        done <= 0;
    end else begin
        case (state)
            0: begin
                if (start) begin
                    state <= 1;
                end else begin
                    state <= 0;
                end
            end
            1: begin
                if (n == 1 || (n & 1) == 0) begin
                    result <= -1;
                    done <= 1;
                    state <= 4;
                end else begin
                    current_coins[0] <= coins[0];
                    current_coins[1] <= coins[1];
                    current_coins[2] <= coins[2];
                    current_coins[3] <= coins[3];
                    current_coins[4] <= coins[4];
                    current_coins[5] <= coins[5];
                    current_coins[6] <= coins[6];
                    current_coins[7] <= coins[7];
                    current_coins[8] <= coins[8];
                    current_coins[9] <= coins[9];
                    current_coins[10] <= coins[10];
                    current_coins[11] <= coins[11];
                    current_coins[12] <= coins[12];
                    current_coins[13] <= coins[13];
                    current_coins[14] <= coins[14];
                    current_i <= n;
                    moves_counter <= 0;
                    state <= 2;
                end
            end
            2: begin
                if (current_i > 0) begin
                    if (current_coins[current_i -1] > 0) begin
                        moves_counter <= moves_counter + current_coins[current_i -1];
                        if (current_i > 1) begin
                            current_coins[(current_i >> 1) - 1] <= current_coins[(current_i >> 1) - 1] >= current_coins[current_i - 1] ? current_coins[(current_i >> 1) - 1] - current_coins[current_i - 1] : 0;
                        end
                        if (current_i & 1) begin
                            if (current_i > 1) begin
                                current_coins[current_i - 2] <= current_coins[current_i - 2] - current_coins[current_i - 1];
                            end
                        end
                        current_coins[current_i - 1] <= 0;
                        current_i <= current_i - 1;
                        state <= 2;
                    end else begin
                        current_i <= current_i - 1;
                        state <= 2;
                    end
                end else begin
                    state <= 3;
                end
            end
            3: begin
                result <= moves_counter;
                done <= 1;
                state <= 4;
            end
            4: begin
                state <= 4;
            end
        endcase
    end
end
endmodule