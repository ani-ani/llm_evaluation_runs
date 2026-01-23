module triple_sum_counter (
input clk,
input rst_n, // active-low reset
input start,
input [4:0] n,
input [15:0] arr [0:7],
output reg [31:0] count,
output reg done
);

// Registers
reg [2:0] state;
reg [4:0] saved_n;
reg [31:0] total_iterations;
reg [31:0] counter;
reg [31:0] cnt_reg;
reg done_reg;

// Output assignments
assign count = cnt_reg;
assign done = done_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 0;
saved_n <= 0;
total_iterations <= 0;
counter <= 0;
cnt_reg <= 0;
done_reg <= 0;
    end else begin
        case (state)
            0: // IDLE state
                if (start) begin
                    state <= 1;
saved_n <= n;
total_iterations <= saved_n * saved_n * saved_n;
counter <= 0;
cnt_reg <= 0;
done_reg <= 0;
                end else begin
                    state <= 0;
                end
            1: // COMPUTE state
                if (counter < total_iterations) begin
                    integer n_val = saved_n;
integer n_sq = n_val * n_val;
integer i = counter / n_sq;
integer j = (counter / n_val) - i * n_val;
integer k = counter % n_val;

                    if (i != j && i != k && j != k) begin
                        logic [15:0] sum = (signed)arr[i] + (signed)arr[j];
                        if (sum == (signed)arr[k]) begin
                            cnt_reg <= cnt_reg + 1;
                        end
                    end
                    counter <= counter + 1;
                end else begin
                    state <= 2;
done_reg <= 1;
                end
            2: // DONE state
                state <= 2;
        endcase
    end
end

endmodule