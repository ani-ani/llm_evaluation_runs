module find_solution(
    input clk,
    input rst_n,
    input start,
    input [15:0] a,  // Q8.8
    input [15:0] b,  // Q8.8
    input [15:0] n,  // Q8.8
    output reg [7:0] x,
    output reg [7:0] y,
    output reg done,
    output reg valid
);

// State declarations
localparam [2:0] IDLE      = 3'd0;
localparam [2:0] COMPUTE   = 3'd1;
localparam [2:0] CHECK     = 3'd2;
localparam [2:0] VALIDATE  = 3'd3;
localparam [2:0] OUTPUT    = 3'd4;
localparam [2:0] FINISH    = 3'd5;

reg [2:0] state;
reg [7:0] x_count;           // Counter for x from 0 to 255
reg [7:0] x_reg;             // Registered x value
reg [15:0] ax;               // a * x (16-bit result)
reg [15:0] diff;             // n - a*x
reg [7:0] y_temp;            // Calculated y value
reg div_valid;               // Division validity flag
reg [7:0] cycle_count;       // Safety counter
localparam [7:0] MAX_CYCLES = 8'd200;  // For state transitions

// Combinational signals for division check
reg [15:0] num_div;          // Numerator for division
reg [15:0] denom_div;        // Denominator for division
reg [15:0] quotient;         // Division result
reg [15:0] remainder;        // Division remainder
reg [7:0] y_check;           // Check if y is within bounds

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        x <= 8'd0;
        y <= 8'd0;
        done <= 1'b0;
        valid <= 1'b0;
        x_count <= 8'd0;
        x_reg <= 8'd0;
        ax <= 16'd0;
        diff <= 16'd0;
        y_temp <= 8'd0;
        div_valid <= 1'b0;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                x_count <= 8'd0;
                x_reg <= 8'd0;
                cycle_count <= 8'd0;
                if (start) begin
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Calculate a * x (multiply by integer x, ignore fractional parts)
                // Q8.8 * integer -> need to shift right by 8
                ax <= (a * x_count) >> 8;
                
                state <= CHECK;
            end
            
            CHECK: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Calculate diff = n - ax
                diff <= n - ax;
                x_reg <= x_count;
                
                // Check if diff is positive (unsigned comparison)
                if (n >= ax) begin
                    // Prepare for division check
                    num_div <= n - ax;
                    denom_div <= b;
                    state <= VALIDATE;
                end else begin
                    // diff is negative, no solution for this x
                    if (x_count < 8'd255) begin
                        x_count <= x_count + 8'd1;
                        state <= COMPUTE;
                    end else begin
                        state <= FINISH;
                    end
                end
            end
            
            VALIDATE: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Perform division: check if num_div is divisible by b
                // For fixed-point: integer division only
                quotient <= num_div / denom_div;
                remainder <= num_div % denom_div;
                
                state <= OUTPUT;
            end
            
            OUTPUT: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Check if division is exact (remainder == 0)
                if (remainder == 16'd0) begin
                    // Check if quotient fits in 8-bit (0-255)
                    if (quotient[15:8] == 8'd0) begin
                        y_temp <= quotient[7:0];
                        div_valid <= 1'b1;
                    end else begin
                        div_valid <= 1'b0;
                    end
                end else begin
                    div_valid <= 1'b0;
                end
                
                state <= FINISH;  // Will check in FINISH
            end
            
            FINISH: begin
                if (div_valid && (y_temp <= 8'd255)) begin
                    // Valid solution found
                    x <= x_reg;
                    y <= y_temp;
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end else if (x_count < 8'd255) begin
                    // Continue searching
                    done <= 1'b0;
                    valid <= 1'b0;
                    x_count <= x_count + 8'd1;
                    state <= COMPUTE;
                end else begin
                    // No solution found
                    done <= 1'b1;
                    valid <= 1'b0;
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule