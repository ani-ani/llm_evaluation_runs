module triangle_ways (
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] l,
    output reg [31:0] result,
    output reg done
);

localparam IDLE = 3'd0;
localparam CALC_TOTAL = 3'd1;
localparam CALC_INVALID_A = 3'd2;
localparam CALC_INVALID_B = 3'd3;
localparam CALC_INVALID_C = 3'd4;
localparam DONE = 3'd5;

reg [2:0] current_state;
reg [31:0] total_ways;
reg [31:0] invalid_ways;
reg [31:0] result_reg;
reg done_reg;
reg [3:0] delay_count;

always @(posedge clk) begin
    if (!rst_n) begin
        current_state <= IDLE;
        total_ways <= 0;
        invalid_ways <= 0;
        result_reg <= 0;
        done_reg <= 0;
        delay_count <= 0;
    end else begin
        if (start && current_state == IDLE) begin
            current_state <= CALC_TOTAL;
            delay_count <= 0;
        end
        case(current_state)
            IDLE: 
                done_reg <= 0;
                if (start) begin
                    current_state <= CALC_TOTAL;
                    delay_count <= 0;
                end
            CALC_TOTAL: 
                total_ways <= ((l + 3) * (l + 2) * (l + 1)) / 6;
                total_ways <= total_ways << 16;
                delay_count <= delay_count + 1;
                if (delay_count == 1) begin
                    current_state <= CALC_INVALID_A;
                    delay_count <= 0;
                end
            CALC_INVALID_A: 
                delay_count <= delay_count + 1;
                if (delay_count == 10) begin
                    current_state <= CALC_INVALID_B;
                    delay_count <= 0;
                end
            CALC_INVALID_B: 
                delay_count <= delay_count + 1;
                if (delay_count == 10) begin
                    current_state <= CALC_INVALID_C;
                    delay_count <= 0;
                end
            CALC_INVALID_C: 
                delay_count <= delay_count + 1;
                if (delay_count == 10) begin
                    current_state <= DONE;
                    delay_count <= 0;
                end
            DONE: 
                result_reg <= total_ways - invalid_ways;
                done_reg <= 1;
                if (delay_count < 2) begin
                    delay_count <= delay_count + 1;
                end else begin
                    delay_count <= 0;
                end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule