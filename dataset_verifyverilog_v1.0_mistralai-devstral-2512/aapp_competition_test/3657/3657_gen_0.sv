module ski_slalom_speed(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] W,
    input wire [31:0] vh,
    input wire [31:0] gate_x [0:15],
    input wire [31:0] gate_y [0:15],
    input wire [4:0] N,
    input wire [31:0] skis [0:31],
    input wire [5:0] S,
    output reg [31:0] best_speed,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_SKI = 3'd1;
    localparam [2:0] CHECK_GATE = 3'd2;
    localparam [2:0] UPDATE_BEST = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] current_ski;
    reg [4:0] current_gate;
    reg [31:0] current_speed;
    reg [31:0] min_speed;
    reg [31:0] prev_x_low, prev_x_high;
    reg [31:0] current_x_low, current_x_high;
    reg [31:0] delta_y;
    reg [31:0] time;
    reg [31:0] max_horizontal;
    reg feasible;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Fixed-point constants
    localparam [31:0] ONE = 32'd1;
    localparam [31:0] SCALE = 32'd65536;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_ski <= 6'd0;
            current_gate <= 5'd0;
            current_speed <= 32'd0;
            min_speed <= 32'd0;
            prev_x_low <= 32'd0;
            prev_x_high <= 32'd0;
            current_x_low <= 32'd0;
            current_x_high <= 32'd0;
            delta_y <= 32'd0;
            time <= 32'd0;
            max_horizontal <= 32'd0;
            feasible <= 1'b0;
            cycle_count <= 8'd0;
            best_speed <= 32'd0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK_SKI;
                        current_ski <= 6'd0;
                        min_speed <= 32'd0;
                        feasible <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_SKI: begin
                    if (current_ski < S) begin
                        current_speed <= skis[current_ski];
                        current_gate <= 5'd0;
                        prev_x_low <= 32'd0;
                        prev_x_high <= 32'd0;
                        next_state <= CHECK_GATE;
                    end else begin
                        next_state <= DONE;
                    end
                end

                CHECK_GATE: begin
                    if (current_gate < N) begin
                        // Calculate delta_y (Q16.16)
                        if (current_gate == 5'd0) begin
                            delta_y <= gate_y[current_gate];
                        end else begin
                            delta_y <= gate_y[current_gate] - gate_y[current_gate - 5'd1];
                        end

                        // Calculate time = delta_y / current_speed (Q16.16)
                        if (current_speed != 32'd0) begin
                            time <= (delta_y << 16) / current_speed;
                        end else begin
                            time <= 32'd0;
                        end

                        // Calculate max_horizontal = vh * time (Q16.16)
                        max_horizontal <= (vh * time) >> 16;

                        // Calculate reachable interval
                        current_x_low <= prev_x_low - max_horizontal;
                        current_x_high <= prev_x_high + max_horizontal;

                        // Check intersection with gate interval
                        if (current_x_high >= gate_x[current_gate] && 
                            current_x_low <= (gate_x[current_gate] + W)) begin
                            // Update for next gate
                            prev_x_low <= gate_x[current_gate];
                            prev_x_high <= gate_x[current_gate] + W;
                            current_gate <= current_gate + 5'd1;
                            next_state <= CHECK_GATE;
                        end else begin
                            // Not feasible, move to next ski
                            current_ski <= current_ski + 6'd1;
                            next_state <= CHECK_SKI;
                        end
                    end else begin
                        // All gates passed, feasible
                        feasible <= 1'b1;
                        next_state <= UPDATE_BEST;
                    end
                end

                UPDATE_BEST: begin
                    if (feasible) begin
                        if (min_speed == 32'd0 || current_speed < min_speed) begin
                            min_speed <= current_speed;
                        end
                    end
                    current_ski <= current_ski + 6'd1;
                    next_state <= CHECK_SKI;
                end

                DONE: begin
                    if (min_speed != 32'd0) begin
                        best_speed <= min_speed;
                        valid <= 1'b1;
                    end else begin
                        best_speed <= 32'd0;
                        valid <= 1'b1;
                    end
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    valid <= 1'b0;
                end
            endcase
        end
    end

    // Safety check for cycle count
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            next_state <= DONE;
        end
    end

endmodule