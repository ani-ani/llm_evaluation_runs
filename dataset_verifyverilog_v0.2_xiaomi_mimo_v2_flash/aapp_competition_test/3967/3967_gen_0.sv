module bamboo_solver(
    input clk,
    input rst_n,
    input start,
    input stop,
    input [7:0] a_0,
    input [7:0] a_1,
    input [7:0] a_2,
    input [7:0] a_3,
    input [11:0] k,
    output reg [11:0] best_d,
    output reg [11:0] current_waste,
    output reg searching,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SEARCHING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [11:0] d; // Current trial interval
    
    // Combinational waste calculation logic
    // The ceil division (a_i + d - 1) / d requires d to be 12-bit for consistent width
    // Waste is defined as (d * ceil) - a_i
    wire [22:0] waste_calc_0; // 12 + 11 = 23 bits max
    wire [22:0] waste_calc_1;
    wire [22:0] waste_calc_2;
    wire [22:0] waste_calc_3;
    
    // Combined waste signal to check against k
    wire [12:0] total_waste; // 13 bits max (4 * 255 = 1020 fits in 10, but generic 13 safe)
    
    // Helper signals for ceil division
    // We need to treat d as 12-bit in the divisor to match numerator width logic
    // But d itself is an output of a counter that stops at 4095.
    
    // Perform waste calculations
    // Note: (a_i + d - 1) / d performs the ceil operation in integer math.
    // To be safe with synthesis and widths, we extend d to 12-bit context.
    // However, d is always <= 4095 in valid operation.
    
    assign waste_calc_0 = (d * ((a_0 + d - 1) / d)) - a_0;
    assign waste_calc_1 = (d * ((a_1 + d - 1) / d)) - a_1;
    assign waste_calc_2 = (d * ((a_2 + d - 1) / d)) - a_2;
    assign waste_calc_3 = (d * ((a_3 + d - 1) / d)) - a_3;

    // Summation with truncation to expected output width (12 bits)
    // We assume the total waste fits in 12 bits as per problem context (k is 12-bit).
    assign total_waste = waste_calc_0[11:0] + waste_calc_1[11:0] + waste_calc_2[11:0] + waste_calc_3[11:0];

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            best_d <= 0;
            current_waste <= 0;
            d <= 0;
            searching <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    searching <= 0;
                    done <= 0;
                    best_d <= 0;
                    current_waste <= 0;
                    d <= 1; // Prepare d=1 for the first iteration
                    if (start) begin
                        state <= SEARCHING;
                        searching <= 1;
                    end
                end

                SEARCHING: begin
                    // 'd' is currently valid (1 to 4095)
                    // Check termination conditions
                    // We terminate if stop is asserted OR if we just checked d=4095.
                    // Note: The check for d=4095 happens in this cycle.
                    
                    if (stop) begin
                        // Stop signal overrides everything. We don't check current d.
                        // We finish immediately with whatever best_d we had.
                        state <= DONE;
                        searching <= 0;
                        done <= 1;
                        d <= 0;
                    end else if (d == 4095) begin
                        // Last valid d. Check it.
                        if (total_waste <= k) begin
                            best_d <= d;
                            current_waste <= total_waste;
                        end else begin
                            // Keep previous best_d
                            // current_waste is updated to reflect this d's waste (as per requirement 4: output current_waste)
                            current_waste <= total_waste;
                        end
                        state <= DONE;
                        searching <= 0;
                        done <= 1;
                        d <= 0;
                    end else begin
                        // Normal iteration: d < 4095 and !stop
                        // Check current d
                        if (total_waste <= k) begin
                            best_d <= d;
                            current_waste <= total_waste;
                        end else begin
                            current_waste <= total_waste;
                        end
                        // Increment d
                        d <= d + 1;
                    end
                end

                DONE: begin
                    // Stay here until reset
                    searching <= 0;
                    done <= 1;
                    d <= 0;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
