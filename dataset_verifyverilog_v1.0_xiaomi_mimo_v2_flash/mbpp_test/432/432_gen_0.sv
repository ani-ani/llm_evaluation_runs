module trapezium_median (
    input  wire        clk,        // Clock signal
    input  wire        rst_n,      // Active-low reset
    input  wire        start,      // Start computation
    input  wire [15:0] base1,      // First base (Q16.16 fixed-point)
    input  wire [15:0] base2,      // Second base (Q16.16 fixed-point)
    input  wire [15:0] height,     // Height (Q16.16 fixed-point, unused)
    output reg  [15:0] median,     // Result (Q16.16 fixed-point)
    output reg         done        // Computation complete
);

    // State definitions
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] ADD   = 2'd1;
    localparam [1:0] DIV2  = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state, next_state;
    reg [16:0] sum;  // 17-bit to hold sum of two 16-bit values
    
    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            median <= 16'd0;
            done <= 1'b0;
            sum <= 17'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        sum <= {1'b0, base1} + {1'b0, base2};
                    end
                end
                
                ADD: begin
                    median <= sum[16:1];  // Divide by 2 (shift right)
                end
                
                DIV2: begin
                    // No action, just transition
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // Initialize registers
                    state <= IDLE;
                    median <= 16'd0;
                    done <= 1'b0;
                    sum <= 17'd0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = ADD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            ADD: begin
                next_state = DIV2;
            end
            
            DIV2: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule