module ski_slalom_speed (
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

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_SKI    = 3'd1;
    localparam [2:0] CHECK_GATE   = 3'd2;
    localparam [2:0] UPDATE_BEST  = 3'd3;
    localparam [2:0] DONE_STATE   = 3'd4;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [5:0] ski_idx;
    reg [4:0] gate_idx;
    reg [31:0] current_ski_speed;
    reg [31:0] current_best;
    reg feasible;
    reg [31:0] prev_x_min;
    reg [31:0] prev_x_max;
    reg [31:0] delta_y_q16;
    reg [31:0] time_q16;
    reg [31:0] max_horiz_q16;
    reg [31:0] reachable_min;
    reg [31:0] reachable_max;
    reg [31:0] gate_min;
    reg [31:0] gate_max;
    reg [63:0] mult_temp;
    reg [31:0] div_temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper signals for arithmetic
    wire [31:0] delta_y;
    wire [31:0] gate_interval;
    wire [31:0] reach_interval;

    // Continuous assignments for comparisons
    assign delta_y = (gate_y[gate_idx] > gate_y[gate_idx-1]) ? 
                     (gate_y[gate_idx] - gate_y[gate_idx-1]) : 
                     (32'd0);
    assign gate_interval = gate_x[gate_idx] + W;
    assign reach_interval = prev_x_max + reach_max;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            best_speed <= 32'd0;
            valid <= 1'b0;
            ski_idx <= 6'd0;
            gate_idx <= 5'd0;
            current_ski_speed <= 32'd0;
            current_best <= 32'd1000000; // Max speed
            feasible <= 1'b0;
            prev_x_min <= 32'd0;
            prev_x_max <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_best <= 32'd1000000;
                        ski_idx <= 6'd0;
                        state <= CHECK_SKI;
                    end
                end

                CHECK_SKI: begin
                    if (ski_idx < S) begin
                        current_ski_speed <= skis[ski_idx];
                        gate_idx <= 5'd1; // Start from gate 1 (gate 0 is start)
                        prev_x_min <= 32'd0;
                        prev_x_max <= W;
                        feasible <= 1'b1;
                        cycle_count <= cycle_count + 8'd1;
                        state <= CHECK_GATE;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                CHECK_GATE: begin
                    if (gate_idx < N && feasible) begin
                        // Calculate delta_y (fixed point, already scaled)
                        if (gate_y[gate_idx] > gate_y[gate_idx-1]) begin
                            delta_y_q16 <= gate_y[gate_idx] - gate_y[gate_idx-1];
                        end else begin
                            delta_y_q16 <= 32'd0;
                        end
                        state <= UPDATE_BEST;
                    end else if (feasible && (gate_idx >= N)) begin
                        // Successfully completed all gates
                        if (current_ski_speed < current_best) begin
                            current_best <= current_ski_speed;
                        end
                        ski_idx <= ski_idx + 6'd1;
                        state <= CHECK_SKI;
                    end else begin
                        // Not feasible
                        ski_idx <= ski_idx + 6'd1;
                        state <= CHECK_SKI;
                    end
                end

                UPDATE_BEST: begin
                    // time = delta_y / s
                    // Using fixed-point division (shift left 16 for numerator)
                    if (current_ski_speed > 32'd0) begin
                        // Divide delta_y * 65536 by speed
                        div_temp = (delta_y_q16 << 16) / current_ski_speed;
                        time_q16 <= div_temp;
                    end else begin
                        time_q16 <= 32'd0;
                    end
                    state <= 2'd3; // Next state
                end
                
                // Additional state for pipeline
                2'd3: begin
                    // max_horiz = vh * time
                    mult_temp = vh * time_q16;
                    max_horiz_q16 <= mult_temp[47:16]; // Q16.16 result
                    state <= 2'd4;
                end

                2'd4: begin
                    // Calculate reachable interval
                    // Starting position unconstrained, so from prev_x range
                    // reachable_min = prev_x_min - max_horiz
                    // reachable_max = prev_x_max + max_horiz
                    if (max_horiz_q16[31] == 1'b0 && max_horiz_q16[15:0] == 16'd0) begin
                        // No movement allowed
                        reachable_min <= prev_x_min;
                        reachable_max <= prev_x_max;
                    end else begin
                        // Convert to integer for simplicity (approximate)
                        // Use Q16.16 to integer by shift right 16
                        reachable_min <= (max_horiz_q16[47:16] < prev_x_min) ? 
                                         32'd0 : (prev_x_min - max_horiz_q16[47:16]);
                        reachable_max <= prev_x_max + max_horiz_q16[47:16];
                    end
                    state <= 2'd5;
                end

                2'd5: begin
                    // Check intersection
                    gate_min <= gate_x[gate_idx];
                    gate_max <= gate_interval;
                    state <= 2'd6;
                end

                2'd6: begin
                    // Intersection check: max(min1, min2) <= min(max1, max2)
                    if (reachable_min > gate_max || gate_min > reachable_max) begin
                        feasible <= 1'b0;
                    end else begin
                        // Update position range to intersection
                        if (reachable_min > gate_min) begin
                            prev_x_min <= reachable_min;
                        end else begin
                            prev_x_min <= gate_min;
                        end
                        if (reachable_max < gate_max) begin
                            prev_x_max <= reachable_max;
                        end else begin
                            prev_x_max <= gate_max;
                        end
                    end
                    gate_idx <= gate_idx + 5'd1;
                    state <= CHECK_GATE;
                end

                DONE_STATE: begin
                    best_speed <= current_best;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule