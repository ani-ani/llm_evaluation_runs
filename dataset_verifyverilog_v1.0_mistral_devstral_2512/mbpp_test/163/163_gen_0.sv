module PolygonAreaCalculator(
    input clk,
    input rst_n,
    input start,
    input [3:0] sides,
    input [15:0] length,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] WAIT_START = 3'd1;
    localparam [2:0] LOAD_INPUTS = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Internal registers
    reg [31:0] length_squared;
    reg [31:0] tan_value;
    reg [31:0] numerator;
    reg [31:0] denominator;
    reg [31:0] quotient;
    reg [31:0] temp_result;
    reg [3:0] current_sides;
    reg [15:0] current_length;

    // Lookup table for tan(π/s) in Q16.16 format
    localparam [31:0] TAN_TABLE [0:15] = '{ 
        32'd0,            // s=0 (invalid)
        32'd0,            // s=1 (invalid)
        32'd0,            // s=2 (invalid)
        32'd113515,       // s=3
        32'd65536,        // s=4
        32'd47622,        // s=5
        32'd37838,        // s=6
        32'd31565,        // s=7
        32'd27146,        // s=8
        32'd23856,        // s=9
        32'd21298,        // s=10
        32'd19243,        // s=11
        32'd17560,        // s=12
        32'd16154,        // s=13
        32'd14957,        // s=14
        32'd13931         // s=15
    };

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            length_squared <= 32'd0;
            tan_value <= 32'd0;
            numerator <= 32'd0;
            denominator <= 32'd0;
            quotient <= 32'd0;
            temp_result <= 32'd0;
            current_sides <= 4'd0;
            current_length <= 16'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    next_state <= WAIT_START;
                end

                WAIT_START: begin
                    if (start) begin
                        next_state <= LOAD_INPUTS;
                    end else begin
                        next_state <= WAIT_START;
                    end
                end

                LOAD_INPUTS: begin
                    current_sides <= sides;
                    current_length <= length;
                    if (current_sides < 3) begin
                        error <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        error <= 1'b0;
                        next_state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate length squared (Q8.8 * Q8.8 = Q16.16)
                    length_squared <= {16'd0, current_length} * {16'd0, current_length};
                    
                    // Get tan value from lookup table
                    tan_value <= TAN_TABLE[current_sides];
                    
                    // Multiply by sides (4-bit * 32-bit = 36-bit, truncate to 32-bit)
                    numerator <= length_squared * current_sides;
                    
                    // Multiply by 1/4 (shift right by 2)
                    numerator <= numerator >> 2;
                    
                    // Division: numerator / tan_value
                    // Using iterative division (simplified for synthesis)
                    if (cycle_count == 8'd1) begin
                        quotient <= 32'd0;
                    end else if (cycle_count > 8'd1 && cycle_count <= 8'd18) begin
                        // Simple iterative division approach
                        // This is a placeholder - in real implementation, use proper division algorithm
                        quotient <= numerator / tan_value;
                    end
                    
                    // Check if computation is complete
                    if (cycle_count >= 8'd18 || cycle_count >= MAX_CYCLES) begin
                        temp_result <= quotient;
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= CALCULATE;
                    end
                end

                OUTPUT: begin
                    result <= temp_result;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    error <= 1'b0;
                end
            endcase
        end
    end

endmodule