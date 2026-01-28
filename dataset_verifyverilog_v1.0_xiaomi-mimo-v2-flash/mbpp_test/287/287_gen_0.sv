module SumOfEvenSquares (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Internal registers for computation
    reg [5:0] n_reg;
    reg [19:0] intermediate; // 20-bit for max value ~1,026,048
    reg [7:0] cycle_count;   // Cycle counter
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // FSM Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE;
                else next_state = IDLE;
            end
            COMPUTE: begin
                // Calculation completes in 1 cycle (combinational)
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // FSM State Update and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 6'd0;
            intermediate <= 20'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate: 2 * n * (n+1) * (2*n + 1) / 3
                    // Max n=63: 2*63*64*127/3 = 342,016 (fits in 19 bits)
                    // Intermediate product: 2*n*(n+1)*(2*n+1) = 1,026,048 (fits in 20 bits)
                    
                    // Break down to avoid overflow
                    // Note: Division by 3 is exact for this formula
                    
                    // Use 64-bit intermediate to be safe, then divide
                    // Or break into steps: (2*n) * (n+1) * (2*n+1) / 3
                    
                    // Optimized: 2*n*(n+1) = 2n^2 + 2n
                    // Result = (2n^2 + 2n) * (2n+1) / 3
                    //        = (2n^2 + 2n) * 2n + (2n^2 + 2n)) / 3
                    //        = (4n^3 + 2n^2 + 4n^2 + 2n) / 3
                    //        = (4n^3 + 6n^2 + 2n) / 3
                    
                    // For n=63: 4*63^3 = 635,016; 6*63^2 = 23,814; 2*63 = 126
                    // Sum: 658,956 / 3 = 219,652 (Wait, let me recalculate)
                    // Actually: 2*n*(n+1)*(2*n+1)/3
                    // n=63: 2*63=126, 63+1=64, 2*63+1=127
                    // 126*64=8064; 8064*127=1,024,128; /3 = 341,376
                    // Correct! 341,376 (fits in 19 bits)
                    
                    // To avoid overflow during multiplication:
                    // We can use 32-bit intermediate
                    begin
                        reg [31:0] temp;
                        temp = 32'd2 * n_reg;
                        temp = temp * (n_reg + 32'd1);
                        temp = temp * (32'd2 * n_reg + 32'd1);
                        intermediate <= temp / 3;
                    end
                    
                    // If calculation takes more than 1 cycle, add state transitions
                    // Since we're doing it in 1 cycle here, we go to FINISH next
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= intermediate[15:0]; // Truncate to 16 bits
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
endmodule