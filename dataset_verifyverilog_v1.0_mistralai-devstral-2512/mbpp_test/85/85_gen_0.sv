module sphere_surface_area(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] radius,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] STAGE1  = 2'd1;
    localparam [1:0] STAGE2  = 2'd2;
    localparam [1:0] STAGE3  = 2'd3;
    localparam [1:0] FINISH  = 2'd4;

    // Pipeline registers
    reg [1:0] state, next_state;
    reg [15:0] r_squared;      // Stage1 output (16-bit)
    reg [31:0] pi_mult;        // Stage2 output (32-bit)
    reg [31:0] final_mult;     // Stage3 output (32-bit)
    reg [7:0] cycle_count;     // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Fixed-point constants
    localparam [31:0] PI_Q16_16 = 32'h3243F;  // 3.14159 in Q16.16

    // Stage1: r² calculation (combinational)
    wire [15:0] r_squared_comb;
    assign r_squared_comb = radius * radius;

    // Stage2: multiply by π (combinational)
    wire [31:0] pi_mult_comb;
    assign pi_mult_comb = $signed(r_squared) * $signed(PI_Q16_16);

    // Stage3: multiply by 4 (combinational)
    wire [31:0] final_mult_comb;
    assign final_mult_comb = pi_mult << 2;  // Multiply by 4 via shift

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            r_squared <= 16'd0;
            pi_mult <= 32'd0;
            final_mult <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= STAGE1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                STAGE1: begin
                    cycle_count <= cycle_count + 8'd1;
                    r_squared <= r_squared_comb;
                    next_state <= STAGE2;
                end

                STAGE2: begin
                    cycle_count <= cycle_count + 8'd1;
                    pi_mult <= pi_mult_comb;
                    next_state <= STAGE3;
                end

                STAGE3: begin
                    cycle_count <= cycle_count + 8'd1;
                    final_mult <= final_mult_comb;
                    next_state <= FINISH;
                end

                FINISH: begin
                    result <= final_mult;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule