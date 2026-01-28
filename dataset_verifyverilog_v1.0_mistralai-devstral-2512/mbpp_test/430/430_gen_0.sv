module directrix_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] a,
    input wire signed [7:0] b,
    input wire signed [7:0] c,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] COMPUTE_1 = 4'd1;
    localparam [3:0] COMPUTE_2 = 4'd2;
    localparam [3:0] COMPUTE_3 = 4'd3;
    localparam [3:0] COMPUTE_4 = 4'd4;
    localparam [3:0] COMPUTE_5 = 4'd5;
    localparam [3:0] COMPUTE_6 = 4'd6;
    localparam [3:0] COMPUTE_7 = 4'd7;
    localparam [3:0] COMPUTE_8 = 4'd8;
    localparam [3:0] COMPUTE_9 = 4'd9;
    localparam [3:0] COMPUTE_10 = 4'd10;
    localparam [3:0] COMPUTE_11 = 4'd11;
    localparam [3:0] COMPUTE_12 = 4'd12;
    localparam [3:0] COMPUTE_13 = 4'd13;
    localparam [3:0] COMPUTE_14 = 4'd14;
    localparam [3:0] COMPUTE_15 = 4'd15;
    localparam [3:0] FINISH     = 4'd16;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Intermediate registers
    reg signed [15:0] a_ext;
    reg signed [15:0] b_ext;
    reg signed [15:0] c_ext;
    reg signed [15:0] b_squared;
    reg signed [15:0] b_squared_plus_1;
    reg signed [31:0] c_4a;
    reg signed [31:0] numerator;
    reg signed [31:0] denominator;
    reg signed [31:0] division_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            a_ext <= 16'd0;
            b_ext <= 16'd0;
            c_ext <= 16'd0;
            b_squared <= 16'd0;
            b_squared_plus_1 <= 16'd0;
            c_4a <= 32'd0;
            numerator <= 32'd0;
            denominator <= 32'd0;
            division_result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_1;
                    end
                end

                COMPUTE_1: begin
                    cycle_count <= cycle_count + 8'd1;
                    a_ext <= {{8{a[7]}}, a};
                    b_ext <= {{8{b[7]}}, b};
                    c_ext <= {{8{c[7]}}, c};
                    state <= COMPUTE_2;
                end

                COMPUTE_2: begin
                    cycle_count <= cycle_count + 8'd1;
                    b_squared <= b_ext * b_ext;
                    state <= COMPUTE_3;
                end

                COMPUTE_3: begin
                    cycle_count <= cycle_count + 8'd1;
                    b_squared_plus_1 <= b_squared + 16'd1;
                    state <= COMPUTE_4;
                end

                COMPUTE_4: begin
                    cycle_count <= cycle_count + 8'd1;
                    c_4a <= c_ext * 4'd4 * a_ext;
                    state <= COMPUTE_5;
                end

                COMPUTE_5: begin
                    cycle_count <= cycle_count + 8'd1;
                    numerator <= {{16'b0}, c_4a} - {{16'b0}, b_squared_plus_1};
                    state <= COMPUTE_6;
                end

                COMPUTE_6: begin
                    cycle_count <= cycle_count + 8'd1;
                    denominator <= 4'd4 * a_ext;
                    state <= COMPUTE_7;
                end

                COMPUTE_7: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Handle division by zero
                    if (denominator == 32'd0) begin
                        division_result <= 32'd0;
                        state <= COMPUTE_15;
                    end else begin
                        // Sign extension for proper division
                        division_result <= numerator / denominator;
                        state <= COMPUTE_8;
                    end
                end

                COMPUTE_8: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if we need to adjust for floor
                    if (numerator[0] && denominator != 32'd0) begin
                        // Negative result, check remainder
                        state <= COMPUTE_9;
                    end else begin
                        state <= COMPUTE_15;
                    end
                end

                COMPUTE_9: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate remainder
                    if (numerator % denominator != 32'd0) begin
                        state <= COMPUTE_10;
                    end else begin
                        state <= COMPUTE_15;
                    end
                end

                COMPUTE_10: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Subtract 1 for floor operation
                    division_result <= division_result - 32'd1;
                    state <= COMPUTE_15;
                end

                COMPUTE_11: begin
                    cycle_count <= cycle_count + 8'd1;
                    state <= COMPUTE_12;
                end

                COMPUTE_12: begin
                    cycle_count <= cycle_count + 8'd1;
                    state <= COMPUTE_13;
                end

                COMPUTE_13: begin
                    cycle_count <= cycle_count + 8'd1;
                    state <= COMPUTE_14;
                end

                COMPUTE_14: begin
                    cycle_count <= cycle_count + 8'd1;
                    state <= COMPUTE_15;
                end

                COMPUTE_15: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= division_result[15:0];
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule