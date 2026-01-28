module sector_area(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] radius,
    input wire [15:0] angle,
    output reg [31:0] result,
    output reg done,
    output reg invalid
);

    // Fixed-point constants
    localparam [31:0] PI_Q16 = 32'd205887;  // PI in Q16.16 format
    localparam [15:0] ANGLE_360 = 16'd92160;  // 360 in Q8.8 format
    localparam [31:0] INV_360_Q16 = 32'd182;  // 1/360 in Q16.16 format

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state;
    reg [1:0] next_state;

    // Internal registers
    reg [31:0] r_squared;
    reg [31:0] pi_r_sq;
    reg [31:0] angle_norm;
    reg [31:0] result_temp;

    // State transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK;
                else
                    next_state = IDLE;
            end
            CHECK: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
            invalid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    invalid <= 1'b0;
                end
                CHECK: begin
                    if (angle > ANGLE_360) begin
                        invalid <= 1'b1;
                        result <= 32'd0;
                    end else begin
                        invalid <= 1'b0;
                        r_squared <= (radius * radius) >> 8;
                    end
                end
                COMPUTE: begin
                    if (!invalid) begin
                        pi_r_sq <= (PI_Q16 * r_squared) >> 16;
                        angle_norm <= (angle * INV_360_Q16) >> 8;
                        result_temp <= (pi_r_sq * angle_norm);
                    end
                end
                DONE: begin
                    if (!invalid) begin
                        result <= result_temp >> 16;
                    end
                    done <= 1'b1;
                end
                default: begin
                    result <= 32'd0;
                    done <= 1'b0;
                    invalid <= 1'b0;
                end
            endcase
        end
    end

endmodule