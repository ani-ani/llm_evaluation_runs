module perfect_squares_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [15:0][7:0] result,
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] i;  // Iteration counter (1-16)
    reg [3:0] sq_count;  // Found squares counter
    reg [7:0] square;  // Current square value
    reg valid;  // Flag for valid square
    
    // Registers for outputs
    reg [15:0][7:0] result_reg;
    reg [3:0] count_reg;
    reg done_reg;
    
    // Square calculation (i*i, max 16*16=256 fits 8-bit)
    wire [7:0] computed_square;
    assign computed_square = i * i;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            
            COMPUTE: begin
                if (i == 4'd15)  // Processed all 16 values (1-16)
                    next_state = DONE;
                else
                    next_state = COMPUTE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            sq_count <= 4'd0;
            result_reg <= '{default: 8'd0};
            count_reg <= 4'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    i <= 4'd0;
                    sq_count <= 4'd0;
                    if (start) begin
                        result_reg <= '{default: 8'd0};
                        count_reg <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    i <= i + 4'd1;
                    
                    // Check if square is within [a, b]
                    // Using computed_square (i*i) which is 0-256
                    if (computed_square >= a && computed_square <= b && sq_count < 4'd15) begin
                        // Store the square in the next available position
                        result_reg[sq_count] <= computed_square;
                        sq_count <= sq_count + 4'd1;
                    end
                end
                
                DONE: begin
                    count_reg <= sq_count;
                    done_reg <= 1'b1;
                    i <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Output assignments
    always @(*) begin
        result = result_reg;
        count = count_reg;
        done = done_reg;
    end

endmodule