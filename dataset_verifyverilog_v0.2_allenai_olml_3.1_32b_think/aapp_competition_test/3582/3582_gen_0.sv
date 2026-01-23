module gaggle_mentor (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0][7:0] current_mentor,
    output reg [7:0] new_mentor,
    output reg [2:0] employee_idx,
    output reg done
);

reg [2:0] state;
reg [7:0] best_mentor [8];
reg [2:0] current_n;
reg [3:0] perm_counter;
reg [2:0] employee_idx_reg;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'b000;
        best_mentor <= 8'b0;
        current_n <= 3'b000;
        perm_counter <= 4'd0;
        employee_idx_reg <= 3'b000;
        done_reg <= 1'b0;
        new_mentor <= 8'b0;
    end else begin
        if (state == 3'b000) begin // IDLE
            if (start == 1'b1) begin
                state <= 3'b001;
                current_n <= n;
            end
            new_mentor <= 8'b0;
        end else if (state == 3'b001) begin // FIND
            if (perm_counter < 100) begin
                perm_counter <= perm_counter + 1;
            end else begin
                state <= 3'b010;
            end
            new_mentor <= 8'b0;
        end else if (state == 3'b010) begin // OUTPUT
            if (employee_idx_reg < current_n) begin
                employee_idx <= employee_idx_reg + 1;
                if (employee_idx_reg + 1 == current_n) begin
                    done_reg <= 1'b1;
                    state <= 3'b100;
                end
            end else begin
                done_reg <= 1'b1;
                state <= 3'b100;
            end
            new_mentor <= 8'b0;
        end else begin // DONE
            new_mentor <= 8'b0;
        end
    end
end

assign done = done_reg;
endmodule