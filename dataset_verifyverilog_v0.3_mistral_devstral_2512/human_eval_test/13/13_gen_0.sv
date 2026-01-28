module gcd_calculator(
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] a_reg, b_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                if (b_reg == 16'd0 || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            cycle_count <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        a_reg <= a;
                        b_reg <= b;
                        cycle_count <= 4'd0;
                        done <= 1'b0;
                    end
                end

                COMPUTE: begin
                    if (b_reg != 16'd0 && cycle_count < MAX_CYCLES) begin
                        // Compute a % b using subtraction
                        if (a_reg >= b_reg) begin
                            a_reg <= a_reg - b_reg;
                        end else begin
                            // Swap a and b when a < b
                            a_reg <= {a_reg, b_reg};
                            b_reg <= a_reg[31:16];
                            a_reg <= a_reg[15:0];
                            cycle_count <= cycle_count + 4'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= a_reg;
                    done <= 1'b1;
                end

                default: begin
                    a_reg <= 16'd0;
                    b_reg <= 16'd0;
                    cycle_count <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule