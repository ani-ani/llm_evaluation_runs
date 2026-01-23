module cheetah_pack_minimum (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_cheetahs,
    input [15:0] start_times [0:3],
    input [15:0] velocities [0:3],
    output reg [31:0] min_pack_length,
    output reg done
);

    reg [2:0] state;
    localparam IDLE = 3'd0, INIT = 3'd1, FIND_INTERSECTION = 3'd2, EVALUATE_TIMES = 3'd3, DONE = 3'd4;

    reg [3:0] N;
    reg [15:0] start_times_reg [0:3];
    reg [15:0] velocities_reg [0:3];
    reg [31:0] critical_times [15:0];
    reg [3:0] num_critical_times;
    reg [31:0] min_length;
    reg [1:0] state_counter;

    always @(posedge clk or posedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            N <= 4'd0;
            start_times_reg <= 'd0;
            velocities_reg <= 'd0;
            num_critical_times <= 4'd0;
            min_length <= 'd0;
            done <= 1'b0;
            state_counter <= 2'd0;
        end else begin
            case (state)
                IDLE: if (start) state <= INIT;
                INIT: begin
                    N <= num_cheetahs;
                    start_times_reg <= start_times;
                    velocities_reg <= velocities;
                    if (N > 4'd0 && N < 5'd1) state <= FIND_INTERSECTION;
                    else state <= DONE;
                end
                FIND_INTERSECTION: begin
                    num_critical_times <= 4'd0;
                    if (N >= 1) critical_times[num_critical_times++] = start_times_reg[0];
                    if (N >= 2) critical_times[num_critical_times++] = start_times_reg[1];
                    if (N >= 3) critical_times[num_critical_times++] = start_times_reg[2];
                    if (N >= 4) critical_times[num_critical_times++] = start_times_reg[3];
                    state <= EVALUATE_TIMES;
                end
                EVALUATE_TIMES: begin
                    if (state_counter < num_critical_times) begin
                        reg [31:0] t = critical_times[state_counter];
                        reg [31:0] max_pos, min_pos;
                        max_pos <= 'd0;
                        min_pos <= 'd0;
                        for (int i=0; i<N; i++) begin
                            if (t >= start_times_reg[i]) begin
                                reg [31:0] pos = velocities_reg[i] * (t - start_times_reg[i]);
                                if (pos > max_pos) max_pos = pos;
                                if (pos < min_pos || min_pos == 'd0) min_pos = pos;
                            end
                        end
                        if (max_pos > min_pos) begin
                            reg [31:0] len = max_pos - min_pos;
                            if (min_length == 'd0 || len < min_length) min_length = len;
                        end
                        state_counter <= state_counter + 1;
                    end else begin
                        min_pack_length <= min_length;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end
                DONE: ;
            endcase
        end
    end
endmodule