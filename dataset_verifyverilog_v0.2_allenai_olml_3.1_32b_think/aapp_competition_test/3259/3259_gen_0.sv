module aladin_box_sim (input clk, input rst_n, input start, input [2:0] op_type, input [2:0] L, input [2:0] R, input [7:0] A, input [7:0] B, output reg [7:0] result, output reg done);
reg [7:0] box [7:0];
reg [2:0] op_type_reg;
reg [2:0] L_reg;
reg [2:0] R_reg;
reg [7:0] A_reg;
reg [7:0] B_reg;
reg [2:0] current_index;
reg [7:0] sum_reg;
reg [3:0] state;
reg done_reg;

localparam IDLE = 3'd0;
localparam PROCESSING = 3'd1;
localparam DONE = 3'd2;

always @(posedge clk) begin
    if (!rst_n) begin
        box <= {8{8'b0}};
        op_type_reg <= 3'b000;
        L_reg <= 3'b000;
        R_reg <= 3'b000;
        A_reg <= 8'b000;
        B_reg <= 8'b000;
        current_index <= 3'b000;
        sum_reg <= 8'b000;
        state <= IDLE;
        done_reg <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                op_type_reg <= op_type;
                L_reg <= L;
                R_reg <= R;
                A_reg <= A;
                B_reg <= B;
                current_index <= L_reg;
                sum_reg <= 8'b000;
                state <= PROCESSING;
                done_reg <= 1'b0;
            end
        end else if (state == PROCESSING) begin
            if (current_index <= R_reg) begin
                if (op_type_reg == 3'b000) begin
                    box[current_index] <= ((current_index - L_reg + 1) * A_reg) % B_reg;
                end else begin
                    sum_reg <= sum_reg + box[current_index];
                end
                current_index <= current_index + 1;
            end else begin
                done_reg <= 1'b1;
                state <= DONE;
            end
        end
    end
end

assign result = (op_type_reg == 3'b001 && done_reg) ? sum_reg : 8'b000;
assign done = done_reg;

endmodule