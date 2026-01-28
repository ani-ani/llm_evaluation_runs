module DivisibilityHackChecker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] b,
    input wire [15:0] d,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH  = 3'd3;
    localparam [2:0] ERROR   = 3'd4;

    // Registers for state and data
    reg [2:0] state;
    reg [15:0] b_reg;
    reg [15:0] d_reg;
    reg [15:0] b_mod_d;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic for modulo computation
    wire [15:0] b_mod_d_wire;
    assign b_mod_d_wire = (d_reg != 16'd0) ? (b_reg % d_reg) : 16'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            b_reg <= 16'd0;
            d_reg <= 16'd0;
            b_mod_d <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    b_reg <= b;
                    d_reg <= d;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Increment cycle counter to prevent infinite loops
                    cycle_count <= cycle_count + 8'd1;

                    // Perform modulo operation
                    b_mod_d <= b_mod_d_wire;

                    // Check exit condition based on computed value
                    // The logic: if b % d == 1, result is yes (1)
                    // Otherwise, result is no (0)
                    if (b_mod_d_wire == 16'd1) begin
                        result <= 1'b1;
                        state <= FINISH;
                    end else begin
                        // This includes d=0, d=1 cases or b_mod_d != 1
                        result <= 1'b0;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule