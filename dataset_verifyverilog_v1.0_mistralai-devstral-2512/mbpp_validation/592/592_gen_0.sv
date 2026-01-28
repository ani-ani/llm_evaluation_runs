module binomial_coeff_sum(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Internal array for binomial coefficients
    reg [15:0] C [0:7];
    
    // Loop counters
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    
    // Cycle counter to prevent infinite loops
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd512;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            
            INIT: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES)
                    next_state = FINISH;
                else if (i == 2*n && j == 1)
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State register and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 9'd0;
            
            // Initialize array
            integer idx;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                C[idx] <= 16'd0;
            end
            
            i <= 4'd0;
            j <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 9'd0;
                end
                
                INIT: begin
                    // Initialize C[0] = 1
                    C[0] <= 16'd1;
                    
                    // Initialize loop counters
                    i <= 4'd1;
                    j <= 4'd0;
                    k <= n - 4'd1;
                    
                    // Clear other array elements
                    integer idx;
                    for (idx = 1; idx < 8; idx = idx + 1) begin
                        C[idx] <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    // Update C[j] = C[j] + C[j-1]
                    if (j > 4'd0) begin
                        C[j] <= C[j] + C[j-1];
                    end
                    
                    // Update loop counters
                    if (j == 4'd0) begin
                        if (i < 2*n) begin
                            i <= i + 4'd1;
                            j <= (i < k) ? i : k;
                        end else begin
                            j <= 4'd1;
                        end
                    end else begin
                        j <= j - 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= C[k];
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule