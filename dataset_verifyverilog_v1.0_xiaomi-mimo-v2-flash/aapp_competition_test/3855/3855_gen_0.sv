module BitLengthComputation(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [29:0] n,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTE   = 2'd1;
    localparam [1:0] FINISH    = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [29:0] n_reg;           // Store input n
    reg [29:0] shifted_n;       // Current value being processed
    reg [4:0] bit_count;        // Count of bits
    reg [7:0] cycle_count;      // Safety counter to prevent infinite loops

    // State transition logic
    always @(*) begin
        next_state = IDLE;  // Default to avoid latches
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                if (shifted_n == 30'd0 || cycle_count >= 8'd200)
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

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            n_reg <= 30'd0;
            shifted_n <= 30'd0;
            bit_count <= 5'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n;
                        shifted_n <= n;
                        bit_count <= 5'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Shift right by 1 bit (divide by 2)
                    shifted_n <= {1'b0, shifted_n[29:1]};
                    
                    // Increment bit count
                    bit_count <= bit_count + 5'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Special case: if n was 0, result should be 0
                    if (n_reg == 30'd0)
                        result <= 5'd0;
                    else
                        result <= bit_count;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule