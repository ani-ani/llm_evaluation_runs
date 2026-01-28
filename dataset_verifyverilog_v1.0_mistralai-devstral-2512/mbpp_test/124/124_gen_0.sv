module complex_angle_calculator(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] a,
    input signed [15:0] b,
    output reg signed [31:0] angle,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;

    // Internal signals for CORDIC
    reg signed [15:0] x, y;
    reg signed [16:0] z;
    reg signed [15:0] x_next, y_next;
    reg signed [16:0] z_next;
    reg [3:0] i;
    
    // CORDIC constants (atan(2^-i) in Q16.16 format)
    localparam signed [16:0] atan_table [0:15] = '{
        16'd32768,  // atan(1) = pi/4
        16'd19661,  // atan(0.5)
        16'd10430,  // atan(0.25)
        16'd5243,   // atan(0.125)
        16'd2623,   // atan(0.0625)
        16'd1312,   // atan(0.03125)
        16'd656,    // atan(0.015625)
        16'd328,    // atan(0.0078125)
        16'd164,    // atan(0.00390625)
        16'd82,     // atan(0.001953125)
        16'd41,     // atan(0.0009765625)
        16'd20,     // atan(0.00048828125)
        16'd10,     // atan(0.000244140625)
        16'd5,      // atan(0.0001220703125)
        16'd2,      // atan(0.00006103515625)
        16'd1       // atan(0.000030517578125)
    };

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            angle <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            x <= 16'd0;
            y <= 16'd0;
            z <= 17'd0;
            i <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize CORDIC values
                        x <= a;
                        y <= b;
                        z <= 17'd0;
                        i <= 4'd0;
                        cycle_count <= 8'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // CORDIC iteration
                    if (y[15]) begin
                        x_next <= x + (y >>> i);
                        y_next <= y - (x >>> i);
                        z_next <= z - atan_table[i];
                    end else begin
                        x_next <= x - (y >>> i);
                        y_next <= y + (x >>> i);
                        z_next <= z + atan_table[i];
                    end
                    
                    x <= x_next;
                    y <= y_next;
                    z <= z_next;
                    i <= i + 4'd1;
                    
                    // Check if done with iterations
                    if (i == 4'd16 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Handle special cases
                    if (a == 16'd0 && b == 16'd0) begin
                        angle <= 32'd0;
                    end else begin
                        // Convert CORDIC result to Q16.16 format
                        angle <= {z[16], z[15:0]};
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule