module steward_support(input clk, input rst_n, // active-low reset input start, input [7:0] strength, input [2:0] n, output reg [2:0] result, output reg done);
localparam IDLE = 3'd0, INPUT = 3'd1, CALCULATE = 3'd2, DONE = 3'd3;
reg [2:0] idx;
reg [7:0] mem [0:7];
reg [7:0] min_val, max_val;
reg [2:0] count;
reg [2:0] calc_idx;
reg [2:0] state;
always @(posedge clk) begin
    if (!rst_n) begin
        idx <=0;
        mem <=0;
        min_val <=8'hFF;
        max_val <=8'h00;
        count <=0;
        calc_idx <=0;
        state <= IDLE;
        result <=0;
        done <=0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    idx <=0;
                    mem <=0;
                    min_val <=8'hFF;
                    max_val <=8'h00;
                    count <=0;
                    calc_idx <=0;
                    state <= INPUT;
                end else begin
                    state <= IDLE;
                end
            end
            INPUT: begin
                if (idx < n) begin
                    mem[idx] <= strength;
                    if (mem[idx] < min_val) min_val <= mem[idx];
                    else if (mem[idx] > max_val) max_val <= mem[idx];
                    idx <= idx +1;
                    if (idx == n) begin
                        state <= CALCULATE;
                        calc_idx <=0;
                    end
                end else begin
                    state <= CALCULATE;
                    calc_idx <=0;
                end
            end
            CALCULATE: begin
                if (calc_idx < n) begin
                    if (mem[calc_idx] > min_val && mem[calc_idx] < max_val) begin
                        count <= count +1;
                    end
                    calc_idx <= calc_idx +1;
                end else begin
                    result <= count;
                    state <= DONE;
                    calc_idx <=0;
                end
            end
            DONE: begin
                done <=1;
                state <= DONE;
            end
        endcase
    end
endmodule