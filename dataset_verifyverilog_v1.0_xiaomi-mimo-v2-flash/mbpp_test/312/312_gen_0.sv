module cone_volume(
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire signed [15:0] r,
  input wire signed [15:0] h,
  output reg signed [31:0] result,
  output reg done
);

    // Fixed-point constants in Q16.16 format
    localparam signed [31:0] PI_Q16 = 32'sh3243F;     // 3.14159
    localparam signed [31:0] ONE_THIRD_Q16 = 32'sh5555; // 0.3333

    // State definitions for control
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Control state register
    reg [1:0] state;
    reg [2:0] counter; // Counts pipeline cycles (0-4)

    // Pipeline registers
    reg signed [31:0] r_squared;      // Stage 1 output
    reg signed [31:0] r_squared_h;    // Stage 2 output
    reg signed [31:0] r_squared_h_pi; // Stage 3 output
    reg signed [63:0] temp_result;    // Stage 4 intermediate (full precision)

    // Combinational intermediate calculations
    wire signed [31:0] r_squared_wire;
    wire signed [31:0] r_squared_h_wire;
    wire signed [31:0] r_squared_h_pi_wire;
    wire signed [63:0] temp_result_wire;

    // Stage 1: r² (16x16 -> 32) then shift right 16 to keep Q16.16
    // r_squared_wire = (r * r) >>> 16;
    wire signed [31:0] stage1_mult;
    assign stage1_mult = r * r;
    assign r_squared_wire = stage1_mult >>> 16;

    // Stage 2: r² * h (32x16 -> 48) then shift right 16
    wire signed [47:0] stage2_mult;
    assign stage2_mult = r_squared * h;
    assign r_squared_h_wire = stage2_mult >>> 16;

    // Stage 3: (r² * h) * π (32x32 -> 64) then shift right 16
    wire signed [63:0] stage3_mult;
    assign stage3_mult = r_squared_h * PI_Q16;
    assign r_squared_h_pi_wire = stage3_mult >>> 16;

    // Stage 4: * (1/3) (32x32 -> 64), keep full precision
    // Result will be finalized in sequential logic
    wire signed [63:0] stage4_mult;
    assign stage4_mult = r_squared_h_pi * ONE_THIRD_Q16;

    // Control logic (FSM)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state and registers
            state <= IDLE;
            counter <= 3'd0;
            done <= 1'b0;
            result <= 32'd0;
            r_squared <= 32'd0;
            r_squared_h <= 32'd0;
            r_squared_h_pi <= 32'd0;
            temp_result <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 3'd0;
                    if (start) begin
                        // Register inputs on start
                        state <= CALC;
                        counter <= 3'd1;
                        // Stage 1: compute r²
                        r_squared <= r_squared_wire;
                    end
                end

                CALC: begin
                    // Shift pipeline data
                    r_squared_h <= r_squared_h_wire;
                    r_squared_h_pi <= r_squared_h_pi_wire;
                    temp_result <= stage4_mult;
                    
                    if (counter == 3'd4) begin
                        // Final stage: shift right 16 and register result
                        result <= temp_result[47:16];
                        state <= DONE_STATE;
                    end else begin
                        counter <= counter + 3'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    counter <= 3'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule