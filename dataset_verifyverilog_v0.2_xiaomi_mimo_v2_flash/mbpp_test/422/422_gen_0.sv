module average_of_cubes (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam CALC_SUM = 2'b01;
    localparam DIVIDE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;
    
    // Internal registers
    reg [7:0] i;
    reg [31:0] sum;
    reg [31:0] numerator;
    reg [7:0] n_reg;
    
    // Combinational logic for state transition
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC_SUM;
                else
                    next_state = IDLE;
            end
            
            CALC_SUM: begin
                if (i > n_reg)
                    next_state = DIVIDE;
                else
                    next_state = CALC_SUM;
            end
            
            DIVIDE: begin
                // Division is single cycle since max latency requirement is 10 cycles
                next_state = DONE;
            end
            
            DONE: begin
                // Stay in DONE until next start
                if (start)
                    next_state = CALC_SUM;
                else
                    next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'h0;
            done <= 1'b0;
            i <= 8'h0;
            sum <= 32'h0;
            n_reg <= 8'h0;
            numerator <= 32'h0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 8'h1;
                        sum <= 32'h0;
                        n_reg <= n;
                    end
                end
                
                CALC_SUM: begin
                    if (i <= n_reg) begin
                        // Compute i*i*i and add to sum
                        sum <= sum + (i * i * i);
                        i <= i + 8'h1;
                    end
                end
                
                DIVIDE: begin
                    // Convert to Q16.16: (sum * 65536) / n
                    // sum * 65536 = sum << 16
                    numerator <= sum << 16;
                    if (n_reg != 8'h0) begin
                        result <= (sum << 16) / n_reg;
                    end else begin
                        result <= 32'h0;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    // Result is already computed and held
                end
            endcase
        end
    end

endmodule