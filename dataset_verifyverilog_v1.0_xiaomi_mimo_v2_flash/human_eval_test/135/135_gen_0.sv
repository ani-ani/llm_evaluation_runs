module can_arrange(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg [7:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] idx;           // Current index (1 to len-1)
    reg [7:0] last_decrease; // Last index where arr[i] < arr[i-1]
    reg [7:0] counter;       // Cycle counter to ensure fixed latency
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            idx <= 3'd0;
            last_decrease <= 8'd0;
            counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 8'd0;
                    idx <= 3'd1;  // Start comparing from index 1
                    last_decrease <= 8'd0;  // Initialize to 0 (no decrease found)
                    if (start) begin
                        if (len == 3'd0) begin
                            // Empty array, return -1
                            result <= 8'd255;  // -1 in 8-bit signed
                            state <= FINISH;
                        end else begin
                            state <= COMPARE;
                        end
                    end
                end

                COMPARE: begin
                    counter <= counter + 8'd1;
                    
                    // Perform comparison (8-bit signed)
                    // arr[idx] < arr[idx-1] means last_decrease = idx (1-based)
                    if ($signed(arr[idx]) < $signed(arr[idx-1])) begin
                        last_decrease <= idx;
                    end
                    
                    // Move to next index
                    idx <= idx + 3'd1;
                    
                    // Check if we've processed all elements
                    // We need to compare until idx = len (idx-1 = len-1 is last pair)
                    if (idx >= (len - 3'd1)) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    // Set result: if last_decrease is 0, return -1, else return last_decrease
                    if (last_decrease == 8'd0) begin
                        result <= 8'd255;  // -1 in 8-bit signed
                    end else begin
                        result <= last_decrease;
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule