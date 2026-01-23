module max_points_game (
    input clk,
    input rst_n,
    input start,
    input [7:0] sequence_in,
    input load_valid,
    output reg [15:0] max_score,
    output reg done
);
reg [2:0] state;
reg [15:0] lut [256];
reg [15:0] prev_prev, prev;
reg [7:0] i_counter;
reg [3:0] load_count;

always @(posedge clk) if (!rst_n) begin
    state <= 3'd0;
    load_count <= 4'd0;
    i_counter <= 8'd0;
    prev_prev <= 16'd0;
    prev <= 16'd0;
end else begin
    case (state)
        3'd0: begin
            if (start) state <= 3'd1;
            else state <= 3'd0;
            max_score <= 16'd0;
            done <= 1'b0;
        end
        3'd1: begin
            if (load_count < 16) begin
                if (load_valid) lut[sequence_in] <= lut[sequence_in] + 1;
                load_count <= load_count + 1;
                state <= 3'd1;
                max_score <= 16'd0;
                done <= 1'b0;
            end else begin
                state <= 3'd2;
                i_counter <= 8'd0;
                prev_prev <= 16'd0;
                prev <= 16'd0;
                max_score <= 16'd0;
                done <= 1'b0;
            end
        end
        3'd2: begin
            reg [15:0] current_points, candidate, current_dp;
            current_points = i_counter * lut[i_counter];
            candidate = prev_prev + current_points;
            current_dp = (prev > candidate) ? prev : candidate;
            if (i_counter < 255) begin
                prev_prev <= prev;
                prev <= current_dp;
                i_counter <= i_counter + 1;
                state <= 3'd2;
                max_score <= 16'd0;
                done <= 1'b0;
            end else begin
                prev_prev <= prev;
                prev <= current_dp;
                i_counter <= i_counter + 1;
                state <= 3'd3;
                max_score <= 16'd0;
                done <= 1'b0;
            end
        end
        3'd3: begin
            max_score <= prev;
            done <= 1'b1;
            state <= 3'd3;
        end
    endcase
end
endmodule