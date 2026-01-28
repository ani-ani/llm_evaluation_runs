module FindMinimumOperations (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] x_in,
    input wire signed [15:0] y_in,
    input wire signed [15:0] m_in,
    output reg signed [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] CHECK       = 4'd1;
    localparam [3:0] CHECK_FINAL = 4'd2;
    localparam [3:0] NEGATIVE    = 4'd3;
    localparam [3:0] NEG_CALC    = 4'd4;
    localparam [3:0] LOOP        = 4'd5;
    localparam [3:0] LOOP_UPDATE = 4'd6;
    localparam [3:0] FINISH      = 4'd7;
    localparam [3:0] ERROR       = 4'd8;
    localparam [3:0] DONE        = 4'd9;

    // Internal registers
    reg [3:0] state, next_state;
    reg signed [15:0] x_reg, y_reg, m_reg;
    reg signed [31:0] count_reg;
    reg signed [31:0] steps_reg;
    reg signed [31:0] x_step_reg;
    reg [10:0] cycle_counter; // 0 to 1024
    localparam [10:0] MAX_CYCLES = 11'd1024;
    reg signed [31:0] temp_sum;
    reg signed [31:0] temp_steps;
    reg signed [31:0] temp_dividend;

    // Combinational logic for max check
    wire signed [15:0] max_val;
    assign max_val = (x_reg > y_reg) ? x_reg : y_reg;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CHECK : IDLE;
            
            CHECK: begin
                if (max_val >= m_reg) 
                    next_state = FINISH;
                else if (y_reg <= 16'sd0)
                    next_state = ERROR;
                else if (x_reg < 16'sd0)
                    next_state = NEGATIVE;
                else
                    next_state = LOOP;
            end
            
            CHECK_FINAL: next_state = (y_reg < m_reg) ? LOOP : FINISH;
            
            NEGATIVE: next_state = NEG_CALC;
            
            NEG_CALC: next_state = CHECK_FINAL;
            
            LOOP: next_state = LOOP_UPDATE;
            
            LOOP_UPDATE: begin
                if (y_reg >= m_reg)
                    next_state = FINISH;
                else
                    next_state = CHECK_FINAL;
            end
            
            FINISH: next_state = DONE;
            ERROR: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'sd0;
            done <= 1'b0;
            x_reg <= 16'sd0;
            y_reg <= 16'sd0;
            m_reg <= 16'sd0;
            count_reg <= 32'sd0;
            steps_reg <= 32'sd0;
            x_step_reg <= 32'sd0;
            cycle_counter <= 11'd0;
            temp_sum <= 32'sd0;
            temp_steps <= 32'sd0;
            temp_dividend <= 32'sd0;
        end else begin
            // Default done is 0
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        x_reg <= x_in;
                        y_reg <= y_in;
                        m_in_reg: m_in; // Bug fix: handle m_in
                        count_reg <= 32'sd0;
                        cycle_counter <= 11'd0;
                    end
                end
                
                CHECK: begin
                    // Check handled in combinational next_state
                end
                
                CHECK_FINAL: begin
                    // Check handled in combinational next_state
                end
                
                NEGATIVE: begin
                    // Calculate steps to make x non-negative
                    // steps = ceil(|x| / y) = (|x| + y - 1) / y
                    temp_dividend <= {16'd0, (x_reg[15] ? -x_reg : x_reg)}; // |x|
                    // Integer division handled in NEG_CALC
                    temp_steps <= 32'sd0;
                end
                
                NEG_CALC: begin
                    // Perform division: (|x| + y - 1) / y
                    // y_reg is positive here
                    if (y_reg > 16'sd0) begin
                        // step = (dividend + y - 1) / y
                        temp_steps <= (temp_dividend + y_reg - 1) / y_reg;
                    end
                    
                    // Update x: x = x + steps * y
                    x_reg <= x_reg + temp_steps * y_reg;
                    
                    // Update count
                    count_reg <= count_reg + temp_steps;
                end
                
                LOOP: begin
                    // Fibonacci step: x, y = y, x + y
                    // Store x+y in temp_sum (32-bit to prevent overflow)
                    temp_sum <= {16'd0, x_reg} + {16'd0, y_reg};
                end
                
                LOOP_UPDATE: begin
                    // Update registers
                    x_reg <= y_reg;
                    y_reg <= temp_sum[15:0]; // Truncate to 16-bit
                    
                    // Increment count
                    count_reg <= count_reg + 32'sd1;
                    
                    // Safety counter
                    cycle_counter <= cycle_counter + 11'd1;
                    
                    // If cycle limit exceeded, go to error
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= ERROR;
                    end
                end
                
                FINISH: begin
                    result <= count_reg;
                    done <= 1'b1;
                end
                
                ERROR: begin
                    result <= -32'sd1;
                    done <= 1'b1;
                end
                
                DONE: begin
                    done <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'sd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Handle m_in assignment in IDLE (additional logic)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_reg <= 16'sd0;
        end else if (state == IDLE && start) begin
            m_reg <= m_in;
        end
    end

endmodule