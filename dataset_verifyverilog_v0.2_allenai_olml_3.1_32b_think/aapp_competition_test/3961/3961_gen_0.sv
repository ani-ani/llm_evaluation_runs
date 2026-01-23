module maze_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] p_i,
    input [2:0] current_room_index,
    output reg [31:0] total_moves,
    output reg done
);

reg [31:0] f_array [0:8];
reg [2:0] target_index;
reg [2:0] i_count;
reg state;
localparam IDLE = 3'd0, CALC = 3'd1, DONE = 3'd2;

localparam MOD = 1000000007;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        f_array <= {32{0}};
        target_index <= 3'd0;
        i_count <= 3'd0;
        state <= IDLE;
        done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                target_index <= current_room_index;
                i_count <= 3'd1;
                state <= CALC;
            end
        end else if (state == CALC) begin
            if (i_count > target_index) begin
                total_moves <= f_array[target_index];
                done <= 1'b1;
                state <= DONE;
            end else begin
                reg [31:0] p_room = p_i;
                reg [31:0] new_val;
                if (p_room == i_count) begin
                    new_val = f_array[i_count - 1] + 2;
                end else begin
                    reg [31:0] temp = 2 + 2 * f_array[i_count - 1] - f_array[p_room - 1];
                    temp = (temp % MOD + MOD) % MOD;
                    new_val = temp;
                end
                reg [31:0] f_array_next [0:8];
                f_array_next[0] = f_array[0];
                f_array_next[1] = f_array[1];
                f_array_next[2] = f_array[2];
                f_array_next[3] = f_array[3];
                f_array_next[4] = f_array[4];
                f_array_next[5] = f_array[5];
                f_array_next[6] = f_array[6];
                f_array_next[7] = f_array[7];
                f_array_next[8] = f_array[8];
                f_array_next[i_count] = new_val;
                f_array <= f_array_next;
                i_count <= i_count + 1;
            end
        end else if (state == DONE) begin
        end
    end
endmodule