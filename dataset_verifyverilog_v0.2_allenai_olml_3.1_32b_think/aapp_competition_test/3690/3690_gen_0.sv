module clock_path (output reg result, output reg done, input wire clk, input wire rst_n, input wire start, input wire [5:0] h, input wire [5:0] m, input wire [5:0] s, input wire [5:0] t1, input wire [5:0] t2);

reg [2:0] state;
reg [5:0] hour_idx_reg, min_idx_reg, sec_idx_reg, start_idx_reg, end_idx_reg;
reg cw_clear_reg, ccw_clear_reg, result_reg, done_reg;
wire [5:0] hour_idx_val, min_idx_val, sec_idx_val, start_idx_val, end_idx_val;
wire clockwise_clear, counter_clear;

always_ff @(posedge clk or negedge rst_n) begin if (!rst_n) begin state <= 3'd0; hour_idx_reg <=6'd0; min_idx_reg <=6'd0; sec_idx_reg <=6'd0; start_idx_reg <=6'd0; end_idx_reg <=6'd0; cw_clear_reg <=1'b0; ccw_clear_reg <=1'b0; result_reg <=1'b0; done_reg <=1'b0; end else begin case(state) 3'd0: if (start) state <= 3'd1; else state <=3'd0; 3'd1: hour_idx_reg <= hour_idx_val; min_idx_reg <= min_idx_val; sec_idx_reg <= sec_idx_val; start_idx_reg <= start_idx_val; end_idx_reg <= end_idx_val; state <= 3'd2; 3'd2: cw_clear_reg <= clockwise_clear; state <= 3'd3; 3'd3: ccw_clear_reg <= counter_clear; state <= 3'd4; 3'd4: result_reg <= cw_clear_reg || ccw_clear_reg; done_reg <= 1'b1; state <= 3'd4; default: state <=3'd0; endcase end end

always_comb begin hour_idx_val = (h % 12) *5; min_idx_val = m; sec_idx_val = s; start_idx_val = (t1 % 12) *5; end_idx_val = (t2 % 12) *5; end

always_comb begin clockwise_clear = 1'b1; if (start_idx_reg < end_idx_reg) begin if (start_idx_reg +1 <= end_idx_reg) begin if ( (hour_idx_reg >= start_idx_reg+1 && hour_idx_reg <= end_idx_reg) || (min_idx_reg >= start_idx_reg+1 && min_idx_reg <= end_idx_reg) || (sec_idx_reg >= start_idx_reg+1 && sec_idx_reg <= end_idx_reg) ) begin clockwise_clear = 1'b0; end end end else begin if ( ( (hour_idx_reg >= start_idx_reg+1 && hour_idx_reg <=59) || (hour_idx_reg >=0 && hour_idx_reg <= end_idx_reg) ) || ( (min_idx_reg >= start_idx_reg+1 && min_idx_reg <=59) || (min_idx_reg >=0 && min_idx_reg <= end_idx_reg) ) || ( (sec_idx_reg >= start_idx_reg+1 && sec_idx_reg <=59) || (sec_idx_reg >=0 && sec_idx_reg <= end_idx_reg) ) ) begin clockwise_clear = 1'b0; end end end counter_clear = 1'b1; if (start_idx_reg > end_idx_reg) begin if (start_idx_reg -1 >= end_idx_reg) begin if ( (hour_idx_reg >= end_idx_reg && hour_idx_reg <= start_idx_reg-1) || (min_idx_reg >= end_idx_reg && min_idx_reg <= start_idx_reg-1) || (sec_idx_reg >= end_idx_reg && sec_idx_reg <= start_idx_reg-1) ) begin counter_clear = 1'b0; end end end end

assign result = result_reg; assign done = done_reg;
endmodule