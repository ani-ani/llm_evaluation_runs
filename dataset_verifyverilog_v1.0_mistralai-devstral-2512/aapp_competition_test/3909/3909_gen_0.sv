module GeraldsSecret(
    input clk,
    input rst_n,
    input start,
    input [63:0] n,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC_LOOP = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [63:0] k;
    reg [63:0] remainder;
    reg [63:0] quotient;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd100;

    // Division logic (combinational)
    wire [63:0] div_result;
    wire [63:0] mod_result;
    assign div_result = (k != 64'd0) ? n / k : 64'd0;
    assign mod_result = (k != 64'd0) ? n % k : 64'd0;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_LOOP;
                end else begin
                    next_state = IDLE;
                end
            end
            CALC_LOOP: begin
                if (mod_result != 64'd0 || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CALC_LOOP;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            k <= 64'd1;
            cycle_count <= 6'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    k <= 64'd1;
                    cycle_count <= 6'd0;
                end
                CALC_LOOP: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (mod_result != 64'd0) begin
                        // Calculate ceil(n / k) = (n + k - 1) / k
                        quotient <= (n + k - 64'd1) / k;
                    end else begin
                        // Update k = k * 3
                        if (k[63:62] == 2'b00) begin  // Check for overflow
                            k <= k * 64'd3;
                        end else begin
                            k <= 64'd0;  // Overflow, force exit
                        end
                    end
                end
                DONE_STATE: begin
                    result <= quotient;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule