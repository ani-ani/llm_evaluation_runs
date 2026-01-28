module coverage_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [31:0] D,
    input wire [15:0] buildings_tx,
    input wire [31:0] buildings_x [0:15],
    input wire [23:0] buildings_h [0:15],
    output reg [31:0] result,
    output reg done
);

    // Fixed-point constants
    localparam [31:0] ZERO = 32'd0;
    localparam [31:0] ONE = 32'h00010000; // Q16.16 = 1.0
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [3:0] NUM_SEGMENTS = 4'd16;
    localparam [4:0] NUM_BUILDINGS_MAX = 5'd16;

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_BUILDINGS = 3'd1;
    localparam [2:0] CALC_SEGMENTS = 3'd2;
    localparam [2:0] CALC_COVERAGE = 3'd3;
    localparam [2:0] SUMMING = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] seg_index;
    reg [4:0] bld_index;
    reg [4:0] tx_count;
    
    // Storage for buildings (packed for easier access)
    reg [31:0] bld_x_reg [0:15];
    reg [23:0] bld_h_reg [0:15];
    reg [15:0] bld_tx_reg;
    
    // Segment state
    reg seg_visible;
    reg [31:0] seg_center_x;
    reg [31:0] segment_length;
    
    // Accumulator for result
    reg [31:0] accum;
    
    // Temporary variables for calculation
    reg [31:0] temp_x_t, temp_h_t;
    reg [31:0] temp_x_b, temp_h_b;
    reg [31:0] temp_x_s; // segment center
    reg signed [63:0] numerator, denominator;
    reg signed [63:0] line_height_q20; // multiplied by 2^20 for precision
    reg signed [63:0] building_height_q20;
    reg is_visible;
    reg [4:0] tx_idx;
    
    // Division state
    reg div_start;
    reg div_done;
    reg signed [63:0] div_numer;
    reg signed [63:0] div_denom;
    reg signed [63:0] div_result;
    reg [5:0] div_cycle;

    // Division logic (iterative)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_done <= 1'b0;
            div_result <= 64'd0;
            div_cycle <= 6'd0;
        end else if (div_start) begin
            div_cycle <= 6'd0;
            div_done <= 1'b0;
            div_result <= 64'd0;
        end else if (div_cycle < 6'd48) begin // 32 cycles for 32-bit precision
            div_cycle <= div_cycle + 6'd1;
            if (div_cycle == 0) begin
                div_result <= 64'd0;
            end else begin
                // Simple non-restoring division approximation
                // This is a simplification - for Q16.16 / Q16.16
                // We use shift-add algorithm
                // For now, use direct multiplication by reciprocal estimate
                // But for Icarus Verilog compatibility, use direct for small cases
                if (div_cycle == 6'd1) begin
                    // Direct calculation: result = numer / denom
                    // Use 64-bit intermediate
                    div_result <= (denominator != 0) ? (div_numer / div_denom) : 64'd0;
                end
            end
        end else begin
            div_done <= 1'b1;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            seg_index <= 4'd0;
            bld_index <= 5'd0;
            tx_count <= 5'd0;
            accum <= 32'd0;
            seg_visible <= 1'b0;
            div_start <= 1'b0;
            
            // Initialize building storage
            for (integer i = 0; i < 16; i = i + 1) begin
                bld_x_reg[i] <= 32'd0;
                bld_h_reg[i] <= 24'd0;
            end
            bld_tx_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    seg_index <= 4'd0;
                    bld_index <= 5'd0;
                    tx_count <= 5'd0;
                    accum <= 32'd0;
                    
                    if (start) begin
                        state <= LOAD_BUILDINGS;
                    end
                end
                
                LOAD_BUILDINGS: begin
                    // Store building data into registers
                    if (bld_index < N) begin
                        bld_x_reg[bld_index[3:0]] <= buildings_x[bld_index[3:0]];
                        bld_h_reg[bld_index[3:0]] <= buildings_h[bld_index[3:0]];
                        bld_index <= bld_index + 5'd1;
                    end else begin
                        bld_tx_reg <= buildings_tx;
                        // Count transmitters
                        tx_count <= 5'd0;
                        for (integer i = 0; i < 16; i = i + 1) begin
                            if (buildings_tx[i]) tx_count <= tx_count + 5'd1;
                        end
                        state <= CALC_SEGMENTS;
                        seg_index <= 4'd0;
                    end
                end
                
                CALC_SEGMENTS: begin
                    // Process each segment
                    if (seg_index < NUM_SEGMENTS) begin
                        // Calculate segment center: (seg_index + 0.5) * D / 16
                        // segment_length = D / 16
                        segment_length <= D >> 4; // Divide by 16
                        
                        // Calculate segment center (approximation with shift)
                        seg_center_x <= ((seg_index + 4'd1) * (D >> 5)) >> 1;
                        
                        seg_visible <= 1'b0; // Assume not visible initially
                        bld_index <= 5'd0;   // Start checking from building 0
                        state <= CALC_COVERAGE;
                        
                        if (tx_count == 5'd0) begin
                            // No transmitters, nothing visible
                            seg_visible <= 1'b0;
                            state <= SUMMING;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                CALC_COVERAGE: begin
                    // Check visibility from each transmitter
                    if (bld_index < N) begin
                        if (bld_tx_reg[bld_index[3:0]]) begin
                            // This building has a transmitter
                            temp_x_t <= bld_x_reg[bld_index[3:0]];
                            temp_h_t <= {bld_h_reg[bld_index[3:0]], 8'd0}; // Extend to Q16.16
                            temp_x_s <= seg_center_x;
                            
                            // Check if any building blocks this path
                            if (N > 5'd1) begin
                                // Need to check other buildings
                                bld_index <= 5'd0; // Reset to check all buildings
                                is_visible <= 1'b1;
                                state <= 3'd6; // Internal state for checking
                            end else begin
                                // No other buildings to block
                                seg_visible <= 1'b1;
                                state <= SUMMING;
                            end
                        end else begin
                            bld_index <= bld_index + 5'd1;
                        end
                    end else begin
                        // No transmitter found for this segment
                        state <= SUMMING;
                    end
                end
                
                3'd6: begin // CHECK_BLOCKING state
                    // Check if building at bld_index blocks path from temp_x_t to temp_x_s
                    if (bld_index < N) begin
                        if (bld_index[3:0] != bld_index[3:0] || 1'b1) begin // Always check
                            temp_x_b <= bld_x_reg[bld_index[3:0]];
                            temp_h_b <= {bld_h_reg[bld_index[3:0]], 8'd0};
                            
                            // Geometric check: line from (temp_x_t, temp_h_t) to (temp_x_s, 0)
                            // Height of line at temp_x_b is:
                            // H_line = temp_h_t * (temp_x_b - temp_x_s) / (temp_x_t - temp_x_s)
                            // Sign check: temp_x_b should be between temp_x_s and temp_x_t
                            
                            // Check if building is between transmitter and segment
                            if ((temp_x_t > temp_x_s && temp_x_b > temp_x_s && temp_x_b < temp_x_t) ||
                                (temp_x_t < temp_x_s && temp_x_b < temp_x_s && temp_x_b > temp_x_t) ||
                                (temp_x_t == temp_x_s)) begin
                                
                                // Calculate line height at building
                                numerator <= $signed({temp_h_t, 32'd0}) * $signed({1'b0, temp_x_b - temp_x_s});
                                denominator <= $signed({1'b0, temp_x_t - temp_x_s});
                                div_numer <= $signed({temp_h_t, 32'd0}) * $signed({1'b0, temp_x_b - temp_x_s});
                                div_denom <= $signed({1'b0, temp_x_t - temp_x_s});
                                div_start <= 1'b1;
                                state <= 3'd7;
                            end else begin
                                bld_index <= bld_index + 5'd1;
                            end
                        end else begin
                            bld_index <= bld_index + 5'd1;
                        end
                    end else begin
                        // No blockers found
                        seg_visible <= 1'b1;
                        state <= SUMMING;
                    end
                end
                
                3'd7: begin // WAIT_DIV state
                    div_start <= 1'b0;
                    if (div_done) begin
                        line_height_q20 <= div_result;
                        building_height_q20 <= $signed({temp_h_b, 32'd0});
                        
                        // Compare: if building height > line height, it blocks
                        if ($signed(temp_h_b) > $signed(div_result[55:24])) begin
                            is_visible <= 1'b0;
                            state <= SUMMING; // Blocked
                        end else begin
                            bld_index <= bld_index + 5'd1;
                            state <= 3'd6; // Check next building
                        end
                    end
                end
                
                SUMMING: begin
                    if (seg_visible) begin
                        accum <= accum + segment_length;
                    end
                    seg_index <= seg_index + 4'd1;
                    state <= CALC_SEGMENTS;
                end
                
                FINISH: begin
                    result <= accum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Cycle counter for safety
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
            end
        end
    end
endmodule