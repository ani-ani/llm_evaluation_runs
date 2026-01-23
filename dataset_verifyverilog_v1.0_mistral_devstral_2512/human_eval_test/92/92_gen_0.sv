module any_int(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] x,
    input signed [15:0] y,
    input signed [15:0] z,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] RESULT  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg is_int;
    reg sum1, sum2, sum3;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if all inputs are integers (fractional bits are 0)
                    is_int = (x[7:0] == 8'd0) && (y[7:0] == 8'd0) && (z[7:0] == 8'd0);
                    
                    // Check sum conditions
                    sum1 = (x + y) == z;
                    sum2 = (x + z) == y;
                    sum3 = (y + z) == x;
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= RESULT;
                    end else begin
                        state <= RESULT;
                    end
                end

                RESULT: begin
                    result <= is_int && (sum1 || sum2 || sum3);
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule