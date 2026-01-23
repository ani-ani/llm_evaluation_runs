module sector_area (
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
    localparam [31:0] PI_Q16 = 205887;
    localparam [15:0] ANGLE_360 = 92160;
    localparam [31:0] INV_360_Q16 = 182;

    // State machine states
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK    = 3'd1;
    localparam [2:0] COMPUTE1 = 3'd2;
    localparam [2:0] COMPUTE2 = 3'd3;
    localparam [2:0] COMPUTE3 = 3'd4;
    localparam [2:0] DONE     = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [31:0] r_squared;
    reg [31:0] pi_r_sq;
    reg [31:0] angle_norm;
    reg [31:0] result_temp;
    reg start_reg;
    reg angle_reg;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_reg)
                    next_state = CHECK;
                else
                    next_state = IDLE;
            end
            CHECK: next_state = COMPUTE1;
            COMPUTE1: next_state = COMPUTE2;
            COMPUTE2: next_state = COMPUTE3;
            COMPUTE3: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            invalid <= 1'b0;
            r_squared <= 32'd0;
            pi_r_sq <= 32'd0;
            angle_norm <= 32'd0;
            result_temp <= 32'd0;
            start_reg <= 1'b0;
            angle_reg <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            start_reg <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && !start_reg) begin
                        // Capture angle validity
                        angle_reg <= (angle > ANGLE_360);
                    end
                end
                
                CHECK: begin
                    if (angle_reg) begin
                        invalid <= 1'b1;
                        result <= 32'd0;
                    end else begin
                        invalid <= 1'b0;
                        // r^2 = (radius * radius) >> 8
                        r_squared <= (radius * radius) >> 8;
                    end
                end
                
                COMPUTE1: begin
                    if (!invalid) begin
                        // pi_r_sq = (PI_Q16 * r_squared) >> 16
                        pi_r_sq <= (PI_Q16 * r_squared) >> 16;
                    end
                end
                
                COMPUTE2: begin
                    if (!invalid) begin
                        // angle_norm = (angle * INV_360_Q16) >> 8
                        angle_norm <= (angle * INV_360_Q16) >> 8;
                    end
                end
                
                COMPUTE3: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (!invalid && cycle_count < MAX_CYCLES) begin
                        // result_temp = (pi_r_sq * angle_norm)
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
                    state <= IDLE;
                    done <= 1'b0;
                    invalid <= 1'b0;
                end
            endcase
            
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE;
            end else begin
                state <= next_state;
            end
        end
    end

endmodule