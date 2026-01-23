module expense_settler (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [5:0] m,
    input [2:0] a_in,
    input [2:0] b_in,
    input [7:0] c_in,
    input load_iou,
    output reg [2:0] p,
    output reg [2:0] out_a,
    output reg [2:0] out_b,
    output reg [7:0] out_c,
    output reg out_valid,
    output reg done
);

reg [7:0][7:0] debt_matrix;
reg [2:0] state;
reg [2:0] out_i, out_j;
reg [2:0] entry_count, total_entries;
reg [2:0] count_i, count_j;

localparam IDLE = 3\'b000;
localparam LOAD = 3\'b001;
localparam SETTLE = 3\'b010;
localparam CHECK_CYCLES = 3\'b011;
localparam OUTPUT = 3\'b100;
localparam DONE = 3\'b101;

always @(posedge clk) if (!rst_n) begin
    debt_matrix <= 0;
    state <= IDLE;
    out_i <=0;
    out_j <=0;
    entry_count <=0;
    total_entries <=0;
    count_i <=0;
    count_j <=0;
end else begin
    if (state == IDLE) begin
        if (start) state <= LOAD;
    end else if (state == LOAD) begin
        if (load_iou) debt_matrix[a_in][b_in] <= debt_matrix[a_in][b_in] + c_in;
        if (!start) state <= SETTLE;
    end else if (state == SETTLE) begin
        // 2-cycle cancellation logic here (simplified for example)
        if (debt_matrix[0][1] >0 && debt_matrix[1][0] >0) begin
            int min_val = debt_matrix[0][1] < debt_matrix[1][0] ? debt_matrix[0][1] : debt_matrix[1][0];
            debt_matrix[0][1] = debt_matrix[0][1] - min_val;
            debt_matrix[1][0] = debt_matrix[1][0] - min_val;
        end
        state <= CHECK_CYCLES;
    end else if (state == CHECK_CYCLES) begin
        if (count_i <8) begin
            if (count_j <8) begin
                if (count_i != count_j && debt_matrix[count_i][count_j] !=0) begin
                    total_entries <= total_entries +1;
                end
                count_j <= count_j +1;
            end else begin
                count_j <=0;
                count_i <= count_i +1;
            end
        end else begin
            state <= OUTPUT;
        end
    end else if (state == OUTPUT) begin
        if (entry_count < total_entries) begin
            out_a <= out_i;
            out_b <= out_j;
            out_c <= debt_matrix[out_i][out_j];
            out_valid <= 1\'b1;
            entry_count <= entry_count +1;
            if (out_j <7) out_j <= out_j +1;
            else begin
                out_j <=0;
                if (out_i <7) out_i <= out_i +1;
                else begin
                    entry_count <= total_entries;
                    done <=1\'b1;
                    state <= DONE;
                end
            end
        end else begin
            out_valid <=1\'b0;
            state <= DONE;
        end
    end
end

assign p = total_entries;

endmodule