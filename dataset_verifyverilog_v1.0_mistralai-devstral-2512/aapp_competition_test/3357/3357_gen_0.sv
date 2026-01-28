module sunlight_hours_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] building_x,
    input wire [15:0] building_h,
    input wire input_valid,
    input wire input_done,
    output reg [15:0] result,
    output reg [3:0] result_index,
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Building storage (max 16 buildings)
    reg [15:0] x_ram [0:15];
    reg [15:0] h_ram [0:15];
    reg [3:0] building_count;
    
    // Processing variables
    reg [3:0] i_reg, j_reg;
    reg [15:0] min_angle;
    reg [15:0] current_angle;
    reg [15:0] delta_x, delta_h;
    reg [15:0] temp_result;
    
    // Cycle counter for safety
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd2000;
    
    // Fixed-point division lookup table (approximation)
    function [15:0] fixed_divide;
        input [15:0] numerator;
        input [15:0] denominator;
        reg [15:0] result;
        reg [15:0] remainder;
        integer i;
        begin
            if (denominator == 16'd0) begin
                result = 16'd0;
            end else begin
                remainder = numerator;
                result = 16'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    remainder = remainder << 1;
                    if (remainder[16]) begin
                        remainder = remainder - denominator;
                        result[15 - i] = 1'b1;
                    end
                end
            end
            fixed_divide = result;
        end
    endfunction
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            building_count <= 4'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            min_angle <= 16'd0;
            current_angle <= 16'd0;
            delta_x <= 16'd0;
            delta_h <= 16'd0;
            temp_result <= 16'd0;
            result <= 16'd0;
            result_index <= 4'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 11'd0;
            
            // Initialize RAM
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                x_ram[k] <= 16'd0;
                h_ram[k] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    if (start) begin
                        next_state <= INPUT;
                    end
                end
                
                INPUT: begin
                    if (input_valid) begin
                        x_ram[building_count] <= building_x;
                        h_ram[building_count] <= building_h;
                        building_count <= building_count + 4'd1;
                    end
                    if (input_done) begin
                        next_state <= PROCESS;
                        i_reg <= 4'd0;
                        min_angle <= 16'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 11'd1;
                    
                    // Process building i_reg
                    if (j_reg == 4'd0) begin
                        min_angle <= 16'd180;  // Start with max angle
                    end
                    
                    if (j_reg < building_count) begin
                        // Calculate angle for building j_reg
                        if (x_ram[j_reg] < x_ram[i_reg]) begin
                            delta_x <= x_ram[i_reg] - x_ram[j_reg];
                            delta_h <= h_ram[i_reg] - h_ram[j_reg];
                            if (delta_h > 16'd0) begin
                                current_angle <= fixed_divide(delta_h, delta_x);
                                if (current_angle < min_angle) begin
                                    min_angle <= current_angle;
                                end
                            end
                        end else if (x_ram[j_reg] > x_ram[i_reg]) begin
                            delta_x <= x_ram[j_reg] - x_ram[i_reg];
                            delta_h <= h_ram[i_reg] - h_ram[j_reg];
                            if (delta_h > 16'd0) begin
                                current_angle <= fixed_divide(delta_h, delta_x);
                                if (current_angle < min_angle) begin
                                    min_angle <= current_angle;
                                end
                            end
                        end
                        
                        j_reg <= j_reg + 4'd1;
                    end else begin
                        // Finished processing building i_reg
                        temp_result <= 16'd180 - min_angle;
                        if (temp_result < 16'd0) begin
                            temp_result <= 16'd0;
                        end
                        
                        result <= temp_result;
                        result_index <= i_reg;
                        result_valid <= 1'b1;
                        
                        i_reg <= i_reg + 4'd1;
                        j_reg <= 4'd0;
                        
                        if (i_reg >= building_count) begin
                            next_state <= DONE;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end
                
                OUTPUT: begin
                    result_valid <= 1'b0;
                    next_state <= IDLE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Default assignments for outputs
    assign result = result;
    assign result_index = result_index;
    assign result_valid = result_valid;
    assign done = done;

endmodule