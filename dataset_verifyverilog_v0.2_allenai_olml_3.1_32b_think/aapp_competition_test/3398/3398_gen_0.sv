module min_moves (
input clk,
input rst_n,
input start,
input [5:0] total_files,
input [9:0] num_delete,
input [9:0] file_coords [0:9],
output reg [3:0] min_moves,
output reg done);

reg [7:0] state;
reg [3:0] current_k;
reg [9:0] current_num;
reg [9:0] current_subset;
reg [3:0] min_moves_reg;
reg done_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 8'd0;
        current_k <= 4'd0;
        current_num <= 10'd0;
        current_subset <= 10'd0;
        min_moves_reg <= 4'd0;
        done_reg <= 1'b0;
    end else begin
        case (state)
            8'd0: // IDLE
                if (start) begin
                    state <= 8'd1;
                    current_k <= 4'd0;
                    current_num <= 10'd0;
                    current_subset <= 10'd0;
                end
            8'd1: // INIT_SUBSET
                if (current_num < 2) begin
                    current_num <= current_num +1;
                end else begin
                    state <= 8'd3;
                    min_moves_reg <= current_k;
                    done_reg <= 1'b1;
                end
            8'd3: // DONE
                state <= 8'd3;
        endcase
        min_moves <= min_moves_reg;
        done <= done_reg;
    end
end

endmodule