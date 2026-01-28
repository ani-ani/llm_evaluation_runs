module gerald_coins (
    input clk,
    input rst_n,
    input start,
    input [63:0] n,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] DIVIDE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [63:0] current_n;
    reg [63:0] quotient_reg;
    reg [1:0] remainder_reg;
    reg divider_start;
    reg [5:0] counter;
    reg divider_done;
    reg [1:0] divider_remainder;
    reg [63:0] divider_quotient;

    // Divider control signals
    reg divider_running;
    reg [5:0] divider_counter;
    reg [63:0] divider_dividend;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? DIVIDE : IDLE;
            DIVIDE: next_state = divider_done ? COMPUTE : DIVIDE;
            COMPUTE: begin
                if (divider_remainder == 2'd0) begin
                    next_state = DIVIDE; // Continue dividing
                end else begin
                    next_state = FINISH;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Divider logic (division by 3)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divider_running <= 1'b0;
            divider_counter <= 6'd0;
            quotient_reg <= 64'd0;
            remainder_reg <= 2'd0;
            divider_done <= 1'b0;
            divider_remainder <= 2'd0;
            divider_quotient <= 64'd0;
        end else begin
            divider_done <= 1'b0;
            
            // Start divider
            if (divider_start && !divider_running) begin
                divider_running <= 1'b1;
                divider_counter <= 6'd0;
                quotient_reg <= 64'd0;
                remainder_reg <= 2'd0;
                divider_dividend <= current_n;
            end
            
            // Run divider
            if (divider_running) begin
                if (divider_counter < 6'd64) begin
                    // Shift remainder left by 1 and bring in next bit
                    remainder_reg <= {remainder_reg, divider_dividend[63-divider_counter]};
                    
                    // Check if remainder >= 3 (using temporary value)
                    // remainder_temp = (remainder_reg << 1) | current_bit
                    if ({remainder_reg[0], divider_dividend[63-divider_counter]} >= 2'd3) begin
                        remainder_reg <= ({remainder_reg[0], divider_dividend[63-divider_counter]}) - 2'd3;
                        quotient_reg <= {quotient_reg[62:0], 1'b1};
                    end else begin
                        quotient_reg <= {quotient_reg[62:0], 1'b0};
                    end
                    
                    divider_counter <= divider_counter + 6'd1;
                end else begin
                    divider_running <= 1'b0;
                    divider_done <= 1'b1;
                    divider_quotient <= quotient_reg;
                    divider_remainder <= remainder_reg;
                end
            end
        end
    end

    // Main datapath and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_n <= 64'd0;
            divider_start <= 1'b0;
            result <= 64'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            divider_start <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        current_n <= n;
                    end
                end
                DIVIDE: begin
                    divider_start <= 1'b1;
                end
                COMPUTE: begin
                    if (divider_remainder == 2'd0) begin
                        current_n <= divider_quotient; // Continue with n/3
                    end else begin
                        result <= divider_quotient + 64'd1; // n/3 + 1
                        done <= 1'b1;
                    end
                end
                FINISH: begin
                    // Wait for next start
                end
                default: begin
                    current_n <= 64'd0;
                    result <= 64'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule