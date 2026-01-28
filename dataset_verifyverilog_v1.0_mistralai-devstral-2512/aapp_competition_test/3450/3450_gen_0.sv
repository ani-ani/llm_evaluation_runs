module factorial_digits(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [11:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_FACT = 3'd1;
    localparam [2:0] REMOVE_ZEROS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [63:0] fact;
    reg [3:0] i;
    reg [3:0] zero_count;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd30;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fact <= 64'd1;
            i <= 4'd0;
            zero_count <= 4'd0;
            cycle_count <= 4'd0;
            result <= 12'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && n != 4'd0) begin
                    next_state = COMPUTE_FACT;
                end
            end
            COMPUTE_FACT: begin
                if (i == n) begin
                    next_state = REMOVE_ZEROS;
                end
            end
            REMOVE_ZEROS: begin
                if (fact[3:0] != 4'd0 || zero_count == 4'd10) begin
                    next_state = OUTPUT;
                end
            end
            OUTPUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fact <= 64'd1;
            i <= 4'd0;
            zero_count <= 4'd0;
            cycle_count <= 4'd0;
            result <= 12'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                end
                COMPUTE_FACT: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (i < n) begin
                        fact <= fact * (i + 4'd1);
                        i <= i + 4'd1;
                    end
                end
                REMOVE_ZEROS: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (fact[3:0] == 4'd0 && zero_count < 4'd10) begin
                        fact <= fact / 4'd10;
                        zero_count <= zero_count + 4'd1;
                    end
                end
                OUTPUT: begin
                    result <= fact[11:0];
                    done <= 1'b1;
                end
                default: begin
                    fact <= 64'd1;
                    i <= 4'd0;
                    zero_count <= 4'd0;
                    cycle_count <= 4'd0;
                    result <= 12'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule