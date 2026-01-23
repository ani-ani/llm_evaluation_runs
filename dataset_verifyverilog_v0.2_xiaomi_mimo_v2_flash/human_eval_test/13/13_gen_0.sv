module gcd_calculator (
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] result,
    output reg done,
    output reg error
);

    // State Encoding
    localparam IDLE     = 3'b000;
    localparam CHECK    = 3'b001;
    localparam SWAP     = 3'b010;
    localparam SHIFT    = 3'b011;
    localparam SUBTRACT = 3'b100;
    localparam DONE     = 3'b101;

    reg [2:0] current_state;
    reg [2:0] next_state;

    // Internal Registers
    reg [15:0] reg_a;
    reg [15:0] reg_b;
    reg [4:0]  cycle_count; // 5 bits to count up to 32

    // Combinational Logic Signals
    wire a_zero;
    wire b_zero;
    wire a_lt_b;
    wire b_even;
    wire a_even;

    // Assignments for combinational conditions
    assign a_zero = (reg_a == 16'd0);
    assign b_zero = (reg_b == 16'd0);
    assign a_lt_b = (reg_a < reg_b);
    assign b_even = ~reg_b[0];
    assign a_even = ~reg_a[0];

    // State Register (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic & Output Logic (Mealy/State Machine)
    always @(*) begin
        // Default next state to prevent latches
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    // Check for edge case: Both inputs zero
                    if (a == 16'd0 && b == 16'd0) begin
                        next_state = DONE;
                    end else begin
                        next_state = CHECK;
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            CHECK: begin
                if (b_zero) begin
                    next_state = DONE;
                end else if (a_lt_b) begin
                    next_state = SWAP;
                end else if (b_even || a_even) begin
                    next_state = SHIFT;
                end else begin
                    next_state = SUBTRACT;
                end
            end

            SWAP: begin
                next_state = CHECK;
            end

            SHIFT: begin
                next_state = CHECK;
            end

            SUBTRACT: begin
                next_state = CHECK;
            end

            DONE: begin
                if (!start) begin // Wait for start to go low to return to IDLE
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_a <= 16'd0;
            reg_b <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 5'd0;
        end else begin
            // Default assignments (maintain state unless changed)
            done <= 1'b0;
            error <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        reg_a <= a;
                        reg_b <= b;
                        cycle_count <= 5'd0;
                    end
                end

                CHECK: begin
                    // Just a pass-through state for logic evaluation
                    // Check cycle limit to prevent infinite loops (Safety Feature)
                    if (cycle_count >= 5'd31 && !b_zero) begin
                         // Force to DONE if taking too long, though problem implies valid inputs
                         // Not explicitly required but good practice. Sticking strictly to spec:
                         // Just increment counter for tracking
                    end
                end

                SWAP: begin
                    reg_a <= reg_b;
                    reg_b <= reg_a;
                    cycle_count <= cycle_count + 1;
                end

                SHIFT: begin
                    if (b_even) begin
                        reg_b <= reg_b >> 1;
                    end else if (a_even) begin
                        reg_a <= reg_a >> 1;
                    end
                    cycle_count <= cycle_count + 1;
                end

                SUBTRACT: begin
                    reg_a <= reg_a - reg_b;
                    cycle_count <= cycle_count + 1;
                end

                DONE: begin
                    done <= 1'b1;
                    result <= reg_a;
                    if (a == 16'd0 && b == 16'd0) begin
                        error <= 1'b1;
                        result <= 16'd0;
                    end
                end
            endcase
        end
    end

endmodule