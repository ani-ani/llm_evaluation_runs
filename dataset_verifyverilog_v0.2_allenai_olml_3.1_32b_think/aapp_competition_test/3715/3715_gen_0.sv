module vacation_scheduler (input clk, input rst_n, input start, input [1:0] day_data, input [6:0] day_index, input data_valid, output reg [7:0] min_rest_days, output reg done);
localparam IDLE = 2'd0, LOAD = 2'd1, COMPUTE = 2'd2, DONE = 2'd3;
reg [1:0] state;
reg [7:0] prev_rest, prev_contest, prev_sport;
reg [7:0] current_rest, current_contest, current_sport;
reg [7:0] global_max;
reg [6:0] day_count;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        prev_rest <= 8'd0;
        prev_contest <= 8'd0;
        prev_sport <= 8'd0;
        global_max <= 8'd0;
        day_count <= 8'd0;
        min_rest_days <= 8'd0;
        done <= 1'b0;
    end else begin
        case(state)
            IDLE: 
                if (start)
                    state <= LOAD;
                else
                    state <= IDLE;
            LOAD: 
                state <= COMPUTE;
            COMPUTE: 
                if (data_valid) begin
                    case(day_data)
                        2'd0: begin
                            current_rest = max(prev_rest, prev_contest, prev_sport);
                            current_contest = 8'd0;
                            current_sport = 8'd0;
                        end
                        2'd1: begin
                            current_contest = max(prev_rest, prev_sport) + 1;
                            current_rest = max(prev_rest, prev_contest, prev_sport);
                            current_sport = 8'd0;
                            if (current_contest > global_max) global_max <= current_contest;
                        end
                        2'd2: begin
                            current_sport = max(prev_rest, prev_contest) + 1;
                            current_rest = max(prev_rest, prev_contest, prev_sport);
                            current_contest = 8'd0;
                            if (current_sport > global_max) global_max <= current_sport;
                        end
                        2'd3: begin
                            current_contest = max(prev_rest, prev_sport) + 1;
                            current_sport = max(prev_rest, prev_contest) + 1;
                            current_rest = max(prev_rest, prev_contest, prev_sport);
                            if (current_contest > global_max) global_max <= current_contest;
                            if (current_sport > global_max) global_max <= current_sport;
                        end
                        default: begin
                            current_rest = max(prev_rest, prev_contest, prev_sport);
                            current_contest = 8'd0;
                            current_sport = 8'd0;
                        end
                    endcase

                    // Update previous values for next iteration
                    prev_rest <= current_rest;
                    prev_contest <= current_contest;
                    prev_sport <= current_sport;

                    day_count <= day_count + 1;

                    if (day_count == 100) begin
                        state <= DONE;
                    end else begin
                        state <= COMPUTE;
                    end
                end else begin
                    // data_valid is low, do not process, stay in COMPUTE
                    state <= COMPUTE;
                end
            DONE: begin
                min_rest_days <= 100 - global_max;
                done <= 1'b1;
                state <= DONE;
                // stay in DONE
            end
            default: state <= IDLE;
        endcase
    end
end
endmodule