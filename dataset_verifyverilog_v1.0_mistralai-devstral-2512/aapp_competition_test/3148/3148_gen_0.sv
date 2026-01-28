module lifeguard_positioning(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] swimmer_x [0:7],
    input wire signed [7:0] swimmer_y [0:7],
    input wire [3:0] num_swimmers,
    output reg signed [15:0] lifeguard1_x,
    output reg signed [15:0] lifeguard1_y,
    output reg signed [15:0] lifeguard2_x,
    output reg signed [15:0] lifeguard2_y,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_DISTANCES = 3'd1;
    localparam [2:0] COUNT_COMPARE = 3'd2;
    localparam [2:0] ADJUST_POSITION = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Distance arrays
    reg signed [15:0] d1 [0:7];
    reg signed [15:0] d2 [0:7];

    // Count of swimmers closer to lifeguard2
    reg [3:0] count_closer;

    // Current position adjustment
    reg signed [15:0] current_x, current_y;

    // Temporary variables
    reg [3:0] i;
    reg signed [15:0] temp_dist;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            lifeguard1_x <= 16'd0;
            lifeguard1_y <= 16'd0;
            lifeguard2_x <= 16'd0;
            lifeguard2_y <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                d1[i] <= 16'd0;
                d2[i] <= 16'd0;
            end
            count_closer <= 4'd0;
            current_x <= 16'd1000;
            current_y <= 16'd1000;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALC_DISTANCES;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_DISTANCES: begin
                    // Calculate d1[i] = |x[i]| + |y[i]|
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < num_swimmers) begin
                            temp_dist = (swimmer_x[i] < 0) ? -swimmer_x[i] : swimmer_x[i];
                            temp_dist = temp_dist + ((swimmer_y[i] < 0) ? -swimmer_y[i] : swimmer_y[i]);
                            d1[i] <= temp_dist;
                        end else begin
                            d1[i] <= 16'd0;
                        end
                    end
                    next_state <= COUNT_COMPARE;
                end

                COUNT_COMPARE: begin
                    // Calculate d2[i] = |x[i] - current_x| + |y[i] - current_y|
                    count_closer <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < num_swimmers) begin
                            temp_dist = (swimmer_x[i] - current_x[15:8]) < 0 ? -(swimmer_x[i] - current_x[15:8]) : (swimmer_x[i] - current_x[15:8]);
                            temp_dist = temp_dist + ((swimmer_y[i] - current_y[15:8]) < 0 ? -(swimmer_y[i] - current_y[15:8]) : (swimmer_y[i] - current_y[15:8]));
                            d2[i] <= temp_dist;
                            
                            if (d2[i] < d1[i]) begin
                                count_closer <= count_closer + 1;
                            end
                        end
                    end
                    
                    // Check if we have the right count
                    if (count_closer == num_swimmers / 2 || count_closer == (num_swimmers + 1) / 2) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= ADJUST_POSITION;
                    end
                end

                ADJUST_POSITION: begin
                    // Adjust position by shifting
                    current_x <= current_x + 16'd100;
                    current_y <= current_y + 16'd100;
                    next_state <= COUNT_COMPARE;
                end

                FINISH: begin
                    lifeguard1_x <= 16'd0;
                    lifeguard1_y <= 16'd0;
                    lifeguard2_x <= current_x;
                    lifeguard2_y <= current_y;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter for timeout
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= FINISH;
                end
            end
        end
    end
endmodule