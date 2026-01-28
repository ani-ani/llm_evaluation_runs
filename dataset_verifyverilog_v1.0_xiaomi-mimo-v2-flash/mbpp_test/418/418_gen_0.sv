module FindLongestSublist(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] lengths [0:3],
    output reg [1:0] max_index,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] max_len;
    reg [3:0] current_len;
    reg [1:0] i;  // iteration index (0-3)
    reg [1:0] cycle_count;

    // State register and reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_index <= 2'd0;
            done <= 1'b0;
            max_len <= 4'd0;
            i <= 2'd0;
            cycle_count <= 2'd0;
        end else begin
            state <= next_state;
            
            // Default assignments for combinational logic
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Reset iteration variables
                    i <= 2'd0;
                    max_len <= 4'd0;
                    max_index <= 2'd0;
                    cycle_count <= 2'd0;
                end
                
                COMPARE: begin
                    // Get current length value
                    case (i)
                        2'd0: current_len = lengths[0];
                        2'd1: current_len = lengths[1];
                        2'd2: current_len = lengths[2];
                        2'd3: current_len = lengths[3];
                        default: current_len = 4'd0;
                    endcase
                    
                    // Compare and update if current is greater
                    // Note: If equal, we keep the first (earlier) index
                    if (current_len > max_len) begin
                        max_len <= current_len;
                        max_index <= i;
                    end
                    
                    // Increment counter or finish
                    if (i == 2'd3) begin
                        // Done checking all 4 lists
                        done <= 1'b1;
                    end else begin
                        i <= i + 2'd1;
                    end
                end
                
                FINISH: begin
                    // Stay in FINISH state for one cycle (done already asserted)
                    // Return to IDLE next cycle
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPARE: begin
                // After processing last index (i==3), go to FINISH
                if (i == 2'd3) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            FINISH: begin
                // Return to IDLE after one cycle
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule