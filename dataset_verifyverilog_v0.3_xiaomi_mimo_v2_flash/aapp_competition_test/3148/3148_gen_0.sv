module lifeguard_positions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [7:0] x0, y0, x1, y1, x2, y2, x3, y3,
    input wire signed [7:0] x4, y4, x5, y5, x6, y6, x7, y7,
    output reg signed [15:0] A_x, A_y,
    output reg signed [15:0] B_x, B_y,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] SORT_STEP  = 3'd2;
    localparam [2:0] COMPUTE    = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] cycle_counter;
    reg [3:0] sort_index;
    reg [2:0] sort_stage; // For bubble sort stages
    
    // Array for x-coordinates (8 elements, 8-bit signed)
    reg signed [7:0] x_reg [0:7];
    reg [3:0] n_reg;
    
    // Intermediate results
    reg signed [15:0] sum_temp;
    reg signed [15:0] median;
    reg [2:0] i, j; // Loop variables for synthesis
    
    // Sorting network flags
    reg swap_needed;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            A_x <= 16'sd0;
            A_y <= 16'sd0;
            B_x <= 16'sd0;
            B_y <= 16'sd0;
            done <= 1'b0;
            cycle_counter <= 4'd0;
            sort_index <= 4'd0;
            sort_stage <= 3'd0;
            n_reg <= 4'd0;
            sum_temp <= 16'sd0;
            median <= 16'sd0;
            // Initialize x_reg array
            x_reg[0] <= 8'sd0;
            x_reg[1] <= 8'sd0;
            x_reg[2] <= 8'sd0;
            x_reg[3] <= 8'sd0;
            x_reg[4] <= 8'sd0;
            x_reg[5] <= 8'sd0;
            x_reg[6] <= 8'sd0;
            x_reg[7] <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 4'd0;
                    if (start) begin
                        state <= LOAD;
                        n_reg <= n;
                    end
                end

                LOAD: begin
                    // Latch all 8 inputs (only first n are valid)
                    x_reg[0] <= x0;
                    x_reg[1] <= x1;
                    x_reg[2] <= x2;
                    x_reg[3] <= x3;
                    x_reg[4] <= x4;
                    x_reg[5] <= x5;
                    x_reg[6] <= x6;
                    x_reg[7] <= x7;
                    sort_stage <= 3'd0;
                    sort_index <= 4'd0;
                    state <= SORT_STEP;
                end

                SORT_STEP: begin
                    // Simple Bubble Sort implementation for 8 elements
                    // Comparing adjacent elements based on sort_index and sort_stage
                    
                    if (sort_stage < 3'd7) begin
                        if (sort_index < (8'd8 - 1 - sort_stage)) begin
                            // Compare and swap if needed
                            if (x_reg[sort_index] > x_reg[sort_index + 1]) begin
                                x_reg[sort_index] <= x_reg[sort_index + 1];
                                x_reg[sort_index + 1] <= x_reg[sort_index];
                            end
                            sort_index <= sort_index + 4'd1;
                        end else begin
                            sort_index <= 4'd0;
                            sort_stage <= sort_stage + 3'd1;
                        end
                        cycle_counter <= cycle_counter + 4'd1;
                    end else begin
                        // Sorting complete, move to compute
                        state <= COMPUTE;
                        cycle_counter <= 4'd0;
                    end
                    
                    // Safety timeout
                    if (cycle_counter >= 4'd15) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Calculate median
                    if (n_reg[0] == 1'b0) begin // Even number of swimmers
                        // Median is average of two middle values
                        // Middle indices are (n/2 - 1) and (n/2)
                        if (n_reg == 4'd2) begin
                            sum_temp <= x_reg[0] + x_reg[1];
                            median <= (x_reg[0] + x_reg[1]) >>> 1;
                        end else if (n_reg == 4'd4) begin
                            sum_temp <= x_reg[1] + x_reg[2];
                            median <= (x_reg[1] + x_reg[2]) >>> 1;
                        end else if (n_reg == 4'd6) begin
                            sum_temp <= x_reg[2] + x_reg[3];
                            median <= (x_reg[2] + x_reg[3]) >>> 1;
                        end else if (n_reg == 4'd8) begin
                            sum_temp <= x_reg[3] + x_reg[4];
                            median <= (x_reg[3] + x_reg[4]) >>> 1;
                        end else begin
                            // Default fallback (shouldn't happen)
                            median <= x_reg[0];
                        end
                    end else begin // Odd number of swimmers
                        // Median is the middle value
                        if (n_reg == 4'd1) begin
                            median <= x_reg[0];
                        end else if (n_reg == 4'd3) begin
                            median <= x_reg[1];
                        end else if (n_reg == 4'd5) begin
                            median <= x_reg[2];
                        end else if (n_reg == 4'd7) begin
                            median <= x_reg[3];
                        end else begin
                            median <= x_reg[0];
                        end
                    end
                    
                    // Calculate final positions (A: median-100, B: median+100)
                    // Note: x_reg is 8-bit, median is 16-bit
                    A_x <= (median - 16'sd100);
                    A_y <= 16'sd0;
                    B_x <= (median + 16'sd100);
                    B_y <= 16'sd0;
                    
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule