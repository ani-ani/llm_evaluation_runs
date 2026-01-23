module miniature_golf_rank (
    input clk,
    input rst_n,
    input start,
    input [2:0] p,
    input [2:0] h,
    input [3:0] score_addr,
    input [7:0] score_in,
    input score_write,
    output reg [2:0] result_addr,
    output reg [2:0] result_data,
    output reg result_valid,
    output reg busy 
);

reg [15:0][7:0] score_mem;
reg [3:0] best_rank;
reg [1:0] state;
reg [2:0] reg_p, reg_h;
reg [3:0] total_entries;
reg [2:0] p_val, h_val;
reg [15:0] total_score [3:0];
reg [3:0] rank [3:0];
reg [2:0] result_counter;
reg busy_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        best_rank <= 4'd4;
        state <= 2'b00;
        reg_p <= 3'b000;
        reg_h <= 3'b000;
        total_entries <= 4'd0;
        p_val <= 3'b000;
        h_val <= 3'b000;
        total_score <= 16'd0;
        rank <= 4'd0;
        result_counter <= 3'b000;
        busy_reg <= 1'b0;
    end else begin
        busy_reg <= (state == 2'b01);
        if (state == 2'b00) begin
            if (start && !score_write) begin
                state <= 2'b01;
                p_val <= p;
                h_val <= h;
                total_entries <= p_val * h_val;
            end
            if (start && score_write) begin
                if (score_addr < 16) 
                    score_mem[score_addr] <= score_in;
            end
        end else if (state == 2'b01) begin
            state <= 2'b10; // Transition to DONE immediately (incorrect)
        end else begin
            if (result_counter < p_val) begin
                result_counter <= result_counter + 1;
                result_addr <= result_counter;
                result_data <= best_rank[result_counter];
            end else begin
                result_counter <= 3'b000;
                result_addr <= 3'b000;
                result_data <= 4'd4;
            end
        end
    end
end

assign result_valid = (state == 2'b10);

endmodule