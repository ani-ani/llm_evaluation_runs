module swerc_fee_calculator (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] swerc_cost,
    input [3:0] swerc_hops,
    input signed [15:0] comp_cost,
    input [3:0] comp_hops,
    output reg [15:0] result,
    output reg [1:0] status,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CHECK = 2'b01;
    localparam DIVIDE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state;
    reg [1:0] next_state;

    // Internal registers for calculation
    reg signed [15:0] numerator;
    reg [3:0] denominator; // unsigned difference
    reg [15:0] quotient;
    reg [15:0] remainder;
    reg [3:0] div_counter; // max hops is 7, so small counter
    reg div_in_progress;

    // State register and asynchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            status <= 2'b00;
            result <= 16'b0;
            div_in_progress <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    status <= 2'b00; // Computing/Idle
                    if (start) begin
                        // Latch inputs logic happens in next state or combinational
                    end
                end

                CHECK: begin
                    // Check conditions based on inputs
                    if (comp_hops <= swerc_hops) begin
                        status <= 2'b11; // Impossible
                        done <= 1'b1;
                        // Next state will be DONE, handled by combinational logic
                    end else begin
                        // Calculate Numerator: comp_cost - swerc_cost
                        // Note: inputs are signed 16-bit, subtraction is signed
                        numerator <= comp_cost - swerc_cost;
                        denominator <= comp_hops - swerc_hops; // Unsigned subtraction since comp_hops > swerc_hops
                        
                        // Check if numerator < 0 immediately if we want to branch in CHECK state
                        // To avoid combinational logic in state machine, we can check here for next state
                        if ((comp_cost - swerc_cost) < 0) begin
                            status <= 2'b10; // Infinity
                            done <= 1'b1;
                        end else begin
                            // Prepare for division
                            // We need (numerator - 1) / denominator
                            // Initialize divider
                            quotient <= 0;
                            remainder <= (comp_cost - swerc_cost) - 16'sd1; // numerator - 1
                            div_counter <= 0;
                            div_in_progress <= 1'b1;
                        end
                    end
                end

                DIVIDE: begin
                    if (div_in_progress) begin
                        // Subtractive division: simple loop or pipelined
                        // Since denominator is small (max 7), we can unroll or use a counter.
                        // Let's use a counter. Each cycle subtract denominator.
                        
                        // Check if remainder >= denominator
                        if (remainder >= {12'b0, denominator}) begin
                            remainder <= remainder - {12'b0, denominator};
                            quotient <= quotient + 1;
                        end
                        
                        div_counter <= div_counter + 1;
                        
                        // Terminate condition: denominator is at most 7, so max 7 shifts/subtractions.
                        // Or check if remainder < denominator.
                        // To be safe for small latency, we can run exactly 'denominator' cycles or until done.
                        // Since denominator <= 7, let's run 16 cycles to be safe or check condition.
                        // A simple way: run until remainder < denominator.
                        // But combinational check might be long. 
                        // Let's run fixed 16 cycles for simplicity (worst case 16 bit remainder).
                        // Actually, since input max is 1000, remainder max is ~1000. 10 cycles is enough.
                        // Let's use a 'done' flag for the divider.
                        
                        // Optimized termination logic:
                        // If remainder is 0, we are done.
                        if (remainder < {12'b0, denominator}) begin
                            div_in_progress <= 1'b0;
                            result <= quotient;
                            status <= 2'b01; // Valid
                            done <= 1'b1;
                        end
                    end
                end

                DONE: begin
                    // Wait for start to go low
                    if (!start) begin
                        done <= 1'b0;
                        status <= 2'b00;
                    end
                end
            endcase
        end
    end

    // Next state combinational logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = CHECK;
                else next_state = IDLE;
            end
            CHECK: begin
                // We made decisions in sequential logic above based on inputs
                if (comp_hops <= swerc_hops) begin
                    next_state = DONE;
                end else if ((comp_cost - swerc_cost) < 0) begin
                    next_state = DONE;
                end else begin
                    next_state = DIVIDE;
                end
            end
            DIVIDE: begin
                // Check if division is done (from sequential logic)
                // Note: We need to access the 'div_in_progress' signal which is a reg.
                // Since this is combinational, we assume the updated value.
                // However, in Verilog, combinational always blocks reading outputs of flip-flops
                // might have simulation mismatches if not careful, but for synthesis it maps the logic.
                // To be strictly correct, we should evaluate the condition.
                // Based on the code in DIVIDE state, we set div_in_progress to 0 when done.
                if (div_in_progress) begin
                    next_state = DIVIDE;
                end else begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (start) next_state = DONE; // Stay in done until start low
                else next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
