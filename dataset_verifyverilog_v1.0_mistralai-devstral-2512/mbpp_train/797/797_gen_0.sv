module odd_sum_module(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] l,
    input wire [7:0] r,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTING = 2'd1;
    localparam [1:0] DONE      = 2'd2;

    // Internal signals
    reg [1:0] state, next_state;
    reg [7:0] current;
    reg [15:0] accumulator;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTING;
                else
                    next_state = IDLE;
            end
            COMPUTING: begin
                if (current > r || cycle_count >= MAX_CYCLES)
                    next_state = DONE;
                else
                    next_state = COMPUTING;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current <= 8'd0;
            accumulator <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current <= l;
                        accumulator <= 16'd0;
                    end
                end
                COMPUTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current[0] == 1'b1) begin
                        accumulator <= accumulator + current;
                    end
                    current <= current + 8'd1;
                    if (current > r || cycle_count >= MAX_CYCLES) begin
                        result <= accumulator;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end

endmodule