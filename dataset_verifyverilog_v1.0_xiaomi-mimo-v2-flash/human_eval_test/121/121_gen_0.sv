module odd_even_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] index;
    reg [15:0] sum;
    reg done_pulse;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS: begin
                if ((index >= len) || (cycle_count >= MAX_CYCLES)) begin
                    next_state = FINISH;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            sum <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            done_pulse <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    done_pulse <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        index <= 4'd0;
                        sum <= 16'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process element if index is within valid range
                    if (index < len) begin
                        // Check if position is even (i[0] == 0) AND element is odd (arr[i][0] == 1)
                        if ((index[0] == 1'b0) && (arr[index][0] == 1'b1)) begin
                            sum <= sum + {8'd0, arr[index]};
                        end
                        index <= index + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    done_pulse <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    index <= 4'd0;
                    sum <= 16'd0;
                    result <= 16'd0;
                    done <= 1'b0;
                    done_pulse <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule