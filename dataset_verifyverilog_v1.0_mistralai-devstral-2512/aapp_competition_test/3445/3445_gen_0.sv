module bicycle_courier_division(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [15:0] point_x,
    input wire [15:0] point_y,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_COORDS = 3'd1;
    localparam [2:0] PRECOMPUTE_DIST = 3'd2;
    localparam [2:0] ITERATE_MASKS = 3'd3;
    localparam [2:0] CALC_DIAMETER = 3'd4;
    localparam [2:0] UPDATE_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;

    // Coordinate storage (16 points max, 10 bits each)
    reg [9:0] x_coords [0:15];
    reg [9:0] y_coords [0:15];

    // Distance matrix (16x16, 16 bits each)
    reg [15:0] dist [0:15];
    integer i, j, k;

    // Mask iteration variables
    reg [15:0] mask;
    reg [15:0] min_result;
    reg [15:0] current_mask;
    reg [15:0] diameter_A, diameter_B;
    reg [15:0] max_diameter;

    // Cycle counter for safety
    reg [19:0] cycle_count;
    localparam [19:0] MAX_CYCLES = 20'd1000000;

    // Extract coordinates from packed format
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 16'd0;
            cycle_count <= 20'd0;
            
            // Initialize all registers
            for (i = 0; i < 16; i = i + 1) begin
                x_coords[i] <= 10'd0;
                y_coords[i] <= 10'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    dist[i*16 + j] <= 16'd0;
                end
            end
            mask <= 16'd0;
            min_result <= 16'd65535;
            current_mask <= 16'd0;
            diameter_A <= 16'd0;
            diameter_B <= 16'd0;
            max_diameter <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 20'd0;
                    if (start) begin
                        next_state <= LOAD_COORDS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_COORDS: begin
                    // Extract coordinates from packed format
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < N) begin
                            x_coords[i] <= point_x[(15 - i*4) : (12 - i*4)];
                            y_coords[i] <= point_y[(15 - i*4) : (12 - i*4)];
                        end else begin
                            x_coords[i] <= 10'd0;
                            y_coords[i] <= 10'd0;
                        end
                    end
                    next_state <= PRECOMPUTE_DIST;
                end

                PRECOMPUTE_DIST: begin
                    // Precompute all pairwise distances
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (i < N && j < N) begin
                                dist[i*16 + j] <= ({1'b0, x_coords[i]} - {1'b0, x_coords[j]})[10:0] +
                                                 ({1'b0, y_coords[i]} - {1'b0, y_coords[j]})[10:0];
                            end else begin
                                dist[i*16 + j] <= 16'd0;
                            end
                        end
                    end
                    next_state <= ITERATE_MASKS;
                    mask <= 16'd1;
                    min_result <= 16'd65535;
                end

                ITERATE_MASKS: begin
                    cycle_count <= cycle_count + 20'd1;
                    
                    // Skip mask=0 and mask=all-ones
                    if (mask == 16'd0 || mask == (16'd1 << N) - 16'd1) begin
                        mask <= mask + 16'd1;
                        next_state <= ITERATE_MASKS;
                    end else begin
                        current_mask <= mask;
                        next_state <= CALC_DIAMETER;
                    end
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                CALC_DIAMETER: begin
                    // Calculate diameter for set A (mask=1)
                    diameter_A <= 16'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (i < N && j < N && current_mask[i] && current_mask[j]) begin
                                if (dist[i*16 + j] > diameter_A) begin
                                    diameter_A <= dist[i*16 + j];
                                end
                            end
                        end
                    end
                    
                    // Calculate diameter for set B (mask=0)
                    diameter_B <= 16'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (i < N && j < N && !current_mask[i] && !current_mask[j]) begin
                                if (dist[i*16 + j] > diameter_B) begin
                                    diameter_B <= dist[i*16 + j];
                                end
                            end
                        end
                    end
                    
                    // Handle single-point sets
                    if (diameter_A == 16'd0) begin
                        diameter_A <= 16'd0;
                    end
                    if (diameter_B == 16'd0) begin
                        diameter_B <= 16'd0;
                    end
                    
                    max_diameter <= (diameter_A > diameter_B) ? diameter_A : diameter_B;
                    next_state <= UPDATE_RESULT;
                end

                UPDATE_RESULT: begin
                    if (max_diameter < min_result) begin
                        min_result <= max_diameter;
                    end
                    mask <= mask + 16'd1;
                    next_state <= ITERATE_MASKS;
                end

                DONE_STATE: begin
                    result <= min_result;
                    done <= 1'b1;
                    valid <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule