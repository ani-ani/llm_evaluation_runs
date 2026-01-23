module check_reverse (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam REVERSE_LOOP = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam COMPARE = 3'b011;
    localparam DONE = 3'b100;

    // Internal Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] n_val;         // Store input n
    reg [7:0] n_curr;        // Current n during digit extraction
    reg [15:0] rev_val;      // Reversed number (16-bit for safety)
    reg [15:0] temp_mul;     // 2 * reverse(n)
    reg [15:0] temp_add;     // n + 1
    reg result_reg;          // Computation result
    reg [2:0] digit_count;   // Counter for max 3 digits
    reg [7:0] quotient;      // Temporary for division

    // State Transition Logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic (Combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = REVERSE_LOOP;
                else
                    next_state = IDLE;
            end
            REVERSE_LOOP: begin
                // Loop until quotient (n_curr) becomes 0
                if (n_curr == 8'd0)
                    next_state = CALCULATE;
                else
                    next_state = REVERSE_LOOP;
            end
            CALCULATE: begin
                next_state = COMPARE;
            end
            COMPARE: begin
                next_state = DONE;
            end
            DONE: begin
                // Wait in DONE state until start is low to prepare for next pulse
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 1'b0;
            // Reset internal registers to safe values
            n_val <= 8'd0;
            n_curr <= 8'd0;
            rev_val <= 16'd0;
            temp_mul <= 16'd0;
            temp_add <= 16'd0;
            result_reg <= 1'b0;
            digit_count <= 3'd0;
            quotient <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Latch input n on start
                        n_val <= n;
                        // Initialize reverse calculation
                        n_curr <= n;
                        rev_val <= 16'd0;
                        digit_count <= 3'd0;
                    end
                end

                REVERSE_LOOP: begin
                    if (n_curr != 8'd0) begin
                        // One digit extraction step per cycle
                        // No actual division/modulo logic, using subtraction loop for synthesizability
                        // However, standard div/mod is synthesizable in modern tools. 
                        // Using explicit subtraction loop for single cycle processing of digit.
                        
                        // Modulo 10 (n_curr % 10)
                        // Standard modulo is preferred for brevity and synthesis
                        rev_val <= rev_val * 10 + n_curr[3:0]; // n_curr % 10 is lower 4 bits if < 10, but strictly n_curr % 10
                        // Actually, n_curr % 10 works best with % operator.
                        // Let's use the standard operators as they are synthesizable.
                        
                        // Update: Using standard operators for clarity and cycle efficiency
                        rev_val <= rev_val * 10 + (n_curr % 10);
                        
                        // Integer division (n_curr / 10)
                        quotient <= n_curr / 10;
                        
                        // Update n_curr for next cycle
                        n_curr <= n_curr / 10;
                    end
                end

                CALCULATE: begin
                    // 2 * reverse(n)
                    temp_mul <= rev_val << 1; // Shift left for *2
                    // n + 1
                    temp_add <= {8'b0, n_val} + 16'd1;
                end

                COMPARE: begin
                    if (temp_mul == temp_add)
                        result_reg <= 1'b1;
                    else
                        result_reg <= 1'b0;
                end

                DONE: begin
                    result <= result_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule