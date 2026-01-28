module cylinder_lateral_area(
    input clk,
    input rst_n,
    input start,
    input [15:0] radius,
    input [15:0] height,
    output reg [31:0] area,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] STAGE1  = 2'd1;
    localparam [1:0] STAGE2  = 2'd2;
    localparam [1:0] STAGE3  = 2'd3;
    localparam [1:0] FINISH  = 2'd4;

    // Constants
    localparam [31:0] PI_CONST = 32'd205891;  // 2 * PI * 2^16 ≈ 205891

    // Internal registers
    reg [1:0] state;
    reg [31:0] mult1_result;
    reg [31:0] mult2_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area <= 32'd0;
            done <= 1'b0;
            mult1_result <= 32'd0;
            mult2_result <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= STAGE1;
                    end
                end

                STAGE1: begin
                    cycle_count <= cycle_count + 8'd1;
                    mult1_result <= PI_CONST * radius;
                    state <= STAGE2;
                end

                STAGE2: begin
                    cycle_count <= cycle_count + 8'd1;
                    mult2_result <= mult1_result * height;
                    state <= STAGE3;
                end

                STAGE3: begin
                    cycle_count <= cycle_count + 8'd1;
                    area <= mult2_result[47:16];  // Right shift 16 bits for Q16.16
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