module steward_support (
    input clk,
    input rst_n,
    input start,
    input [31:0] values [0:15],
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN_MIN_MAX = 2'd1;
    localparam [1:0] COUNT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i;
    reg [31:0] min_val;
    reg [31:0] max_val;
    reg [15:0] count_reg;
    reg [3:0] n_reg;
    
    // FSM Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            min_val <= 32'd0;
            max_val <= 32'd0;
            count_reg <= 16'd0;
            n_reg <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize min/max with first element
                        min_val <= values[0];
                        max_val <= values[0];
                        i <= 4'd1; // Start from index 1 since we loaded index 0
                        n_reg <= n;
                        count_reg <= 16'd0;
                        result <= 16'd0;
                    end
                end
                
                SCAN_MIN_MAX: begin
                    if (i < n_reg) begin
                        // Update min_val
                        if (values[i] < min_val)
                            min_val <= values[i];
                        // Update max_val
                        if (values[i] > max_val)
                            max_val <= values[i];
                        i <= i + 4'd1;
                    end
                end
                
                COUNT: begin
                    if (i < n_reg) begin
                        // Check if strictly between min and max
                        if ((values[i] > min_val) && (values[i] < max_val)) begin
                            count_reg <= count_reg + 16'd1;
                        end
                        i <= i + 4'd1;
                    end
                    
                    // Update result when counting is complete
                    if (i >= n_reg) begin
                        // Handle edge cases: n<=2 or min==max
                        if ((n_reg <= 4'd2) || (min_val == max_val)) begin
                            result <= 16'd0;
                        end else begin
                            result <= count_reg;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    // Reset for next operation
                    i <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // FSM Combinational Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCAN_MIN_MAX;
                else
                    next_state = IDLE;
            end
            
            SCAN_MIN_MAX: begin
                // Done scanning when i reaches n_reg
                if (i >= n_reg)
                    next_state = COUNT;
                else
                    next_state = SCAN_MIN_MAX;
            end
            
            COUNT: begin
                // Done counting when i reaches n_reg
                if (i >= n_reg)
                    next_state = DONE_STATE;
                else
                    next_state = COUNT;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule