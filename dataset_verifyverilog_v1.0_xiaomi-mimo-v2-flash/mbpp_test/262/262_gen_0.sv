module array_splitter (
    input clk,
    input rst_n,
    input start,
    input [7:0] in_data [0:15],
    input [3:0] in_len,
    input [3:0] L,
    output reg [7:0] out_first [0:15],
    output reg [7:0] out_second [0:15],
    output reg [3:0] first_len,
    output reg [3:0] second_len,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] idx;
    reg [3:0] captured_len;
    reg [3:0] captured_L;
    
    // Temporary arrays for input capture (to avoid latch inference)
    reg [7:0] captured_data [0:15];
    
    integer i;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (idx >= captured_len)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            captured_len <= 4'd0;
            captured_L <= 4'd0;
            done <= 1'b0;
            first_len <= 4'd0;
            second_len <= 4'd0;
            
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                captured_data[i] <= 8'd0;
                out_first[i] <= 8'd0;
                out_second[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Capture input data and parameters
                        captured_len <= in_len;
                        captured_L <= L;
                        idx <= 4'd0;
                        first_len <= (L > in_len) ? in_len : L;
                        second_len <= (L > in_len) ? 4'd0 : (in_len - L);
                        
                        // Capture input array
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < in_len)
                                captured_data[i] <= in_data[i];
                            else
                                captured_data[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESSING: begin
                    if (idx < captured_len) begin
                        if (idx < captured_L) begin
                            // Copy to out_first
                            out_first[idx] <= captured_data[idx];
                        end else begin
                            // Copy to out_second
                            if (idx < 16) begin
                                out_second[idx - captured_L] <= captured_data[idx];
                            end
                        end
                        idx <= idx + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    // Clear internal state for next operation
                    idx <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                    idx <= 4'd0;
                    captured_len <= 4'd0;
                    captured_L <= 4'd0;
                end
            endcase
        end
    end
endmodule