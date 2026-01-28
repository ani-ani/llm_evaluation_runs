module can_arrange (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] i;
    reg signed [7:0] stored_arr [0:15];
    reg found;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;
    
    integer idx;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (len <= 4'd1) begin
                        next_state = FINISH;
                    end else begin
                        next_state = PROCESS;
                    end
                end
            end
            PROCESS: begin
                if (i >= len || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
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
            result <= 4'd0;
            done <= 1'b0;
            i <= 4'd0;
            found <= 1'b0;
            cycle_count <= 4'd0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                stored_arr[idx] <= 8'sd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Store array and initialize
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            stored_arr[idx] <= arr[idx];
                        end
                        i <= 4'd1;
                        found <= 1'b0;
                        result <= 4'd0;  // Will be updated if found
                        cycle_count <= 4'd0;
                        if (len <= 4'd1) begin
                            result <= -4'sd1;
                        end
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check condition: arr[i] < arr[i-1]
                    if (stored_arr[i] < stored_arr[i-1]) begin
                        result <= i;
                        found <= 1'b1;
                    end
                    
                    // Continue scanning
                    i <= i + 4'd1;
                    
                    // If reached end and never found
                    if ((i + 4'd1) >= len) begin
                        if (!found) begin
                            result <= -4'sd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule