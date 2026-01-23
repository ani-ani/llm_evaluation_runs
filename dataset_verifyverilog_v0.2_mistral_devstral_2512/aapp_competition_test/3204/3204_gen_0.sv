module bridge_scheduler (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_boats,
    input [10:0] boat_arrival_time [0:7],
    output reg [15:0] total_time,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam RAISE_BRIDGE = 3'b001;
    localparam SERVE_BOATS = 3'b010;
    localparam LOWER_BRIDGE = 3'b011;
    localparam DONE = 3'b100;

    localparam BRIDGE_MOVEMENT_TIME = 60;
    localparam BOAT_PASS_TIME = 20;
    localparam MAX_WAIT_TIME = 1800;

    // State registers
    reg [2:0] state, next_state;

    // Data registers
    reg [15:0] current_time;
    reg [15:0] accumulated_time;
    reg [11:0] wait_time_counter;
    reg [5:0] bridge_movement_counter;
    reg [4:0] boat_pass_counter;
    reg [2:0] boat_index;
    reg [1:0] bridge_state; // 0: LOWERED, 1: RAISING, 2: RAISED, 3: LOWERING

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (!rst_n) next_state = IDLE;
                else if (start) next_state = RAISE_BRIDGE;
                else next_state = IDLE;
            end

            RAISE_BRIDGE: begin
                if (bridge_movement_counter == BRIDGE_MOVEMENT_TIME - 1) begin
                    next_state = SERVE_BOATS;
                end else begin
                    next_state = RAISE_BRIDGE;
                end
            end

            SERVE_BOATS: begin
                if (boat_pass_counter == BOAT_PASS_TIME - 1) begin
                    if (boat_index == num_boats - 1) begin
                        next_state = LOWER_BRIDGE;
                    end else begin
                        next_state = SERVE_BOATS;
                    end
                end else begin
                    next_state = SERVE_BOATS;
                end
            end

            LOWER_BRIDGE: begin
                if (bridge_movement_counter == BRIDGE_MOVEMENT_TIME - 1) begin
                    next_state = DONE;
                end else begin
                    next_state = LOWER_BRIDGE;
                end
            end

            DONE: begin
                if (!rst_n) next_state = IDLE;
                else next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_time <= 0;
            accumulated_time <= 0;
            wait_time_counter <= 0;
            bridge_movement_counter <= 0;
            boat_pass_counter <= 0;
            boat_index <= 0;
            bridge_state <= 0;
            done <= 0;
            total_time <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    current_time <= 0;
                    accumulated_time <= 0;
                    wait_time_counter <= 0;
                    bridge_movement_counter <= 0;
                    boat_pass_counter <= 0;
                    boat_index <= 0;
                    bridge_state <= 0;
                    done <= 0;
                end

                RAISE_BRIDGE: begin
                    if (bridge_movement_counter == 0) begin
                        bridge_state <= 1; // RAISING
                    end
                    bridge_movement_counter <= bridge_movement_counter + 1;
                    current_time <= current_time + 1;
                    if (bridge_movement_counter == BRIDGE_MOVEMENT_TIME - 1) begin
                        bridge_state <= 2; // RAISED
                        bridge_movement_counter <= 0;
                    end
                end

                SERVE_BOATS: begin
                    if (boat_pass_counter == 0) begin
                        boat_index <= boat_index + 1;
                    end
                    boat_pass_counter <= boat_pass_counter + 1;
                    current_time <= current_time + 1;
                    if (boat_pass_counter == BOAT_PASS_TIME - 1) begin
                        boat_pass_counter <= 0;
                    end
                end

                LOWER_BRIDGE: begin
                    if (bridge_movement_counter == 0) begin
                        bridge_state <= 3; // LOWERING
                    end
                    bridge_movement_counter <= bridge_movement_counter + 1;
                    current_time <= current_time + 1;
                    if (bridge_movement_counter == BRIDGE_MOVEMENT_TIME - 1) begin
                        bridge_state <= 0; // LOWERED
                        bridge_movement_counter <= 0;
                    end
                end

                DONE: begin
                    done <= 1;
                    total_time <= accumulated_time + current_time;
                end
            endcase
        end
    end

    // Accumulated time calculation
    always @(posedge clk) begin
        if (!rst_n) begin
            accumulated_time <= 0;
        end else if (state == RAISE_BRIDGE || state == SERVE_BOATS || state == LOWER_BRIDGE) begin
            if (bridge_state == 1 || bridge_state == 3) begin // RAISING or LOWERING
                accumulated_time <= accumulated_time + 1;
            end else if (bridge_state == 2) begin // RAISED
                accumulated_time <= accumulated_time + 1;
            end
        end
    end

endmodule