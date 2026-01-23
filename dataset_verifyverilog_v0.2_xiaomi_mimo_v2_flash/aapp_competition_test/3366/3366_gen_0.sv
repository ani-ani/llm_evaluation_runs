module sum_collatz(
    input clk,
    input rst_n,
    input start,
    input [15:0] L,
    input [15:0] R,
    output reg [31:0] sum,
    output reg done
);

    // State encoding for main FSM
    localparam IDLE = 3'b000;
    localparam CALC_F = 3'b001;
    localparam ACCUM = 3'b010;
    localparam INCREMENT_X = 3'b011;
    localparam DONE = 3'b100;

    // Registers for main FSM state
    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [15:0] current_X;
    reg [15:0] target_R;
    reg [31:0] sum_reg;
    reg [31:0] f_val; // Result of f(X)
    reg [31:0] iter_count; // Counter for calculating f(X)

    // State transition logic (Asynchronous)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC_F;
                else
                    next_state = IDLE;
            end
            CALC_F: begin
                // f(X) calculation is done when X reaches 1
                if (current_X == 16'd1)
                    next_state = ACCUM;
                else
                    next_state = CALC_F;
            end
            ACCUM: begin
                next_state = INCREMENT_X;
            end
            INCREMENT_X: begin
                if (current_X > target_R)
                    next_state = DONE;
                else
                    next_state = CALC_F;
            end
            DONE: begin
                // Stay in DONE until reset or new start
                if (start) next_state = CALC_F; // Optional: restart if start is held high? No, typically wait for low then high. But specs say wait for start. Assuming synchronous restart allowed or wait until start goes low.
                // Let's stick to strict behavior: stay done until reset.
                // Actually, good design returns to IDLE if start goes low.
                if (!start) next_state = IDLE;
                else next_state = DONE; // Keep done high if start still high
            end
            default: next_state = IDLE;
        endcase
    end

    // State update and Output Logic (Synchronous)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum <= 32'd0;
            done <= 1'b0;
            // Reset internal regs
            sum_reg <= 32'd0;
            current_X <= 16'd0;
            target_R <= 16'd0;
            f_val <= 32'd0;
            iter_count <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_X <= L;
                        target_R <= R;
                        sum_reg <= 32'd0;
                    end
                end

                CALC_F: begin
                    // This state runs a sub-iteration to calculate f(X)
                    // We use 'iter_count' to track the operation count
                    // We use 'f_val' (using it as temporary X register for calculation logic to save bits, 
                    // but actually we need to keep current_X for the loop range check later. 
                    // Let's use a specific temp register or reuse iter_count logic? 
                    // Spec says: "Use a temporary register for current X value".
                    // Let's use iter_count[15:0] as the temporary X value? No, need 32-bit potentially if X grows.
                    // Wait, odd -> X+1. 65535 (max 16-bit) -> 65536 (fits 16-bit). 32-bit is safe.
                    // Let's use f_val as the temporary variable for X calculation.
                    // Init logic needs to be handled. When entering CALC_F, we need to load current_X into f_val.
                    // However, the FSM enters CALC_F and loops. We need a way to load the seed.
                    // Let's modify the transition into CALC_F to load the seed. 
                    // Better: Use a separate 'calc_busy' logic or detect entry.
                    // Since 'state' transition is combinational, we can detect 'entering_calc'.
                    
                    if (state != CALC_F) begin
                        // Just entered CALC_F from previous state (ACCUM/INCREMENT or IDLE)
                        // Wait, IDLE goes to CALC_F. ACCUM goes to INCREMENT which goes to CALC_F.
                        // INCREMENT updates current_X. So when we enter CALC_F from INCREMENT, current_X is correct.
                        // We need to initialize the temporary calc register.
                        f_val <= {16'd0, current_X}; // Initialize temp X
                        iter_count <= 32'd0; // Reset counter for this specific X
                    end else begin
                        // We are already in CALC_F state, perform one step of Collatz
                        if (f_val != 32'd1) begin
                            if (f_val[0] == 1'b0) begin
                                // Even: X = X / 2
                                f_val <= f_val >> 1;
                            end else begin
                                // Odd: X = X + 1
                                f_val <= f_val + 32'd1;
                            end
                            iter_count <= iter_count + 32'd1;
                        end
                    end
                end

                ACCUM: begin
                    // Add the calculated iterations (iter_count) to sum_reg
                    // Note: iter_count holds the number of steps taken to reach 1
                    sum_reg <= sum_reg + iter_count;
                end

                INCREMENT_X: begin
                    // Increment the main X counter for the range loop
                    current_X <= current_X + 16'd1;
                end

                DONE: begin
                    sum <= sum_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
