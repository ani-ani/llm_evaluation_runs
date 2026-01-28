module largest_divisor (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] CALCULATING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [15:0] divisor;
    reg [15:0] n_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Combinational remainder calculation
    wire [15:0] remainder;
    wire [31:0] div_temp;
    assign div_temp = n_reg * divisor;
    assign remainder = div_temp[15:0];

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECKING;
                end else begin
                    next_state = IDLE;
                end
            end
            CHECKING: begin
                // Check if divisor divides n evenly
                if (remainder == 16'd0) begin
                    next_state = CALCULATING;
                end else if (divisor == 16'd1 || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CHECKING;
                end
            end
            CALCULATING: begin
                // Wait one cycle for result to be registered
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            divisor <= 16'd0;
            n_reg <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n;
                        if (n == 16'd1) begin
                            result <= 16'd1;
                        end else begin
                            divisor <= n[15:1];  // n/2 (floor division for unsigned)
                        end
                    end
                end
                CHECKING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (remainder == 16'd0 && divisor != 16'd0) begin
                        // Found divisor, move to calculating
                        result <= divisor;
                    end else if (divisor > 16'd1) begin
                        divisor <= divisor - 16'd1;
                    end
                end
                CALCULATING: begin
                    // Result already set in CHECKING state
                    // Just transition to DONE
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
            
            // Handle n=1 edge case in IDLE
            if (state == IDLE && start && n == 16'd1) begin
                result <= 16'd1;
            end
        end
    end

endmodule