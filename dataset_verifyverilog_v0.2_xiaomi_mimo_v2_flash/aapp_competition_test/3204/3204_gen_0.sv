module bridge_scheduler(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_boats,
    input [10:0] boat_arrival_time [0:7],
    output reg [15:0] total_time,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam DECIDE = 3'b001;
    localparam RAISE = 3'b010;
    localparam SERVE = 3'b011;
    localparam LOWER = 3'b100;
    localparam CALCULATE = 3'b101;
    localparam FINISH = 3'b110;

    reg [2:0] state;

    // Registers
    reg [15:0] current_time;
    reg [15:0] unavailable_time;
    reg [2:0] idx;
    reg [5:0] bridge_cnt;
    reg [4:0] boat_cnt;

    // Helper wires for current and next boat times
    wire [15:0] curr_boat_time;
    wire [15:0] next_boat_time;

    assign curr_boat_time = {5'b0, boat_arrival_time[idx]};
    assign next_boat_time = (idx + 1 < num_boats) ? {5'b0, boat_arrival_time[idx + 1]} : 16'hFFFF;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_time <= 0;
            unavailable_time <= 0;
            idx <= 0;
            bridge_cnt <= 0;
            boat_cnt <= 0;
            total_time <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= DECIDE;
                        current_time <= 0;
                        unavailable_time <= 0;
                        idx <= 0;
                    end
                end

                DECIDE: begin
                    bridge_cnt <= 0;
                    boat_cnt <= 0;
                    if (idx >= num_boats) begin
                        state <= CALCULATE;
                    end else begin
                        if (curr_boat_time > current_time && (curr_boat_time - current_time) > 1800) begin
                            current_time <= curr_boat_time;
                            state <= DECIDE;
                        end else begin
                            if (curr_boat_time > current_time) current_time <= curr_boat_time;
                            state <= RAISE;
                        end
                    end
                end

                RAISE: begin
                    if (bridge_cnt < 60) begin
                        bridge_cnt <= bridge_cnt + 1;
                        current_time <= current_time + 1;
                        unavailable_time <= unavailable_time + 1;
                    end else begin
                        state <= SERVE;
                    end
                end

                SERVE: begin
                    if (boat_cnt < 20) begin
                        boat_cnt <= boat_cnt + 1;
                        current_time <= current_time + 1;
                        unavailable_time <= unavailable_time + 1;
                    end else begin
                        idx <= idx + 1;
                        boat_cnt <= 0;
                        if (idx + 1 >= num_boats) begin
                            state <= LOWER;
                        end else begin
                            if (next_boat_time > current_time) begin
                                if ((next_boat_time - current_time) > 1800) begin
                                    current_time <= next_boat_time;
                                    unavailable_time <= unavailable_time + (next_boat_time - current_time);
                                    state <= SERVE;
                                end else begin
                                    if ((next_boat_time - current_time) > 120) begin
                                        state <= LOWER;
                                    end else begin
                                        current_time <= next_boat_time;
                                        unavailable_time <= unavailable_time + (next_boat_time - current_time);
                                        state <= SERVE;
                                    end
                                end
                            end else begin
                                state <= SERVE;
                            end
                        end
                    end
                end

                LOWER: begin
                    if (bridge_cnt < 60) begin
                        bridge_cnt <= bridge_cnt + 1;
                        current_time <= current_time + 1;
                        unavailable_time <= unavailable_time + 1;
                    end else begin
                        state <= DECIDE;
                    end
                end

                CALCULATE: begin
                    total_time <= unavailable_time;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule