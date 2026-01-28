module closest_pair(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr_0,
    input wire signed [7:0] arr_1,
    input wire signed [7:0] arr_2,
    input wire signed [7:0] arr_3,
    input wire signed [7:0] arr_4,
    input wire signed [7:0] arr_5,
    input wire signed [7:0] arr_6,
    input wire signed [7:0] arr_7,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;

    // Point storage: 8 points, each with 8-bit x and 16-bit y
    reg signed [7:0] x [0:7];
    reg signed [15:0] y [0:7];

    // Prefix sum computation
    reg signed [15:0] prefix_sum [0:7];
    integer i;

    // Distance computation variables
    reg [23:0] min_dist;
    reg [23:0] current_dist;
    reg [7:0] dx, dy;
    reg [7:0] dx_sq, dy_sq;

    // Lookup tables for squared differences
    reg [7:0] dx_sq_lut [0:49];
    reg [15:0] dy_sq_lut [0:255];

    // Initialize lookup tables
    initial begin
        for (i = 0; i < 50; i = i + 1) begin
            dx_sq_lut[i] = i * i;
        end
        for (i = 0; i < 256; i = i + 1) begin
            dy_sq_lut[i] = i * i;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            min_dist <= 24'd0;
            
            // Initialize points
            for (i = 0; i < 8; i = i + 1) begin
                x[i] <= i;
                y[i] <= 16'd0;
                prefix_sum[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    // Compute prefix sums
                    prefix_sum[0] <= arr_0;
                    prefix_sum[1] <= prefix_sum[0] + arr_1;
                    prefix_sum[2] <= prefix_sum[1] + arr_2;
                    prefix_sum[3] <= prefix_sum[2] + arr_3;
                    prefix_sum[4] <= prefix_sum[3] + arr_4;
                    prefix_sum[5] <= prefix_sum[4] + arr_5;
                    prefix_sum[6] <= prefix_sum[5] + arr_6;
                    prefix_sum[7] <= prefix_sum[6] + arr_7;
                    
                    // Store points
                    for (i = 0; i < 8; i = i + 1) begin
                        x[i] <= i;
                        y[i] <= prefix_sum[i];
                    end
                    
                    if (start) begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Brute-force comparison for all pairs
                    min_dist <= 24'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (int j = i + 1; j < 8; j = j + 1) begin
                            dx <= (x[i] > x[j]) ? (x[i] - x[j]) : (x[j] - x[i]);
                            dy <= (y[i] > y[j]) ? (y[i] - y[j]) : (y[j] - y[i]);
                            
                            dx_sq <= dx_sq_lut[dx];
                            dy_sq <= dy_sq_lut[dy[7:0]];
                            
                            current_dist <= dx_sq + dy_sq;
                            
                            if (current_dist < min_dist) begin
                                min_dist <= current_dist;
                            end
                        end
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= min_dist;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule