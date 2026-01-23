module garbage_disposal (
    input clk,
    input rst_n, // Active-low reset
    input start,
    input [7:0] n,
    input [7:0] k,
    input [7:0] a_i,
    output reg [31:0] total_bags,
    output reg done,
    output reg [4:0] day_index
);
parameter IDLE = 3'd0,
FETCH_DAY = 3'd1,
PROCESS_DAY = 3'd2,
FINISHED = 3'd3;
reg [2:0] state;
reg [31:0] total_bags_reg;
reg [4:0] day_index_reg;
reg [7:0] carry_reg;
reg prev_start;
reg [2:0] next_state;
reg [31:0] next_total_bags;
reg [4:0] next_day_index;
reg [7:0] next_carry;
always @(posedge clk) if (!rst_n) prev_start <= 0; else prev_start <= start;
always @(*) begin
    next_state = state;
    next_total_bags = total_bags_reg;
    next_day_index = day_index_reg;
    next_carry = carry_reg;
    case(state)
        IDLE: begin
            if (start && !prev_start) begin
                next_state = FETCH_DAY;
                next_day_index = 0;
                next_total_bags = 0;
                next_carry = 0;
            end
        end
        FETCH_DAY: begin
            next_state = PROCESS_DAY;
        end
        PROCESS_DAY: begin
            integer current_garbage, bags_today;
            current_garbage = a_i + carry_reg;
            bags_today = current_garbage / k;
            next_total_bags = total_bags_reg + bags_today;
            if (day_index_reg == n-1 && (current_garbage % k) !=0) begin
                next_total_bags = next_total_bags +1;
            end
            next_carry = current_garbage % k;
            next_day_index = day_index_reg +1;
            if (next_day_index < n) begin
                next_state = FETCH_DAY;
            end else begin
                next_state = FINISHED;
            end
        end
        FINISHED: begin
        end
        default: next_state = IDLE;
    endcase
end
always @(posedge clk) if (!rst_n) begin
    state <= IDLE;
    total_bags_reg <= 0;
    day_index_reg <= 0;
    carry_reg <= 0;
    prev_start <=0;
end else begin
    state <= next_state;
    total_bags_reg <= next_total_bags;
    day_index_reg <= next_day_index;
    carry_reg <= next_carry;
end
assign total_bags = total_bags_reg;
assign day_index = day_index_reg;
assign done = (state == FINISHED);
endmodule