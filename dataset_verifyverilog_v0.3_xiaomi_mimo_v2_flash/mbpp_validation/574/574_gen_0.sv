module cylinder_surface_area(
    input clk,
    input rst_n,
    input start,
    input [15:0] radius,  // Q8.8 format
    input [15:0] height,  // Q8.8 format
    output reg [31:0] result,  // Q16.16 format
    output reg done
);

    // Internal constants in Q8.8 format
    localparam [15:0] PI_FIXED = 16'd804;  // 3.14159265 * 256
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] STATE_R_SQ = 2'd1;
    localparam [1:0] STATE_TERM1 = 2'd2;
    localparam [1:0] STATE_TERM2 = 2'd3;
    localparam [1:0] STATE_FINISH = 2'd4;

    reg [1:0] state, next_state;
    reg [15:0] r_reg;  // Store radius
    reg [15:0] h_reg;  // Store height
    reg [31:0] temp;   // Temporary calculation
    reg [31:0] term1;  // First term (2*π*r²)
    reg [31:0] term2;  // Second term (2*π*r*h)

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            r_reg <= 16'd0;
            h_reg <= 16'd0;
            temp <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        r_reg <= radius;
                        h_reg <= height;
                        state <= STATE_R_SQ;
                    end
                end

                STATE_R_SQ: begin
                    // Calculate temp = radius * radius (16-bit * 16-bit = 32-bit)
                    // Input is Q8.8, so result is Q16.16
                    temp <= r_reg * r_reg;
                    state <= STATE_TERM1;
                end

                STATE_TERM1: begin
                    // Calculate term1 = 2 * PI_FIXED * temp
                    // PI_FIXED is Q8.8, temp is Q16.16
                    // (PI_FIXED * temp) >> 8 to align, then * 2
                    temp <= (temp * PI_FIXED) >> 8;
                    state <= STATE_TERM2;
                end

                STATE_TERM2: begin
                    // term1 is now properly formatted
                    term1 <= temp;
                    // Calculate temp = radius * height (Q16.16)
                    temp <= r_reg * h_reg;
                    state <= STATE_FINISH;
                end

                STATE_FINISH: begin
                    // Calculate term2 = 2 * PI_FIXED * (radius * height)
                    // temp is Q16.16 from previous multiplication
                    term2 <= (temp * PI_FIXED) >> 8;
                    result <= ((temp * PI_FIXED) >> 8) + term1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule