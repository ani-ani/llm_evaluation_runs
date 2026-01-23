module downlink_verifier (
	input clk,
	input rst_n,
	input start,
	input [3:0] n_in,
	input [3:0] q_in,
	input [3:0] s_in,
	input [3:0] sensor_queue_map [3:0],
	input [255:0] queue_capacities [3:0],
	input [255:0] window_downlink [3:0],
	input [255:0] sensor_data [3:0][3:0],
	output reg result,
	output reg done
);

	localparam IDLE = 3'd0;
	localparam READ_PARAMS = 3'd1;
	localparam PROCESS_WINDOW = 3'd2;
	localparam ALLOCATE = 3'd3;
	localparam CHECK_RESULT = 3'd4;
	localparam DONE = 3'd5;

	reg [2:0] state;
	reg [2:0] next_state;
	reg [3:0] n_val, q_val, s_val;
	reg [3:0] sensor_map [3:0];
	reg [255:0] queue_cap [4];
	reg [255:0] window_down [4];
	reg [255:0] queue_fill [4];
	reg [3:0] window_idx, sensor_idx;
	reg [3:0] param_count;
	reg result_reg, done_reg;

	always_ff @(posedge clk) begin
		if (!rst_n) begin
			state <= IDLE;
			n_val <= 4'd0;
			q_val <= 4'd0;
			s_val <= 4'd0;
			sensor_map <= 4'd0;
			queue_cap <= 4{256'b0};
			window_down <= 4{256'b0};
			queue_fill <= 4{256'b0};
			window_idx <= 4'd0;
			sensor_idx <= 4'd0;
			param_count <= 4'd0;
			result_reg <= 1'b0;
			done_reg <= 1'b0;
		end else begin
			case (state)
				IDLE: begin
					if (start) begin
						next_state = READ_PARAMS;
						param_count <= 4'd0;
						window_idx <= 4'd0;
						sensor_idx <= 4'd0;
					end else begin
						next_state = IDLE;
					end
				end
				READ_PARAMS: begin
					if (param_count < 15) begin
						next_state = READ_PARAMS;
						case (param_count)
							0: n_val <= n_in; param_count <= 1;
							1: q_val <= q_in; param_count <= 2;
							2: s_val <= s_in; param_count <= 3;
							3: sensor_map[0] <= sensor_queue_map[0]; param_count <= 4;
							4: sensor_map[1] <= sensor_queue_map[1]; param_count <= 5;
							5: sensor_map[2] <= sensor_queue_map[2]; param_count <= 6;
							6: sensor_map[3] <= sensor_queue_map[3]; param_count <= 7;
							7: queue_cap[0] <= queue_capacities[0]; param_count <= 8;
							8: queue_cap[1] <= queue_capacities[1]; param_count <= 9;
							9: queue_cap[2] <= queue_capacities[2]; param_count <= 10;
							10: queue_cap[3] <= queue_capacities[3]; param_count <= 11;
							11: window_down[0] <= window_downlink[0]; param_count <= 12;
							12: window_down[1] <= window_downlink[1]; param_count <= 13;
							13: window_down[2] <= window_downlink[2]; param_count <= 14;
							14: window_down[3] <= window_downlink[3]; param_count <= 15;
						endcase
					end else if (param_count == 15) begin
						next_state = PROCESS_WINDOW;
						param_count <= 4'd0;
					end else begin
						next_state = READ_PARAMS;
					end
				end
				PROCESS_WINDOW: begin
					if (window_idx >= n_val) begin
						next_state = CHECK_RESULT;
					end else begin
						if (sensor_idx < s_val) begin
							reg [255:0] data;
							data = sensor_data[window_idx][sensor_idx];
							reg [3:0] queue_idx;
							queue_idx = sensor_map[sensor_idx];
							if (queue_idx >= q_val) begin
								result_reg <= 1'b0;
								done_reg <= 1'b1;
								next_state = DONE;
							end else begin
								reg [255:0] new_fill;
								new_fill = queue_fill[queue_idx] + data;
								if (new_fill > queue_cap[queue_idx]) begin
									result_reg <= 1'b0;
									done_reg <= 1'b1;
									next_state = DONE;
								end else begin
									queue_fill[queue_idx] <= new_fill;
									sensor_idx <= sensor_idx + 1;
									next_state = PROCESS_WINDOW;
								end
							end
						end else begin
							if (window_idx < n_val) begin
								next_state = ALLOCATE;
							end else begin
								next_state = CHECK_RESULT;
							end
						end
					end
				end
				ALLOCATE: begin
					reg [255:0] alloc;
					reg [255:0] remaining;
					remaining = window_down[window_idx];
					if (q_val > 0 && queue_fill[0] > 0 && remaining > 0) begin
						alloc = queue_fill[0] < remaining ? queue_fill[0] : remaining;
						queue_fill[0] <= queue_fill[0] - alloc;
						remaining = remaining - alloc;
					end
					if (q_val > 1 && queue_fill[1] > 0 && remaining > 0) begin
						alloc = queue_fill[1] < remaining ? queue_fill[1] : remaining;
						queue_fill[1] <= queue_fill[1] - alloc;
						remaining = remaining - alloc;
					end
					if (q_val > 2 && queue_fill[2] > 0 && remaining > 0) begin
						alloc = queue_fill[2] < remaining ? queue_fill[2] : remaining;
						queue_fill[2] <= queue_fill[2] - alloc;
						remaining = remaining - alloc;
					end
					if (q_val > 3 && queue_fill[3] > 0 && remaining > 0) begin
						alloc = queue_fill[3] < remaining ? queue_fill[3] : remaining;
						queue_fill[3] <= queue_fill[3] - alloc;
						remaining = remaining - alloc;
					end
					next_state = PROCESS_WINDOW;
				end
				CHECK_RESULT: begin
					if (queue_fill[0] === 0 && queue_fill[1] === 0 && queue_fill[2] === 0 && queue_fill[3] === 0) begin
						result_reg <= 1'b1;
						done_reg <= 1'b1;
						next_state = DONE;
					end else begin
						result_reg <= 1'b0;
						done_reg <= 1'b1;
						next_state = DONE;
					end
				end
				DONE: begin
					next_state = DONE;
				end
			endcase
			state <= next_state;
		end
	end

	assign result = result_reg;
	assign done = done_reg;
endmodule