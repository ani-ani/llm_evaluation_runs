module tv_coverage(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [31:0] D,
    input wire [0:15] buildings_tx,
    input wire [31:0] buildings_x [0:15],
    input wire [23:0] buildings_h [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd900;

    // Building data storage
    reg [31:0] b_x [0:15];
    reg [23:0] b_h [0:15];
    reg [0:15] b_tx;
    reg [31:0] city_length;
    reg [3:0] num_buildings;

    // Computation variables
    reg [31:0] segment_center;
    reg [31:0] segment_width;
    reg [3:0] segment_idx;
    reg [3:0] transmitter_idx;
    reg [31:0] line_height;
    reg [31:0] temp_val;
    reg [31:0] covered_length;
    reg [0:15] visible_segments;

    // Fixed-point division parameters
    localparam [4:0] DIV_ITERATIONS = 5'd16;
    reg [31:0] numerator, denominator;
    reg [31:0] quotient;
    reg [4:0] div_iter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 32'd0;
            
            // Initialize building data
            for (integer i = 0; i < 16; i = i + 1) begin
                b_x[i] <= 32'd0;
                b_h[i] <= 24'd0;
                b_tx[i] <= 1'b0;
            end
            city_length <= 32'd0;
            num_buildings <= 4'd0;
            
            // Initialize computation variables
            segment_center <= 32'd0;
            segment_width <= 32'd0;
            segment_idx <= 4'd0;
            transmitter_idx <= 4'd0;
            line_height <= 32'd0;
            temp_val <= 32'd0;
            covered_length <= 32'd0;
            for (integer i = 0; i < 16; i = i + 1) begin
                visible_segments[i] <= 1'b0;
            end
            
            // Division variables
            numerator <= 32'd0;
            denominator <= 32'd0;
            quotient <= 32'd0;
            div_iter <= 5'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load input data
                    num_buildings <= N;
                    city_length <= D;
                    for (integer i = 0; i < 16; i = i + 1) begin
                        if (i < N) begin
                            b_x[i] <= buildings_x[i];
                            b_h[i] <= buildings_h[i];
                            b_tx[i] <= buildings_tx[i];
                        end else begin
                            b_x[i] <= 32'd0;
                            b_h[i] <= 24'd0;
                            b_tx[i] <= 1'b0;
                        end
                    end
                    
                    // Calculate segment width
                    segment_width <= city_length >> 4; // D / 16
                    segment_idx <= 4'd0;
                    transmitter_idx <= 4'd0;
                    covered_length <= 32'd0;
                    for (integer i = 0; i < 16; i = i + 1) begin
                        visible_segments[i] <= 1'b0;
                    end
                    
                    next_state <= COMPUTE;
                end
                
                COMPUTE: begin
                    // Check if computation is complete
                    if (segment_idx == 4'd16) begin
                        next_state <= OUTPUT;
                    end else begin
                        // Calculate segment center
                        segment_center <= segment_width * segment_idx + (segment_width >> 1);
                        
                        // Check visibility for this segment
                        if (segment_idx < 16) begin
                            visible_segments[segment_idx] <= 1'b0;
                            for (transmitter_idx = 0; transmitter_idx < 16; transmitter_idx = transmitter_idx + 1) begin
                                if (b_tx[transmitter_idx] && transmitter_idx < num_buildings) begin
                                    // Check if transmitter can see this segment
                                    // Line from (b_x[tx], b_h[tx]) to (segment_center, 0)
                                    // Check all buildings between transmitter and segment
                                    reg [31:0] tx_x = b_x[transmitter_idx];
                                    reg [23:0] tx_h = b_h[transmitter_idx];
                                    reg visible = 1'b1;
                                    
                                    for (integer i = 0; i < 16; i = i + 1) begin
                                        if (i < num_buildings && i != transmitter_idx) begin
                                            reg [31:0] bx = b_x[i];
                                            reg [23:0] bh = b_h[i];
                                            
                                            // Check if building is between transmitter and segment
                                            if ((bx > tx_x && bx < segment_center) || (bx < tx_x && bx > segment_center)) begin
                                                // Calculate line height at building position
                                                // line_height = tx_h * (tx_x - bx) / (tx_x - segment_center)
                                                if (tx_x > segment_center) begin
                                                    // segment is left of transmitter
                                                    if (bx > segment_center && bx < tx_x) begin
                                                        numerator <= {tx_h, 16'd0} * (tx_x - bx);
                                                        denominator <= tx_x - segment_center;
                                                        
                                                        // Start division
                                                        quotient <= 32'd0;
                                                        div_iter <= 5'd0;
                                                        
                                                        // Simple fixed-point division
                                                        for (integer j = 0; j < DIV_ITERATIONS; j = j + 1) begin
                                                            if (numerator >= denominator << (DIV_ITERATIONS - j - 1)) begin
                                                                quotient <= quotient + (1 << (DIV_ITERATIONS - j - 1));
                                                                numerator <= numerator - (denominator << (DIV_ITERATIONS - j - 1));
                                                            end
                                                        end
                                                        
                                                        line_height <= quotient;
                                                        
                                                        // Compare with building height (scaled to Q16.16)
                                                        if ({bh, 8'd0} > line_height) begin
                                                            visible = 1'b0;
                                                        end
                                                    end
                                                end else if (tx_x < segment_center) begin
                                                    // segment is right of transmitter
                                                    if (bx < segment_center && bx > tx_x) begin
                                                        numerator <= {tx_h, 16'd0} * (bx - tx_x);
                                                        denominator <= segment_center - tx_x;
                                                        
                                                        // Start division
                                                        quotient <= 32'd0;
                                                        div_iter <= 5'd0;
                                                        
                                                        // Simple fixed-point division
                                                        for (integer j = 0; j < DIV_ITERATIONS; j = j + 1) begin
                                                            if (numerator >= denominator << (DIV_ITERATIONS - j - 1)) begin
                                                                quotient <= quotient + (1 << (DIV_ITERATIONS - j - 1));
                                                                numerator <= numerator - (denominator << (DIV_ITERATIONS - j - 1));
                                                            end
                                                        end
                                                        
                                                        line_height <= quotient;
                                                        
                                                        // Compare with building height (scaled to Q16.16)
                                                        if ({bh, 8'd0} > line_height) begin
                                                            visible = 1'b0;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    
                                    if (visible) begin
                                        visible_segments[segment_idx] <= 1'b1;
                                    end
                                end
                            end
                            
                            segment_idx <= segment_idx + 1;
                        end
                    end
                end
                
                OUTPUT: begin
                    // Calculate total covered length
                    covered_length <= 32'd0;
                    for (integer i = 0; i < 16; i = i + 1) begin
                        if (visible_segments[i]) begin
                            covered_length <= covered_length + segment_width;
                        end
                    end
                    
                    result <= covered_length;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
            
            // Safety check for cycle count
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
            end
        end
    end

endmodule