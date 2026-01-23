module stove_cooking (
    input clk,
    input rst_n,
    input start,
    input [63:0] k_in,
    input [63:0] d_in,
    input [63:0] t_in,
    output reg [63:0] result,
    output reg done
);

reg [2:0] state;
reg [63:0] low, high, iteration_count, result_reg;

reg [2:0] next_state;
reg [63:0] next_low, next_high, next_iteration_count, next_result_reg;
wire [63:0] mid, cycle_len, on_time, off_time, heat_per_cycle, full_cycles, remaining_time, remaining_heat, total_cooking, required;
wire sufficient;

always_comb begin
    next_state = state;
    next_low = low;
    next_high = high;
    next_iteration_count = iteration_count;
    next_result_reg = result_reg;

    mid = (low + high) >> 1;

    cycle_len = ((k_in + d_in - 1) / d_in) * d_in;
    on_time = k_in;
    off_time = cycle_len - on_time;
    heat_per_cycle = (on_time * 2) + off_time;

    full_cycles = mid / cycle_len;
    remaining_time = mid % cycle_len;

    if (remaining_time < on_time) begin
        remaining_heat = remaining_time * 2;
    end else begin
        remaining_heat = (on_time * 2) + (remaining_time - on_time);
    end

    total_cooking = (full_cycles * heat_per_cycle) + remaining_heat;
    required = t_in + t_in;
    sufficient = total_cooking >= required;

    if (!rst_n) begin
        next_state <= 3'd0;
        next_low <= 64'b0;
        next_high <= 64'b0;
        next_iteration_count <= 64'b0;
        next_result_reg <= 64'b0;
    end else begin
        case (state)
            3'd0: begin
                if (start) begin
                    next_state = 3'd1;
                end
            end
            3'd1: begin
                next_state = 3'd2;
                next_high = t_in + t_in;
                next_low = 64'b0;
                next_iteration_count = 64'b0;
            end
            3'd2: begin
                next_state = 3'd3;
            end
            3'd3: begin
                next_low = low;
                next_high = high;
                if (sufficient) begin
                    next_high = mid;
                end else begin
                    next_low = mid + 1;
                end
                next_iteration_count = iteration_count + 1;
                if (next_iteration_count == 64) begin
                    next_state = 3'd4;
                    next_result_reg = low;
                end else begin
                    next_state = 3'd2;
                end
            end
            3'd4: begin
                next_state = 3'd4;
            end
        endcase
    end
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        low <= 64'b0;
        high <= 64'b0;
        iteration_count <= 64'b0;
        result_reg <= 64'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        low <= next_low;
        high <= next_high;
        iteration_count <= next_iteration_count;
        result_reg <= next_result_reg;
        done <= (state == 3'd4);
    end
end

assign result = done ? result_reg : 64'b0;

endmodule