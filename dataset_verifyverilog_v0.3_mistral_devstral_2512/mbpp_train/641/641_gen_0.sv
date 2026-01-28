module NonagonalNumberCalculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] MULT1 = 3'd1;
    localparam [2:0] SUB   = 3'd2;
    localparam [2:0] MULT2 = 3'd3;
    localparam [2:0] DIV2  = 3'd4;
    localparam [2:0] DONE  = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Intermediate registers
    reg [15:0] mult1_result;
    reg [15:0] sub_result;
    reg [15:0] mult2_result;

    // Cycle counter for safety
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            mult1_result <= 16'd0;
            sub_result <= 16'd0;
            mult2_result <= 16'd0;
            cycle_count <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        next_state <= MULT1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                MULT1: begin
                    cycle_count <= cycle_count + 5'd1;
                    mult1_result <= 7'd7 * n_in;
                    next_state <= SUB;
                end

                SUB: begin
                    cycle_count <= cycle_count + 5'd1;
                    sub_result <= mult1_result - 16'd5;
                    next_state <= MULT2;
                end

                MULT2: begin
                    cycle_count <= cycle_count + 5'd1;
                    mult2_result <= n_in * sub_result;
                    next_state <= DIV2;
                end

                DIV2: begin
                    cycle_count <= cycle_count + 5'd1;
                    result <= mult2_result >> 1;
                    next_state <= DONE;
                end

                DONE: begin
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