module bridge_scheduler (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_boats,
    input [10:0] boat_arrival_time [0:7],
    output reg [15:0] total_time,
    output reg done
);

reg [15:0] current_time;
reg [1:0] bridge_state;
reg [2:0] boat_index;
reg [15:0] accumulated_time;
reg [15:0] total_time;
reg [11:0] wait_time_counter;
reg [5:0] bridge_movement_counter;
reg [4:0] boat_pass_counter;
reg [2:0] state;

localparam IDLE = 3'd0,
        RAISE_BRIDGE = 1,
        SERVE_BOATS = 2,
        LOWER_BRIDGE =3,
        DONE=4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_time <= 16'd0;
        bridge_state <= 2'd0;
        boat_index <= 3'd0;
        accumulated_time <=16'd0;
        state <= IDLE;
        done <=1'b0;
        total_time <=16'd0;
        bridge_movement_counter <=6'd0;
        boat_pass_counter <=4'd0;
    end else begin
        if (state != IDLE && state != DONE) begin
            current_time <= current_time +1;
        end

        if (state == IDLE) begin
            if (start) begin
                if (num_boats ==0) begin
                    state <= DONE;
                    done <=1'b1;
                end else begin
                    state <= RAISE_BRIDGE;
                end
            end
        end else if (state == RAISE_BRIDGE) begin
            if (bridge_movement_counter < 60) begin
                bridge_movement_counter <= bridge_movement_counter +1;
                accumulated_time <= accumulated_time +1;
                bridge_state <= 1;
            end else begin
                bridge_state <= 2;
                bridge_movement_counter <=6'd0;
                state <= SERVE_BOATS;
                boat_pass_counter <=4'd0;
            end
        end else if (state == SERVE_BOATS) begin
            if (boat_pass_counter >0) begin
                boat_pass_counter <= boat_pass_counter -1;
                accumulated_time <= accumulated_time +1;
            end else begin
                if (boat_index < num_boats) begin
                    if (boat_arrival_time[boat_index] <= current_time) begin
                        boat_pass_counter <= 20;
                    end
                end else begin
                    state <= LOWER_BRIDGE;
                    bridge_state <= 2;
                end
            end
        end else if (state == LOWER_BRIDGE) begin
            if (bridge_movement_counter <60) begin
                bridge_movement_counter <= bridge_movement_counter +1;
                accumulated_time <= accumulated_time +1;
                bridge_state <=3;
            end else begin
                bridge_state <=0;
                bridge_movement_counter <=6'd0;
                state <= DONE;
                done <=1'b1;
            end
        end else if (state == DONE) begin
            total_time <= accumulated_time;
        end
    end
endmodule