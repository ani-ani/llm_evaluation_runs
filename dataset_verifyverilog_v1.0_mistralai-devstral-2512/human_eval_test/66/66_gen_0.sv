module ascii_uppercase_sum(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [3:0] char_count,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [10:0] sum;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            
            COMPUTE: begin
                if (index == char_count - 4'd1 || cycle_count >= MAX_CYCLES)
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            sum <= 11'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        index <= 4'd0;
                        sum <= 11'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if current character is uppercase
                    reg is_uppercase;
                    is_uppercase = ((char_array[index] & 8'h5F) >= 8'h41) && 
                                  ((char_array[index] & 8'h5F) <= 8'h5A);
                    
                    if (is_uppercase)
                        sum <= sum + char_array[index];
                    
                    index <= index + 4'd1;
                end
                
                FINISH: begin
                    result <= {5'd0, sum};
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule